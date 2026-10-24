# Configuration

Part of the [PharenSDK guides](../README.md#guides).

## The Info.plist keys

`Pharen.start()` and its `granting:` / `configure:` forms read these keys from the app's
Info.plist:

| Key | Required | Value |
|---|---|---|
| `PharenIngestKey` | yes | The ingest key (`YOUR-INGEST-KEY`), one per app and environment — see [Keys](https://www.pharen.ai/docs/api-keys). Public by design — commit it. **Empty or missing ⇒ the SDK stays fully off**: `start` returns `nil` and installs nothing. That is the recommended way to disable Pharen in local or unconfigured builds. |
| `PharenConsentGrantedAtBuild` | no | Array of purpose strings granted at launch (`telemetry`, `behavioral`, `identity`, `content`). `health` listed here is dropped at start, logged and reported: special-category consent is a runtime opt-in, never a build-time grant. A value passed to `Pharen.start(granting:)` **replaces** this array — pick one form. |
| `PharenIngestBaseURL` | no | For an ingest you run locally while developing: read only in a development build (a simulator build, or one signed for development). A release build ignores it, logs that it did, and sends to the SDK's own host. Must be `https`, or `http` to a loopback host only; anything else turns the SDK off rather than downgrade transport security. |
| `PharenLinkDomains` | no | Array of extra universal-link domains the deep-links module accepts inbound (`["myapp.example"]`), beyond the hosts the platform serves for your app. `pharen.link` is included until the platform has named those hosts. Each entry still needs its `applinks:` associated-domain entitlement. |
| `PharenFeedbackContact` | no | `optional` (the default), `required` or `hidden` — whether the report form asks the person for a way to reach them; see [The reporter's address](Feedback.md#the-reporters-address). |
| `PharenAppEnvironment` | no | The test environment this build sends to, by name, when its ingest key is a test key — see `appEnvironment` below. Typically `$(PHAREN_APP_ENVIRONMENT)`, set per build configuration. Empty, only whitespace, or missing ⇒ none declared, and the key's own environment applies; so is a value that is not printable ASCII of at most 64 characters, which is logged at start. |

`CFBundleShortVersionString` and `CFBundleVersion` supply the app version and build.

Grant consent in code with `Pharen.start(granting:)` — it is a policy decision about what you
collect, and it should read like one, in a line a code reviewer sees. Prefer configuration?
Declare the purposes in `PharenConsentGrantedAtBuild` and call `Pharen.start()`; the two forms do the
same thing, and when both are present the code value wins.

## The start forms

| Call | Configuration | Consent |
|---|---|---|
| `Pharen.start(granting:) { config in … }` | Info.plist, then the block over the parsed `PharenConfig` (the block is optional) | The purposes you pass (replaces `PharenConsentGrantedAtBuild`) |
| `Pharen.start() { config in … }` | Info.plist, then the block (optional) | `PharenConsentGrantedAtBuild`, or whatever the block writes to `consentGrantedAtBuild` |
| `Pharen.start(config:)` | A `PharenConfig` you built | `config.consentGrantedAtBuild` |

The Info.plist forms return `nil` when unconfigured. `start(config:)` always returns an
instance; with an empty `ingestKey` it logs an error and returns a stub that refuses every
event, installs no handlers and writes nothing to disk. One instance per process: a second
`start` logs loudly and returns the existing instance with the new configuration ignored.
`Pharen.shared` is that instance (`nil` before start) — read it at each call site rather than
caching it in your own singleton. A start the system makes before the device's first unlock since a
restart (a silent push or a fetch, say) cannot read what the SDK keeps on the device, so until the
unlock `shared` is an instance that collects nothing, and at the unlock it becomes the started one.

The other decisions a reviewer should see go in the block that follows the line, on the
configuration parsed from Info.plist. What the block sets wins; what it does not set keeps
the plist's answer or the default.

```swift
Pharen.start(granting: [.telemetry, .behavioral]) { config in
    config.ratings.minCheckpoints = 5                 // thresholds only — the switch is the policy you write in the console
    config.diagnostics.attachments.enabled = true     // pictures with a report, once your screens are masked
    config.shake.enabled = false                      // you will call presentFeedbackSheet() yourself
    config.feedback.contact.mode = .hidden            // the report form does not ask for an address
}
```

The block never sets the key, the release identity or the app: they come from Info.plist,
the bundle and the ingest key. `health` cannot be granted at start by any form — a value
written into `consentGrantedAtBuild`, on the granting line, in a plist or in the block, is
dropped at start, logged at error level and reported as `config.health_at_build` (an
`sdk.error`, which rides the `telemetry` purpose).

## Configuring in code

`start(config:)` skips Info.plist: a host that assembles its own configuration — a test
harness, a hosted seam, a migration — builds the `PharenConfig` and starts with it.

```swift
import PharenSDK

// The ingest endpoint is compiled in, the app is derived from the key, and the version and
// build are read from the bundle — none of them is an integration step, and none can be
// typed against.
let pharen = Pharen.start(config: PharenConfig(
    ingestKey: "YOUR-INGEST-KEY",   // public by design; safe to commit
    consentGrantedAtBuild: [.telemetry, .behavioral, .identity]
))

pharen.track("checkout_completed", properties: ["order_value": 49.99, "items": 3])
pharen.screen("Cart")
pharen.identify("cus_482", traits: ["plan": "pro"])  // needs .identity; traits → the identity store, never the event stream
pharen.crashReporting.recordError("payment failed")
```

Every call is gated by a purpose (the table under [Consent](Privacy.md#consent)): `track` and `screen`
by `behavioral`, `identify` by `identity`, `recordError` by `telemetry`. A call whose purpose
is not granted is dropped quietly — that is the privacy design — so grant what you call.

`PharenConfig` reads `appVersion` and `appBuild` from the bundle (`CFBundleShortVersionString` /
`CFBundleVersion`), the same values your release registers, and the server derives the app
from the ingest key, which is minted for one app. Neither is settable, and the configuration has
no field for the app. Pass `bundle:` to read another bundle.

## `PharenConfig` reference

Every field, with its default. The Info.plist forms set `ingestKey`,
`consentGrantedAtBuild`, `linkDomains` and `feedback.contact.mode`; everything else is
code-only. Where the SDK sends is not a field: every release build sends to the SDK's own host
over HTTPS, and a request or redirect to plain HTTP anywhere but the device itself is refused. A field remote config can also serve is spelled the way the served document spells
it — `shake.enabled`, `feedback.contact.mode`, `ratings`, the parts of `diagnostics` — so a
knob reads the same in this block, in a served document and in the build's config report; a
number that would be ambiguous carries its unit in its name.
`appVersion` and `appBuild` are read from the bundle on every path, and the app is derived by
the server from the ingest key — the configuration has no field for it.

| Field | Default | What it does |
|---|---|---|
| `ingestKey` | — (required) | Sent as `X-Pharen-Ingest-Key`. The server derives organization, app and environment from it. The SDK never sends the organization or the app; it may declare a test environment (`appEnvironment`), but never stamps one — the server decides. Empty ⇒ the SDK is off. |
| `appEnvironment` | `nil` (or `PharenAppEnvironment`) | The test environment this build sends to, by name — `qa`, say, where the key's own environment is `staging`. Sent with every request as `X-Pharen-App-Environment`; `nil`, empty or only whitespace sends nothing. A value set in the start block replaces the plist's. Only a test key reads it, and one minted pinned to its environment ignores it; a live key always sends to your live environment, and the platform flags a declaration a live key carries, and a test key declaring `live`, `production` or `prod`. The name is trimmed and sent only when it is printable ASCII of at most 64 characters; anything else is logged at start and declares nothing. A name the platform cannot use — misspelled, archived, not one of yours — is never refused, and the data goes to the key's own environment. Read at the first `start` in a process, so an in-app environment chooser's choice takes effect at the next launch. |
| `appVersion` / `appBuild` | from the bundle | The release identity every event carries (`CFBundleShortVersionString` / `CFBundleVersion`). Read-only, so crashes and symbols match the release you registered. |
| `maxQueueDepth` | `15_000` | Events held offline — the queue's share of what the SDK keeps on the device for sending, which is 30 MB and 15 000 items across the queue, crash reports and identity updates together. Past either bound, the oldest events your own calls recorded go first; see [Delivery](Delivery.md). |
| `crashReporting` | `.default` | `crashReporting.enabled` (`true`): install the crash and error handlers at start, and upload any pending report. `crashReporting.startupCrashSendTimeoutSeconds` (`2`): how long `start` waits for a crash the previous run suffered *during startup* to reach the server before your app goes on, so an app that crashes at every launch can still report it. Spent on that launch alone, and only when such a report is waiting; `0` never waits. |
| `sdkKillSwitch` | `false` | The SDK's emergency stop, compiled in: the SDK captures and sends nothing, and your app runs on untouched. The platform can also stop the SDK remotely. |
| `consentGrantedAtBuild` | `[]` | Purposes granted at start, before the crash handlers install. A first-run baseline: a person's later runtime choice persists across launches and is not overwritten by it; a baseline that changes between app versions is reconciled at start. |
| `linkDomains` | `[]` | Extra inbound universal-link domains, beyond the hosts the platform serves for your app. |
| `ratings` | `PharenRatingSettings()` | Compiled rating thresholds, inherited by the `ratings` policy you write in the console. No compiled switch: a prompt is never presented from compiled rules alone (see [Ratings](Ratings.md)). Every part of the block is written the same way as `shake` and `diagnostics`. |
| `shake` | `.default` | `shake.enabled` (`true`): present the feedback sheet on a device shake. |
| `diagnostics` | `.default` | What a report or crash may carry, how much, and how it is delivered — nested by part (`network`, `crashTrace`, `attachments`, `upload`) and spelled the way remote config's `diagnostics` section is. `attachments.enabled` is `nil` by default (let consent decide); the count and size ceilings are the platform's. See [Field diagnostics](Field-Diagnostics.md). Code-only. |
| `feedback` | `.default` | `feedback.contact.mode` (`.optional`): does the report form ask the person for a way to reach them? `.optional` asks and takes a blank, `.required` will not send without one, `.hidden` does not ask and collects nothing. **Taking the default means your app collects an email address** — answer App Privacy with it (the SDK's manifest declares it), or set `feedback.contact.mode` to `.hidden`. Also settable as the `PharenFeedbackContact` Info.plist key. |
| `identity` | `.default` | `identity.persistence` (`.acrossLaunches`): the user id passed to `identify` is kept on the device, outside the device backup, so later launches send as that person until `reset()`, a withdrawal of `identity`, or `identify` with a different id. `.processOnly` keeps it for the life of the process and deletes one an earlier configuration kept — for an app that signs in on every launch. Code-only. |
| `uiLocale` | `nil` | Pin the SDK's own end-user surfaces to one language (a BCP-47 tag). `nil` follows the reader's own language preference. |
| `storageAppGroupIdentifier` | `nil` | An app-group container to include in the storage footprint. Entitlements cannot be read back at runtime, so a group container is measured only when named here. |
| `storageDirectories` | `[]` | Directories to include in the storage footprint beyond the standard containers (`PharenStorageDirectory`). |
