# Consent and privacy

Part of the [PharenSDK guides](../README.md#guides).

## Consent

Consent is enforced at the boundary: every event is checked against its purpose before it is
queued, and an event whose purpose is not granted is dropped there. Purposes and what they
gate:

| Purpose | Gates |
|---|---|
| `telemetry` | `app.crash`, `app.error`, `app.anr`, `app.exit`, `app.launch`, `app.notice_shown`, `app.notice_dismissed`, `app.notice_action`, `perf.*`, `storage.*`, `cleanup.scan_completed`, and the SDK's own reports: `sdk.error`, `sdk.config_snapshot`, `sdk.config_applied` |
| `behavioral` | `session.*`, `user.screen`, `user.event`, `deeplink.opened`, `install.referred`, `push.*`, `rating.*`, `feedback.survey_shown`, `feedback.survey_dismissed`, `feedback.survey_refused`, `monetization.*`, `cleanup.marked`, `cleanup.freed` |
| `identity` | `identity.identify`, `identity.alias` (and the identity-store send behind `identify`) |
| `content` | `feedback.nps`, `feedback.csat`, `feedback.report` |
| `health` | Special-category data — **reserved in this version**: no API writes the special-category store. A grant changes one thing about what the SDK collects: pictures with a report start off — a default the app overrides once it has masked its screens; see [Field diagnostics](Field-Diagnostics.md). Runtime opt-in only — dropped at start from the plist and from `start(granting:)` alike. Keep it out of any "grant all" action your banner offers: a runtime `setConsent(granted:)` stores the set it is given. |

Two restricted stores stand behind these purposes, and neither is the event stream: the
**identity store**, which `identify()` writes under `identity`, and the **special-category
store**, which `health` gates and which nothing in this version writes. They are separate
tables with separate keys, and `identify()` reaches only the first — which is why a
special-category value has no place in a trait: the identity store treats everything it holds
as a trait, and only the special-category store gives a value special-category handling.

```swift
guard let consent = Pharen.shared?.consent else { return }   // nil until start, or with no key
consent.setConsent(granted: [.telemetry, .behavioral, .identity])  // e.g. from your consent banner
consent.grant(.content)
consent.revoke(.behavioral)
consent.granted   // Set<PharenConsentPurpose>
```

Withdrawing a purpose reaches the queue, not just the gate: already-buffered events of the
withdrawn classes are dropped from memory and disk, and pending crash-report files go with
the crash class. Every event carries an explicit consent context, present even when empty;
an event without one is rejected at ingest.

## Privacy

- **Consent-gated at the boundary.** Every event carries an explicit consent context, present even when empty; an event is enqueued only if its purpose is granted, and an event without a consent context is rejected at ingest.
- **No PII in event properties.** Identity traits (email/name/phone) flow through `identify()` to the identity store, a restricted store separate from the event stream, never inlined into the stream or logs.
- **`org_id` is server-stamped** — the SDK never sends it.
- **Designed for <1–2% overhead:** writing and sending run off the calling thread, in batches. That is the design target; the measured footprint for each release is published at https://www.pharen.ai/sdk.

## Privacy manifest (PrivacyInfo.xcprivacy)

The SDK ships its own Apple privacy manifest, declaring exactly what it does:

- **Collected data** (*no* tracking), every type declared *linked*: Device ID (the SDK's own random per-install anonymous id), Product Interaction (analytics), and Performance/Crash data (app functionality and analytics); **User ID**, the id your app passes to `identify()` (app functionality and analytics); and, for the feedback surfaces (app functionality, user-initiated), **Other User Content** (the free text a person writes into NPS/CSAT/bug reports and the screen frame a report captures with their say-so), **Photos** they pick from their library to attach, and the **Email Address** the report form asks for, so the report's author can be reached.
- **Required-reason APIs**: UserDefaults (`CA92.1` — the SDK's own suite in the app container), SystemBootTime (`35F9.1` — the time budget the storage footprint walk holds itself to; an elapsed-time measure, never sent), FileTimestamp (`C617.1` — the container creation date shown as "Installed" in the dev build panel, display-only; and the app's own executable's change time and added date, from which only `binary_reinstalled_with_data`'s yes-or-no is sent).

The manifest ships inside the framework, where Xcode's privacy report reads it; the report is the reference for your App Privacy answers, which are yours to keep accurate. Everything is declared *linked*: Apple counts collected data as linked when it is tied to the user "via their account, device, or other details", unless privacy protections are applied before collection, and every event and report the SDK sends carries the install id, a device-level id that persists for the life of the install. Calling `identify()` adds your user id to all of it, and the report form's contact field, visible by default, stores a report's address beside the install id. Declaring it linked is the safe side, and an app can answer as the report shows.

Two narrower answers are your app's judgment, made against Apple's own criteria rather than on the SDK's word:

- **Not linked.** An app that never calls `identify()`, sets `feedback.contact.mode` to `.hidden`, and passes `identifyDevice` no id its own systems can join to a signed-in user sends the install id and nothing that names anyone. Whether that is "not linked" under Apple's definition is for you to decide; the install id still rides everything. If you answer not linked, User ID and Email Address are not collected and can be left out.
- **Optional disclosure.** Apple lets an app leave out data that meets all of its criteria: not used for tracking, advertising, marketing or other purposes; collected only infrequently, outside the app's primary function, and optional for the user; and provided by the user in the app's interface, clear to them, with their name or account name prominently displayed in the submission form, and chosen by them each time. The SDK's report form does not display a signed-in account, so it does not meet the last criterion, and feedback reaches the platform only through that form. It never covers what the SDK attaches on its own, such as diagnostics.

A manifest cannot remove the SDK's entries, so either answer is made in App Store Connect. Pass `identify()` an opaque user id rather than an email address or phone number: either works, and the platform replaces it with a reference of its own before storing any event, but it is personal data sent with every event; a development build logs a warning when an id looks like one.

## What Pharen does not do

- **No chat UI.** Pharen does not build generic messaging. The transport legs are:
  - System → user: **Push** (APNs)
  - User → system: **Feedback** (the SDK's reporting sheet: `presentSheet` / `presentReport`)
- **No PII in the event stream.** Identity traits and device attributes route to the identity store — a restricted store of its own — via `identify()` / `identifyDevice()`, never through `properties`.
