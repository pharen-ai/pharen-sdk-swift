# Feedback

Part of the [PharenSDK guides](../README.md#guides).

User → system. The SDK's reporting sheet is how a person sends you a report, under the `content`
purpose; your app opens it, and the sheet does the rest:

```swift
guard let feedback = Pharen.shared?.feedback else { return }   // nil until start, or with no key
feedback.presentSheet()                                       // the reporting flow, same as a shake
feedback.presentSheet(category: .bug)                         // straight to the form for one kind
let answer = feedback.presentReport(category: .bug, context: details)  // the form, with your context
feedback.reportRefusal                                        // nil, or why a report now would be refused
```

Each call that presents a form answers a `PharenFeedbackPresentation` — what came of asking. The
report calls above give it, and so do the survey calls,
[`presentNPS()` and `presentCSAT()`](#surveys-presentnps-and-presentcsat):

| answer | meaning | your app |
|---|---|---|
| `.presented` | the form is on screen, ready to send | nothing to add |
| `.refused(reason)` | feedback is refused right now, for `reason`. From a report call, reports are refused (`reportRefusal` gives the same reason) and the form opened on the refusal, saying why; from a survey call, nothing opened, and the reason is the one `reportRefusal` gives, except `.withheld` while a notice covers your app | nothing to add: the person who asked to report has been told, and the person did not ask for a survey |
| `.unavailable` | nothing opened — another of the SDK's surfaces is on screen (the reporting flow, a survey form, the rating question's card, and for a survey call the platform's rating sheet the SDK has just asked for), there is no window to present from, or the screen in front is being presented or dismissed. A survey call answers this only once every rule of its policy has let the survey through | from a report call, say it could not open; from a survey call your app made on its own, nothing to add |
| `.invalidContext` | nothing opened — `presentReport`'s `context` is empty, only whitespace or past its bound | say it could not open |
| `.ineligible(reason)` | nothing opened — the survey `presentNPS()` or `presentCSAT()` asked for is not presented now, for the first rule of its policy that said no | nothing to add: the person did not ask for it |

Every call that presents one of the SDK's forms is **main-actor only** and presents in your
call's turn, so its answer is what happened. None of them is a send. The sheet calls' answer may
be ignored.

The sheet is the only way a report reaches the platform through the SDK — there is no call that
submits from a form your app draws. It acknowledges submission, and the console shows delivered reports. Let the form handle
the acknowledgment. `reportRefusal` is the same answer read before
anything opens: `.collectionOff` when the SDK is off (compiled or remote), `.consentMissing`
when `content` is not granted, `.withheld` when reports are not being provided to this install
right now. Read it to say "reports are off" in your own UI rather than offering a way to report
that cannot send; the sheet reads it too, and says so in place of the form. Free text is stored
verbatim behind authenticated read and never logged; disclose its handling to your users.

**The platform mark.** On a plan without white-label, every step of the sheet — the picker and the
form — ends in a footnote, **Powered by Pharen**, in the language the sheet's own strings are read
in. It is plain text, never a link, and drawn only when the configuration your app has fetched says
so: a first launch before any configuration has arrived shows none. It is not one of the strings
you can override ([Localization](Localization-and-Branding.md#localization)). The rating question's card and app notices carry no mark on
any plan.

## A report about one thing: `presentReport(category:context:)`

For a report started from something specific in your app — a result it computed, an item it
flagged — `presentReport` opens the form for one kind with **context** from your app shown
above the text field: read-only and selectable, under the heading **Sent with your report**,
and sent with the report as its `context`. The person may add their own words or send the
context alone; everything else about the form holds, the mark and the submission outcome included.

```swift
@MainActor func flag(_ item: Item) {
    guard let pharen = Pharen.shared else { return }
    let details = "engine=4 strategy=\(item.strategy) members=\(item.count)"
    switch pharen.presentFeedbackReport(category: .bug, context: details) {
    case .presented, .refused:
        break                  // the form is up, or says itself why nothing can be sent
    case .unavailable, .invalidContext:
        showCouldNotOpen()     // nothing opened
    case .ineligible:
        break                  // answered only by presentNPS() and presentCSAT(), never by this call
    @unknown default:
        break                  // an answer a later SDK adds
    }
}
```

`presentReport(category:context:)` on `feedback` and `presentFeedbackReport(category:context:)`
on the facade are the same call, and answer what happened (the table above). `context` is at most **2,000 characters** (Unicode code
points; an emoji is one) and is refused whole, never shortened: one that is longer, or empty or
only whitespace, opens nothing, answers `.invalidContext`, and writes a line to the device log.
While `reportRefusal` is non-nil the form opens as `presentSheet(category:)` does — saying why in
place of its field — and the answer is `.refused` with that reason. `.unavailable` while
the reporting flow, a survey form or the rating question's card is on screen, and with nothing to
present from. Put no identifiers, file paths or absolute dates in
`context`: it is stored as the person's words are.

## Surveys: `presentNPS()` and `presentCSAT()`

Both forms use the **native** layout template: system typography, colors and sheet controls.
This is the only shipped template; there is no layout selector or configuration field.

The SDK draws two surveys. **NPS** asks how likely the person is to recommend your app, 0 to 10,
with labeled endpoints; **CSAT** asks how satisfied they are, 1 to 5, each score a number and a
word. One screen: choosing a score reveals the follow-up for its band (0–6 / 7–8 / 9–10, or
1–2 / 3 / 4–5) and an optional comment of up to 10,000 characters, and nothing is sent until the
person presses Send. Closing the form sends no score; once a comment is typed, closing asks first.
The form acknowledges submission. Verify delivery in the console. The forms carry the platform
mark when your plan does, and your app learns whether a form was presented. The score stays with
the SDK and service.

```swift
@MainActor func orderDelivered() {
    Pharen.shared?.feedback.presentCSAT()   // shown only if the served policy lets it be, now
}
```

A survey is presented only under the policy you serve (`feedback.nps`, `feedback.csat`); its
`enabled` is the only switch. The policy holds the wording per language, the cooldown (90 days for
NPS and 30 for CSAT unless it names one), `once_per_version` (off unless it turns it on), minimum
launches, days and sessions since a failure, and triggers. Days since install count from the
first launch with an SDK that has the surveys — or from your first rating checkpoint, if that was
earlier — so an install updated from an older SDK starts counting at the update. Your call answers
`.ineligible(reason)`
with the first rule that said no, and `.refused` — presenting nothing — when feedback is refused
right now; `.unavailable` when there is nothing to present from or another of the SDK's surfaces is
on screen. Answers ride `content`; the form's show, dismissal and refusal ride `behavioral`.

**Asking after your app's own events.** You need not call at all. Track the moments you might ask at
— `track("order_completed")` — and the served policy for a survey or the rating prompt can name
event checkpoints: after a number of that event since install, in this app version, in this
session, or since the prompt was last shown, the SDK reaches the prompt itself, through the same
rules, at a settled moment after an optional delay. Counts stay on the device, begin when the device
first holds a rule naming the event, and need `behavioral`. The NPS form can also have a timed
checkpoint, as the rating prompt has.

**One prompt per launch.** The first prompt the SDK reaches by itself in a launch — timed or after an
event, of any kind — is the only one it reaches. Your app's own call is never refused for this, and
counts as that launch's prompt. A policy can take a kind out of the limit with
`launch_limit: exempt`; the prompt budget still bounds it.

**Report subcategories and copy.** When the policy serves a subcategory list for a kind of report,
the sheet asks for one after the kind — the served rows, then **Something else**, which chooses
none — and the report carries it; `presentReport` and the rating question's form skip the step. The
policy can also serve the picker's title and each kind's label, title, prompt and a placeholder:
served text in the person's language first, then the SDK's own string in it (your `Pharen.strings`
override still replaces that), then the served default.

## Shake to send feedback (+ the dev build panel)

By default, a device shake presents the SDK's reporting flow — in your app's voice, localized in
the reader's language, with the platform mark at its foot on a plan without white-label. It
opens on a compact picker
titled **Need help?**, asking what kind of report this is — **Report a problem**, **Suggest an
improvement**, **Ask a question** — and the choice opens a form already carrying that title and that question,
with a photo picker and a screenshot of the frame at the moment of the shake (taken *before*
any of it appears, so the picture never shows the surface that asked for it). The chosen kind
travels with the report as its category, which is what lets the console group reports by
kind.

A picker a shake opened closes itself after 30 seconds if nobody touches it, silently; a touch anywhere on it, or
choosing any option, cancels that. The form never closes by itself.

Prefer an explicit trigger, or no shake at all? Set `shake.enabled` to `false` and call
`Pharen.shared?.presentFeedbackSheet()` from your own button or settings row; it works whether
or not shake is on. Your own trigger can skip the picker: `presentFeedbackSheet(category: .bug)`
opens that form directly, for a settings row that has already asked the question.

Shake is a property of the build, not of a distribution channel: an app that wants it only in
internal builds sets `shake.enabled` from its own build configuration. Remote config can
only narrow it — a remote `false` kills the surface on the next shake without a release, and a
remote `true` never switches it on for an app that compiled it off.

When feedback cannot be delivered — collection off, `content` not granted, or reports withheld —
the picker says so instead of offering ways to report, using `PharenFeedbackRefusal.message`. While reports are withheld or nothing is being collected, a shake
presents nothing, except on a build that carries the developer panel, which a developer reaches
through the same sheet.

## The reporter's address

A report can carry a way to reach the person who wrote it, so you can answer them. **This is on
by default** (`feedback.contact.mode` is `.optional`), and taking that default means your app
collects an email address, stored beside the install id: the SDK's privacy manifest declares it
(Email Address, linked, app functionality), and your App Privacy answers name it, and Device ID
and what the install sends as linked too. To collect nothing, set `feedback.contact.mode` to `.hidden`, or the `PharenFeedbackContact`
Info.plist key to `hidden`; to insist on one, `.required`.

The address never rides the event stream. It travels by its own call once the report has been
accepted, and a report is never delayed or lost because that call failed — so a person's report
reaches you whether or not they chose to leave an address. The field pre-fills from the email
trait you passed to `identify`, and otherwise from the last address typed on that device, which
is kept locally and sent only as part of a submission. It is editable and clearable, and clearing
it is what forgets it. Withdrawing `content` or `identity` consent deletes everything the install is
holding.

Remote configuration can move an asking app between `optional` and `required`, and can hide the
field — it can never widen a build that compiled `.hidden` back into asking.

On builds that are not the one customers get — debug builds, ad-hoc or development-signed
installs, and in-house (enterprise) builds — the picker also carries a
**Developer** row opening the dev build panel: build identity, install date, SDK and endpoint
info, granted consent purposes, and an update check that offers an in-place install link when a
newer build exists. The check runs only when the panel opens, and sends nothing about the
device. Store and TestFlight installs
never see the Developer row, regardless of the knob.

On every such build but an in-house one, the panel's SDK section also shows the SDK version's
stage — "1.2.0 · Deprecated", in words beside a symbol — its end-of-support and end-of-life
dates and the version to upgrade to, whether new development on it is still accepted, and this
install's service state. The stage and dates are read when the panel opens, and not while the
install is not served or the SDK is switched off; the service state shows with no network at
all. While the install is not served, no update is offered.
