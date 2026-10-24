# PharenSDK (iOS / Swift)

The iOS/Swift SDK for **[Pharen](https://www.pharen.ai)**: crash, hang and error reporting,
performance, sessions and analytics, identity, feedback and surveys, rating prompts, deep links,
push registration, remote configuration and app notices, field diagnostics, and storage
observability — in one Swift package, with no third-party dependencies. Every event is gated
by a consent purpose your app grants, queued offline, and sent in batches.

The SDK ships as a **compiled framework**: this repository carries the package manifest and the guides, and each release is a tag plus one archive, `PharenSDK.xcframework.zip`, that the manifest names by SHA-256 checksum. Swift Package Manager verifies the archive before anything is linked. Inside it, per platform: a dynamic `PharenSDK.framework` with its textual module interface and documentation, the SDK's privacy manifest and its 21 `.lproj` localizations.

> **2.0.** APIs follow SemVer: `from: "2.0.0"` resolves every 2.x release, and a breaking change means a new major. The SDK runs in production apps.

## Requirements

- iOS 15+, on the device and the Simulator (arm64 and x86_64). The archive also carries a macOS 13+ slice, so a package that depends on it builds for macOS test targets. Mac Catalyst and visionOS are not in this release's archive.
- **Xcode 26.0.1 or newer** for this build (Swift 6.2; that Xcode itself runs on macOS 15.6 and later). The framework is built with library evolution enabled, and its textual module interface is readable by the compiler that wrote it and by newer ones — so the Xcode that builds a release is the floor for that release, and it is stated here for every release. The policy: each release is built with the oldest Xcode App Store Connect accepts at that time, so the floor tracks Apple's; this section states the floor each release used.
- **Swift Package Manager only** (no CocoaPods). No third-party dependencies; system frameworks only.

**Swift 6 / strict concurrency:** the framework is compiled with complete strict-concurrency
checking, in the Swift 5 language mode. The public surface is `Sendable` — the envelope and
context types, the configuration, and every module protocol — so a plain `import PharenSDK`
works in Swift 6 language-mode projects; `@preconcurrency import` is not needed.

**Overhead:** an event call such as `track` or `screen` builds the event on the calling thread
and returns; writing it to disk and sending it run off that thread. `start` can wait at launch,
up to two seconds by default, to send a crash the previous run suffered during startup. The
design target is under 1–2% overhead; the measured footprint for each release is published at
https://www.pharen.ai/sdk.

## Install (SPM)

Read [the SDK license](LICENSE.md) and its [release terms snapshot](LEGAL-TERMS.txt)
before obtaining or using the package. Schedule A, Part C governs the compiled SDK,
including accountless evaluation. Downloading, installing, running, linking, or distributing
the SDK — adding this package to your project installs and links it — is your acceptance of
Schedule A as a whole, Part C included; if you do not accept it, do not do any of those things.
For organizational use, an authorized representative
should accept the Terms through [onboarding](https://onboard.pharen.ai/start) or arrange
written acceptance with [hello@pharen.ai](mailto:hello@pharen.ai); automated package
resolution is not a record that a representative agreed. App end users do not accept
this developer agreement. The [sample code](Sample/LICENSE.md) has separate 0BSD terms.

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/pharen-ai/pharen-sdk-swift.git", from: "2.0.0")
]
```

Add `"PharenSDK"` to your target's dependencies. Consumers pin a SemVer **major** range:
`from: "2.0.0"` resolves every 2.x release.

Resolution fetches `PharenSDK.xcframework.zip` from this repository's Releases and verifies
its checksum against the manifest, so a build machine needs to reach `github.com`. Xcode
embeds the framework in your app. Upload your app's own dSYMs so your frames symbolicate —
[Crash reporting](https://www.pharen.ai/docs/crash-reporting) lists the ways. The archive
carries no debug symbols for the SDK, so a crash frame inside the SDK reads `PharenSDK + 0x…`:
attributed to the SDK, not named. Xcode's warning at upload that `PharenSDK.framework` has no
dSYM is expected and does not stop the upload; [Crashes and errors](Guides/Crashes-and-Errors.md)
says why.

## Quick Start

You need an ingest key for each app and environment. Keys are issued once your application is
approved; [Keys](https://www.pharen.ai/docs/api-keys) explains how. An ingest key is public by
design: it ships inside your app, submits data for that one app and environment, and cannot
read your event data back. Beyond sending, the SDK uses it to fetch the app's served
configuration, to look up a link when one opens, and, in the developer panel (debug, ad-hoc and
in-house builds), to read the app's latest build and, outside in-house builds, the SDK version's
support status — [SECURITY.md](SECURITY.md) lists every route it reaches.

**1. Put the key in Info.plist.** Add `PharenIngestKey` to the app's Info.plist. To send Debug
builds to a test environment and Release builds to live, set the value to
`$(PHAREN_INGEST_KEY)` and define `PHAREN_INGEST_KEY` per build configuration, in the target's
build settings or an xcconfig. A custom Info.plist key must reference the build setting
directly; `INFOPLIST_KEY_<name>` carries only Apple's own keys.

**2. Start the SDK** with one line of Swift, as early as possible in the app lifecycle:

```swift
import PharenSDK

Pharen.start(granting: [.telemetry, .behavioral])
```

Consent is opt-in, and this line is where you grant it: `telemetry` covers crashes, errors
and performance; `behavioral` covers sessions, screens and `track()`. A started SDK with no
purposes granted runs, and no event leaves the device.

**3. Confirm it end to end.** Build and run the app once, then open **Events** in the
[console](https://console.pharen.ai). The first session's events appear once the app has sent
them: it sends while it runs, and again when it moves to the background. Events are sent by
the running app, so a clean compile proves nothing. If nothing arrives, check that the key
resolved (with an empty or missing key the SDK stays off and `Pharen.start` returns `nil`) and
that the purposes you granted cover what you sent.

The Info.plist keys the SDK reads, the other start forms, and every `PharenConfig` field are in
[Configuration](Guides/Configuration.md).

## Privacy by default

- **Consent is opt-in.** Every event belongs to a purpose — `telemetry`, `behavioral`,
  `identity` or `content` — and is dropped on the device unless your app has granted it.
  Withdrawing a purpose also drops what is already queued under it. `health` is reserved for
  special-category data and can be granted only at runtime, never at start.
- **Traits stay off the event stream.** The traits you pass to `identify()` go to a separate,
  restricted identity store, never into events or logs. Keeping personal data out of event
  properties is your app's job: the SDK refuses a few obvious keys (`email`, `phone`, `name`,
  `address`, `ssn`) on the device, and the platform checks again at ingest. The user id you pass
  to `identify()` rides every later event, so pass an opaque one.
- **Your organization is stamped by the server**, from the ingest key; the SDK never sends it.
- **A privacy manifest ships inside the framework**, so Xcode's privacy report includes the
  SDK's entries. Taking the defaults means your app collects an email address through the
  report form; one setting turns that off.

[Consent and privacy](Guides/Privacy.md) has the details, the privacy manifest
(`PrivacyInfo.xcprivacy`) and how to answer App Privacy.

## Sample app

`Sample/PharenSample.xcodeproj` is the smallest app that starts the SDK: one row per capability
with its whole integration behind the button; a settings screen with the report flow in its
own menu, consent switches, and a live readout of what a report would carry; and the privacy
posture stated. Open it, put your ingest key in its `Info.plist`, run. `Sample/README.md` has
the three steps.

## Guides

Each capability has its own guide in [`Guides/`](Guides). The platform around the SDK — keys,
the console, symbol upload, environments, the support policy — is documented at
[www.pharen.ai/docs](https://www.pharen.ai/docs), and [AGENTS.md](AGENTS.md) is the condensed
version for coding agents.

| Guide | What it covers |
|---|---|
| [Configuration](Guides/Configuration.md) | The Info.plist keys, the start forms, configuring in code, every `PharenConfig` field |
| [Consent and privacy](Guides/Privacy.md) | The purposes and what each gates, the restricted stores, the privacy manifest |
| [Analytics and identity](Guides/Analytics-and-Identity.md) | `track`, `screen`, `identify`, `reset`, traits, continuity without sign-in |
| [Sessions](Guides/Sessions.md) | Automatic sessions, and how each launch is reported |
| [Crashes and errors](Guides/Crashes-and-Errors.md) | Fatal crashes, hangs, exits no report describes, handled errors, breadcrumbs, symbols, other crash reporters |
| [Performance](Guides/Performance.md) | App start, screen render, network timing with trace context, thermal state |
| [Ratings](Guides/Ratings.md) | The system rating prompt and the rating question, under a policy you serve |
| [Feedback](Guides/Feedback.md) | The reporting sheet, reports about one thing, NPS and CSAT, shake, the reporter's address, the dev build panel |
| [Deep links](Guides/Deep-Links.md) | Inbound universal links, routed on the platform's confirmed destination when it answers in time |
| [Push](Guides/Push.md) | Token registration and receipts |
| [Remote config and flags](Guides/Remote-Config.md) | Flags, the remote stop, what an install does while the platform does not serve it |
| [App notices](Guides/App-Notices.md) | Update required, retired, outage, kill switch and waiting room covers |
| [Field diagnostics](Guides/Field-Diagnostics.md) | The network trace, pictures with a report, privacy masks |
| [Storage](Guides/Storage.md) | The app's storage footprint, the cleanup funnel, storage pressure |
| [Monetization](Guides/Monetization.md) | The paywall, purchase and usage-limit funnel |
| [Delivery](Guides/Delivery.md) | The offline queue, batches, backoff, holds, and how events are scoped |
| [Localization and branding](Guides/Localization-and-Branding.md) | 21 languages, string overrides, the remote app brand |
| [API overview](Guides/API-Overview.md) | Every module's entry point and the public types |

## Contributing & security

This repository publishes the compiled SDK and its guides: it does not accept pull
requests, and issues are not the support channel. Questions and support route through
[pharen.ai](https://www.pharen.ai). Something broken, confusing, or missing? Tell us at
**hello@pharen.ai** — the exact command, the expected result, and the actual output, error
text verbatim, gets the fastest turnaround. To report a security vulnerability, email the
same address — see [SECURITY.md](SECURITY.md).

## What is in the archive, and how to check it

`Package.swift` names the release archive and its SHA-256; `swift package compute-checksum
PharenSDK.xcframework.zip` on a downloaded copy reproduces the value. Inside the archive:

- `ios-arm64/`, `ios-arm64_x86_64-simulator/`, `macos-arm64_x86_64/` — one dynamic
  `PharenSDK.framework` per platform, each with `Modules/PharenSDK.swiftmodule/*.swiftinterface`
  (the public interface, readable), `*.swiftdoc` (its documentation, shown in Quick Help),
  `PrivacyInfo.xcprivacy`, and the 21 `*.lproj` localizations (`Localizable.strings`);
- `LICENSE.md` — the SDK license, the same text as at this repository's root;
- `LEGAL-TERMS.txt` — the Terms of Service and Acceptable Use Policy as they read when this
  release was published, the same text as at this repository's root; the terms travel with the
  archive.

The framework links Foundation and the system frameworks only (`otool -L` on the binary
lists nothing else), and declares no package dependencies.

The archive is codesigned by **Lucubra LLC** (Apple Developer team `B542UD8K77`), the company
that operates Pharen — the same entity the Terms of Service and `LICENSE.md` name.
`codesign -dv --verbose=2 PharenSDK.xcframework` shows
`Authority=Apple Distribution: Lucubra LLC (B542UD8K77)`; Xcode shows the signer in the
inspector and asks before accepting a release whose signer changed.

## License

Licensed, not sold, under Schedule A (Software License), Part C, of the Pharen Terms of
Service — https://www.pharen.ai/legal/terms#schedule-a — see [LICENSE.md](LICENSE.md). Not
open source. The integration glue (the fastlane plugin, the release-lane template) is MIT.
