# Analytics and identity

Part of the [PharenSDK guides](../README.md#guides).

```swift
Pharen.shared?.track("subscription_started", properties: ["plan": "pro", "trial": true])
Pharen.shared?.screen("Settings")
Pharen.shared?.identify("cus_482", traits: [
    "plan": "pro",
    "email": "person@myapp.example",
    "name_given": "Ada",
    "name_family": "Lovelace",
])
Pharen.shared?.identifyDevice(deviceId: serverDeviceId, attributes: ["model_tier": "high"])
```

`track` sends `user.event` with `name` and your properties; `screen` sends `user.screen`.
Keeping personal data out of properties is your app's job: the SDK refuses only these exact keys
on the device — `email`, `phone`, `name`, `address` and `ssn` on the bag itself, and `email`,
`phone` and `ssn` in a nested value — the platform checks again at ingest,
and a refusal is reported through the SDK's own health channel so it never looks like data loss.

`identify` puts the id you pass on the event stream as `user_id` and sends the traits to
the identity store on a separate path — traits never appear on the stream or in
logs. `identifyDevice` does the same for a device id and its attributes — it records them
against the current install and joins nothing (see [Continuity without sign-in](#continuity-without-sign-in)).
Use it for facts about the hardware rather than the person, such as the performance tier above,
and for an id your own systems already keep for the device, such as the id your own server gave
it: the attributes stay with the install even after someone signs in, so they never become that
person's traits. The device id rides the `identity.identify` event, which the console's Events
page shows; no count groups or filters by it.

**Linking a person to their install.** By default an install is only its own random id — the
platform never joins it to a person. When you want events, crashes and reports from an install
attributed to a signed-in user, call `identify` with **your own id for this user** (the one your sign-in system uses) as the first argument: from that call on, every event and every report
the install sends carries it as `user_id`. The call needs the `identity` purpose; without
it nothing is sent and nothing is kept, and withdrawing the purpose ends the link. The id is
kept on the device (outside the device backup), so later launches send as the same person
without another call; set `identity.persistence` to `.processOnly` to keep it for the process
only. Call `identify` when someone signs in, and again whenever your app learns who is using it:
a launch before the device is first unlocked after a restart cannot read the kept id, and sends
as nobody until you do. A crash report carries the id identified when the app crashed and the
install it crashed as, recorded at that moment and sent on a later launch — the id only while
`identity` is granted then. `reset()` and a withdrawal take it off reports still waiting; one
already being sent when you call it goes as it was read. An id the SDK does not record on a crash
report (a placeholder, or one that is not a user id — see below) is left off; the crash is
delivered without it.
Identifying the same id again is the ordinary case.

Call `identify` only once someone is signed in. An id that names nobody — `guest`, `anonymous`,
`null`, `0`, an empty string and the rest of the platform's short list, matched whole and without
regard to case — is removed by the platform from every event that carries it, so that one
placeholder never becomes a single "user" shared by every signed-out install. The events are
still delivered, as if nobody were signed in; the `identity.identify` event itself, which carries
nothing but the id, is rejected; and each is counted on the ingest-health endpoint
(`GET /v1/ingest/health`). That happens on
the platform, so a development build of your app logs the mistake to the console
(`ai.pharen.sdk`, category `lifecycle`). Such an id is held only for the process that passed it
and is never kept across launches, and an id kept by an earlier build that the list now names is
deleted at start. Traits sent with a placeholder are refused and not kept.

A user id is at most 256 characters, counted as Unicode code points, with no control character. A
plain emoji is one code point; one drawn from several — a flag, a skin tone, a family — counts
each. An id longer than that, or containing a control character, is not a user id: `identify`
links nobody with it, no later event carries it and no trait update is sent, and whoever was
identified before is no longer, so their id does not ride the next person's events. The
`identity.identify` event still goes: the platform refuses it and counts the refusal on the
ingest-health endpoint (`GET /v1/ingest/health`), so the mistake shows where you look. A
development build also logs why.
The id is never shortened or repaired for you: two users whose ids differ only past the limit
would become one user. An id of that shape kept by an earlier build is deleted at start.

**Signing out.** Call `reset()` when the person signs out:

```swift
Pharen.shared?.reset()
```

From then on nothing the install sends carries a user id until the next `identify`. `reset()`
forgets the kept id and takes it off everything still waiting to be sent: queued events go
without it (a queued `identity.identify` from `identify` is dropped, since the id is all it says;
one from `identifyDevice` stays), trait sends kept for a retry are dropped, and a report's pending
contact goes without it. It also forgets the address the report form remembered. A batch already
being delivered when you call it is delivered as it was built. It leaves the install id, consent
and everything already delivered as they are. Events still queued at sign-out — an offline
session, say — are delivered without the id, so they count toward the install but not the user.

On a device more than one person uses — a shared iPad, a family device, a kiosk — this call is
what keeps the next person's events from carrying the last person's id. Withdrawing the
`identity` purpose also clears the id, and more besides (below), and stops `identify` from
linking anyone until it is granted again; `reset()` leaves the grant in place, so the next
person can be identified straight away.

**A new install for the next person.** `reset(.userAndInstall)` does everything `reset()` does
and also replaces the install:

```swift
Pharen.shared?.reset(.userAndInstall)
```

From that call on the install id is a new one, kept for later launches. The current session ends
under the old install and the new install's first begins (`session.start` with `source: reset`,
its `session_number` 1), and the push token is registered to the new install, which takes it
from the old one once the registration can be sent (below). The new install reports its
configuration afresh, as a new install does. Events already queued, a session's end and exit, a
crash report and diagnostics captured before the call stay with the install they came from.
Consent, your app's own settings, and the SDK's rating and storage history stay. Choose it
when nothing the next person does should count toward the previous person's install — a kiosk, a
device handed on; `reset()` is enough when the same household shares one install.

The token moves only when the registration can be sent: with `behavioral` granted, the SDK
switched on, a token your app has handed over, and a network. Until then the previous install
keeps it, and a notification sent to that install still reaches this device.

| | `reset()` | `reset(.userAndInstall)` | withdrawing `identity` |
|---|---|---|---|
| Kept user id | deleted | deleted | deleted |
| Queued events | id removed; an `identity.identify` from `identify` dropped | the same, and they stay with the old install | id removed; every `identity.identify` dropped |
| Trait sends kept for a retry | `identify`'s dropped; `identifyDevice`'s kept without the id | the same | all dropped |
| A report's pending contact | sent without the id | the same | dropped |
| Report form's remembered address | forgotten | forgotten | forgotten |
| Next `identify` | links at once | links at once | does nothing until `identity` is granted |
| Install id | kept | replaced | kept |
| Session | continues | ends; the new install's first begins | continues |
| Push token | stays with the install | registered to the new install, once it can be sent | stays with the install |

An opaque id is best, but if your sign-in system's id is an email address or a phone number,
pass it as it is: the platform replaces it with a keyed reference before anything is stored,
keeps the id itself encrypted, and never puts it on the event stream. Send it spelled the same
way every time — `Ada@Example.com` and `ada@example.com` are two different ids, because some
sign-in systems keep them apart — and if the id is an address, send it as the `email` trait
too, which is what makes the person findable by their address. Calling `identify` is also what turns the install id into
something joinable to a person, which is why the SDK's privacy manifest declares Device ID and
what the install sends as *linked* (see [Privacy manifest](Privacy.md#privacy-manifest-privacyinfoxcprivacy)).

**Traits for support.** The second argument is the detail you want beside that id when someone
reaches you, under the keys the platform recognizes — `email`, `phone`, `name_given`,
`name_family`, `name_display`, `username`, `group_id`, `company`, `plan`, `created_at`,
`locale`, `time_zone` — or any key of your own, which is kept as it is. `group_id` is the id of
the group this user belongs to in your app — a company, dealer, team or household. `email`,
`phone`, `username`, `group_id` and the name parts are what the person can be found by; a
phone number is findable only in international form (`+12065550100`). Traits go by their own
call to the identity store, kept for the person across all their installs, where each send
merges over what was stored before. Values are scalars — `String`, `Bool`, a finite number —
or null: send `NSNull()` for a key to remove it from the store (an optional that is nil does the same; note
that assigning a nil optional through a dictionary subscript drops the key instead of setting
it). A bag holds up to 64 keys and 16 KB per call. Whatever the store would not take is refused
before the send, on its own, and the rest of the bag still goes: a value that is not a scalar (an
array, a dictionary, a date), keys past the cap in sorted key order, and the largest values first
when the bag is over size. Each refusal is
reported through the SDK's own health channel, like a refused event attribute —
`identity.trait_refused`, with counts and, for a value with no JSON form, its type, never a key
or a value. A trait send that fails because the device is offline or the platform is unavailable
is kept on the device and retried on later launches until it succeeds or identity consent is
revoked; one the platform refuses outright is reported (`identity.send_refused`, with the status)
and not kept.

## Continuity without sign-in

Deleting the app and installing it again makes a new install with a new id, and the platform
does not join the two: deleting an app is the one reset a person has, and the SDK leaves it with
them. The install id is kept out of the device backup too, so restoring your app's data onto a
new iPhone or iPad, or onto the same one after an erase, starts a new install there; its first
`app.launch` carries `restored_from_backup: true`. An install that last ran on an earlier SDK is
carried over once by a backup taken before it updated. An app that deletes the contents of its
own Application Support while keeping its settings is taken for a restore too. The exclusion is
the system's backup exclusion, which Apple does not document as a guarantee.

Offloading an app keeps its data, so an offloaded app that comes back is the same install. A
launch that finds the app's executable placed again at the same version and build carries
`binary_reinstalled_with_data: true` on its `app.launch`. That is what a return from offloading
looks like, and the field names the fact, not that cause: a development build installed again at
the same build number reports it too, and so could a system update that places apps again. A
return that brings a newer build reads as the update it also is and is not reported. It is read
on iOS only, and in the Simulator it can report a reinstall that was not one. Reading the
executable's file times is declared in the SDK's privacy manifest, and only the fact leaves the
device.

With `telemetry` granted when the SDK starts, it also keeps one Keychain item, on this device
only, never synchronized and keyed to your app's bundle identifier, which can outlive the app's
deletion: a random marker, a random salt, and — once someone has signed in — the install they last
signed in on and a hash of their id under that salt. A new install that finds it carries
`installed_before: true` on its first `app.launch` with `telemetry` granted; when the same user
then signs in again, that `identity.identify` carries `replaces_install`, the install they left.
Neither is ever reported as false, because nothing guarantees a Keychain item survives the app: a
missing item proves nothing. No identifier of the device is read, the marker and salt never leave
it, and `reset()` and withdrawing `identity` clear who last signed in (a process launched before
the device's first unlock cannot reach the item until it is unlocked). The item exists only while
`telemetry` is granted: withdrawing it removes the item, and so does a launch without it, whether
the user declined or your app never granted it. One exception lets an app ask after it starts: a
reinstall that starts without `telemetry` leaves an earlier install's item in place for seven
days from its first launch. A grant in that time is picked up at the next launch, which reports
the reinstall if it falls inside those seven days; if the user declines, or the seven days pass,
the next launch removes the item.

Only builds signed by the Apple developer team that signs your app can reach the item. After an
App Store app transfer, builds the new team signs can neither read nor remove an item an earlier
team's build kept; it stays on the device, never read again, and `reset()` and withdrawing
`telemetry` or `identity` reach only an item a new-team build kept.

If your app does not sign people in and you want a returning person counted as the same
one, that is your choice to make and to declare: pass an id of your own to `identify` as the
user id, on every launch like any user id, and every install of **this app** that sends it
is then one user. (Users are kept per app, so two of your apps sending the same id are two
users.) Two ids an app can use, neither of them a promise:

- **`identifierForVendor`**, which the system assigns. It comes back the same after a reinstall
  only while another app you publish stays installed, and changes when the person deletes them
  all — so for a publisher with a single app it gives no continuity at all. It can be `nil`
  (after a restart, before the device is first unlocked): call `identify` once it has a value,
  and never substitute a fallback, which would split the person in two.
- **An id you keep in the Keychain.** Whether a Keychain item outlives deleting the app is not a
  behavior Apple documents, so treat it as best-effort. Store it with a `…ThisDeviceOnly`
  accessibility and without iCloud sync, or it follows the person: an ordinary item moves to a
  new phone through an encrypted backup or a device transfer, and a synchronizable one reaches
  their iPad through iCloud Keychain.

Know what that makes the numbers mean:

- a "user" is then a device as your app identifies it: a shared iPad is one user, and one
  person's iPhone and iPad are two;
- a user id you add later, when you add sign-in, is a different user from this one, and the
  two are not merged;
- the id is sent under the `identity` purpose, and your App Privacy answers name it as a Device
  ID linked to the person (the SDK's manifest already declares Device ID linked), with the
  consent your privacy notice and the law in your markets ask for.

`identifyDevice` does not do this: installs that report the same device id stay separate
installs. Passing the vendor identifier to `identifyDevice` records it and does nothing more with
it, and it is still a Device ID — declared linked in the SDK's manifest, and linked in fact once
your app also calls `identify`, because the event then carries the user id too.
