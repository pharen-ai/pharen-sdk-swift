# Field diagnostics

Part of the [PharenSDK guides](../README.md#guides).

`Pharen.shared?.diagnostics` keeps a bounded window of the app's recent network requests (the
SDK's own calls included, labeled) and assembles a **diagnostic bundle** to accompany a
feedback report or a crash: the recent-request window, the person's attachments, and the
window recovered from a run that did not finish, which the next launch attaches to the newest
stored crash. The module never fails upward — with diagnostics off, refused by consent, or
nothing to report, a submission proceeds exactly as it would without a bundle.

Two kinds of thing ride a report. **Attachments** are what a person attaches and ratings
before sending — the frame captured at the trigger and any pictures they pick — and every
`attachments` setting, compiled, served or at runtime, governs those alone. The network
trace, breadcrumbs and app context are **diagnostics** the SDK gathers, governed by
`enabled` and, for the trace, `network.enabled`; turning attachments off leaves them riding.
Breadcrumbs have no switch of their own: they ride every report, under `telemetry`.
`crashTrace` is the trace a crash report carries: a trigger, not a part, and distinct from
`crashReporting.enabled`, which installs the crash handlers.

```swift
guard let diagnostics = Pharen.shared?.diagnostics else { return }   // nil until start, or with no key
diagnostics.recordNetwork(metrics: taskMetrics)             // route your own URLSession here, or use PharenURLSessionDelegate(diagnostics:)
diagnostics.networkFilter = { $0.url?.host != "payments.myapp.example" }
diagnostics.settings                                 // PharenDiagnosticsSettings in force, remote overrides folded in
diagnostics.attachmentAvailability                   // would a report opened now offer pictures — and if not, why
diagnostics.carries(.networkTrace)                   // would a report opened now carry this part (false for one it never carries)
diagnostics.setAttachmentsEnabled(false)             // pictures off on this install, persisted; only ever narrows
```

Capture is on by default (`PharenDiagnosticsSettings()`: network and crash traces, up to 5
pictures of 800 KB each) — **but the SDK never hooks `URLSession`**. The network trace holds
only what your app routes to it: hand each session's metrics to `recordNetwork(metrics:)`
from your own task delegate, or give the session `PharenURLSessionDelegate(diagnostics:)`.
Without either, a report's network trace is empty. The compiled settings are `config.diagnostics` in the start block,
nested by part: `enabled`; `network` (`enabled`, `maxEntries`, `maxAgeSeconds`, `maxTraceBytes`);
`crashTrace` (`enabled`, `maxEntries`, `maxAgeSeconds`); `attachments` (`enabled`, `maxCount`,
`maxBytes`, `maxLongestEdgePixels`, `minQuality`, `fallbackLongestEdgePixels`); `upload`
(`cellularMaxBytes`, `escalateAfterHours`); and one ceiling beside
the parts, `maxBundleBytes` for the whole submission. The parts are spelled the way remote config's `diagnostics` section is, so the line
you write reads as the document an organization serves — `enabled`, `network.enabled`,
`network.maxEntries` / `max_entries`, `network.maxAgeSeconds` / `max_age_seconds`,
`upload.cellularMaxBytes` / `cellular_max_bytes`, `upload.escalateAfterHours` / `escalate_after_hours`,
`crashTrace.enabled` / `crash_trace.enabled`, `attachments.enabled`, `attachments.maxCount` /
`max_count`; everything else is compiled only. A served field overrides its compiled one,
field by field — except two that only narrow: a served `attachments.max_count` never raises the
compiled count, and a compiled `attachments.enabled = false` is never turned on by a served value.
The picture count and size and the bundle sizes are the platform's ceilings, and a served
picture count may lower the compiled one, never raise it. A value written in code past a bound
is held to it and logged at error level, naming the field. Uploads follow `PharenUploadPolicy` — by default a
bundle under 2 MiB goes on any connection, a larger one waits for an unmetered path and stops
waiting after 24 hours — and a bundle waiting on connectivity is retried on foreground.

Mark what must never appear in a captured frame: `.pharenPrivacyMask()` on a SwiftUI view, or
`view.pharenPrivacyMask = .blockCapture` on a `UIView`. While a marked view is on screen, no
picture of the screen is taken: the report opens without a thumbnail, the person can still add
a picture of their own, and the report records why (`privacy_mask`) for you to see in the
console. A marked view counts as on screen while it is in the view tree, not hidden and not
fully transparent. One exception reads the other way: a SwiftUI view with the mask and `.hidden()`, or
inside `drawingGroup()`, has no view in the tree for the SDK to find, so while it is in the layout
no picture is taken at all. Leave a private view out of the layout (`if`) rather than hiding it,
and keep it outside `drawingGroup()`. The SDK logs an error naming this case when it refuses.

To keep the rest of the screen, cover just the view instead: `.pharenPrivacyMask(.coverRegion)`,
or `view.pharenPrivacyMask = .coverRegion`. Its rectangle is filled before encoding. The fill
covers the view's layout frame and nothing drawn outside it, so apply the mask before any
`offset`, `rotationEffect` or `scaleEffect`, and clip content that may overflow; a covered view
inside `drawingGroup()` cannot be found, so no picture is taken. No picture is taken while a
view controller transition is in flight or the view is animating either, since its rectangle is
not yet where its pixels are.

The mask cannot reach a picked photo, and a region you did not mark is captured — the platform
provides the mechanism and cannot verify the app used it. The capture is the SDK's own, taken by
its reporting sheet; there is no call to take one yourself, and no way to attach a picture except
through the sheet.

## Pictures: the `health` purpose, the block, and the switch

Every part of a bundle rides a purpose (`PharenBundlePartKind.consentPurpose`: the network
trace, breadcrumbs and app context ride `telemetry`; pictures ride `content`), and a part
whose purpose is not granted is left out. Pictures are the one part whose default is derived
from consent: **where the person has granted `health`, they start off**, because a frame from
an app that asks for that consent is likelier to show someone other than the sender. A health
app masks first, then turns pictures on where a reviewer sees it:

```swift
Pharen.start(granting: [.telemetry, .behavioral]) { config in
    config.diagnostics.attachments.enabled = true   // we mask, therefore we capture
}
```

— or for the whole app, `diagnostics.attachments.enabled: true` in remote config, the same
spelling. A choice made either way beats the default. A served `false` stops a
build that compiled `true`, and a served value decides for a build that compiled no choice; a
compiled `false` turns pictures off for any app, and no served value turns them back on — only a
build without that line can.

`setAttachmentsEnabled(false)` turns pictures off on this install at runtime — persisted
across launches, and it only **narrows**: `true` hands the answer back to the setting and to
consent, never past them. That makes it safe to wire to a settings switch a person flips, and
the choice stays on the device. `attachmentsEnabled` reads the switch.

Read the forecast, not the flag, to know what a report would carry:

```swift
switch Pharen.shared?.diagnostics.attachmentAvailability {
case .available:              showAttachButton()   // the frame and the picker are offered
case .offBySetting:           hideAttachButton()   // attachments.enabled false (compiled or served), diagnostics off, a count of zero, or the kill switch
case .offByConsent:           hideAttachButton()   // pictures may not leave under content — no picture
case .offByRuntimeSetting:    hideAttachButton()   // setAttachmentsEnabled(false) on this install
case .offByDefaultForHealth:  hideAttachButton()   // health granted, no choice made — mask, then turn on
case nil:                     hideAttachButton()   // the SDK is off
@unknown default:             hideAttachButton()   // a reason a later SDK adds: offer nothing it cannot name
}
```

When several reasons hold, the one named is the one to change first. The report sheet reads
the same answer for its frame and its picker, and the report records the same reason. `isCollecting`
is the gate every part passes first — diagnostics on and the kill switch off.
