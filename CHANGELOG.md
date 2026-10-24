# Changelog

## 2.0.0 — 2026-10-23

The first Swift Package Manager release of PharenSDK.

### Compatibility

- **Stable API for 2.x.** The public API follows Semantic Versioning: a breaking change comes
  only with a new major version, so `from: "2.0.0"` resolves every 2.x release, and nothing
  public is removed or changed incompatibly before 3.0.0. A later 2.x release can require a
  newer Xcode; the README states the floor for each release. Support windows and
  end-of-support notice periods are in the
  [SDK support policy](https://www.pharen.ai/docs/sdk-support).
- **Platforms.** iOS 15 and later, on device and in the Simulator (arm64 and x86_64), plus a
  macOS 13 slice for test targets. Built with Xcode 26.0.1 (Swift 6.2), the oldest Xcode that
  can read this release's module interface. The public API is `Sendable`, so a plain
  `import PharenSDK` works in the Swift 6 language mode.
- **Install.** Swift Package Manager only, with no third-party dependencies. The package
  resolves one compiled XCFramework, `PharenSDK.xcframework.zip`, from this repository's
  Releases. The manifest pins the archive's SHA-256, and the archive is codesigned. Each
  platform slice carries its module interface, its documentation and the SDK's privacy manifest;
  the archive carries no debug symbols for the SDK. See the README's [Install](README.md#install-spm) section.

### What the SDK does

- **Consent at the boundary.** Every event rides a purpose (`telemetry`, `behavioral`,
  `identity` or `content`; `health` is reserved for special-category data). An event whose
  purpose is not granted is dropped before it is stored or sent, and withdrawing a purpose
  also clears what is already queued.
- **Crashes, hangs and errors.** Fatal crashes, recorded and sent on the next launch;
  system-diagnosed hangs; exits no crash report describes; handled errors with a breadcrumb
  trail. Your app's frames are symbolicated on the platform from the dSYMs you upload; a frame
  inside the SDK is attributed to `PharenSDK`, not named.
- **Sessions and analytics.** Automatic sessions (15 minutes of inactivity, 4 hours at most),
  `track`, `screen`, `identify` and `reset`. Identity traits go to a restricted store, never
  to the event stream.
- **Performance.** App start, screen render, network timing and thermal state.
- **Feedback.** A reporting sheet that opens on a shake or from your own button. NPS and CSAT
  forms, contextual reports, an optional reporter address, and screenshots that respect your
  privacy masks.
- **Ratings.** The system rating prompt and a rating question, both shown only under a policy
  you serve.
- **Deep links and push.** Inbound universal links confirmed by the platform before routing,
  and push token registration with receipts.
- **Remote configuration.** Flags, a remote stop for the SDK, and app notices: update required,
  retired, outage, kill switch and waiting room.
- **Field diagnostics.** Recent network requests and app context attached to reports and
  crashes, under limits you control.
- **Storage and monetization.** The app's storage footprint, cleanup and storage-pressure
  signals, and the paywall, purchase and usage-limit funnel.
- **Delivery.** A durable offline queue with batching, backoff and a bounded on-device budget.
- **Localization and accessibility.** The SDK's own screens ship in 21 languages and support
  Dynamic Type, VoiceOver, Reduce Motion and dark mode.

The [README](README.md) is the overview, each capability has its own guide in
[`Guides/`](Guides), and [AGENTS.md](AGENTS.md) is the condensed guide for coding agents.
