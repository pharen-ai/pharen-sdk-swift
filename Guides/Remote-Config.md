# Remote config and flags

Part of the [PharenSDK guides](../README.md#guides).

The SDK fetches its configuration at every launch, and on returning to the foreground at most
about once an hour; repeated failures back it off. It keeps the last good answer on the device,
and an unchanged document costs next to nothing to check. A change you make also reaches devices
that are in use and sending, within about fifteen minutes, without waiting for them to return to the foreground. A failed fetch changes nothing: the cached document stays in force. Remote config carries the kill switch, what leaves the device and when (see
[Delivery](Delivery.md)), rating rules, the prompt budget, the shake and diagnostics switches, the report form's contact mode, and your own
flags.

```swift
let dark = Pharen.shared?.remoteFlag("myapp.feed.dark_mode")?.boolValue ?? compiledDefault

NotificationCenter.default.addObserver(forName: Pharen.remoteConfigDidApplyNotification,
                                       object: nil, queue: .main) { _ in
    // a genuinely new document is in force — re-read the flags you gate on
}
```

`remoteFlag(_:)` returns a `PharenFlagValue` (`boolValue`, `numberValue`, `stringValue`) or
`nil` when the key is absent or nothing has been fetched yet; keep your compiled default as
the fallback. The SDK attaches no meaning to any key. The notification posts from a
background context only after a changed document is applied — never for an unchanged one.

**Flags are configuration, not secrets.** The served document — every flag value included — is
fetched with the ingest key that ships inside your app, so anyone who holds the app can read
every value. Put feature switches, thresholds and copy variants in flags; never a credential,
an API key, or anything you would not print in the app's own source.

## Kill switch — what it can and cannot rescue

The remote kill switch is cached on the device and applied before anything is recorded, so a
killed SDK stays killed across launches, including offline ones. Its limit: an app that crashes
**before the first configuration fetch ever succeeds** can never receive the kill. The SDK has
no client-side crash-loop breaker — it only thins the crash reports a looping build sends (see
[Delivery](Delivery.md)); what contains a bad build is the compiled `sdkKillSwitch` and the
cached remote kill from any earlier successful fetch.

A switched-off SDK — compiled or served — captures nothing and sends nothing: no batch, no
crash upload, no identity update, no push registration, no report address or diagnostics — and it
asks for no rating sheet, by any path. What
it captured before the switch stays queued on the device, and goes once the switch is off. The
configuration fetch alone continues, because it is how a served switch is turned off again.

## When the platform does not serve an install

Every response the SDK reads can say that the platform is not serving this install right now,
and the SDK reads that before anything else in the answer. It is never an error your app sees:

- **Held** — the SDK keeps capturing, within the budget it keeps on the device (30 MB and
  15 000 items), and sends nothing. When the install is served again, what it kept is sent, one
  batch per send cycle. Reports, NPS and CSAT are refused (`reportRefusal` is `.withheld`), and
  so are rating prompts.
- **Stopped** — the SDK captures nothing and sends nothing, and deletes what it was holding:
  queued events, crash reports, identity updates, report addresses and the remembered reporter
  address, diagnostic bundles. Feedback is refused as `.collectionOff`, rating prompts as
  `withheld`. A crash still counts as a failure toward the ratings ladder's
  `minSessionsSinceFailure`, and nothing about it is kept.
- **Terminated** — the same as stopped, and the SDK does not ask again. A new build of your app
  asks once, at its first launch.

While held or stopped, the SDK asks whether it is served again at launch and on returning to the
foreground, when the interval the platform named has passed — between an hour and thirty days —
with one configuration request that carries no identifier of any person or install. The startup
wait for a crash report is skipped, because that upload will not be made. Your consent API,
`remoteFlag` (its last values), deep-link parsing and identify all keep working on the device.

Separately, the platform can withhold one capability at a time — `feedback`, `ratings`, `push` or
`diagnostics` — through the served configuration. A withheld capability refuses through the
results its surface already has (`.withheld` for reports and rating prompts, `isCollecting`
`false` for diagnostics, a kept-but-unsent token for push), and stays withheld until a document
without it arrives, however old the document is.

Every request the SDK makes names it in a `Pharen-SDK` header — the SDK version, your app's
version and build, and the build's distribution class — and carries `User-Agent:
pharen-ios/<version>`. Your app's own requests, and any `User-Agent` your app sets on them, are
untouched.
