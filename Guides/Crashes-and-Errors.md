# Crashes and errors

Part of the [PharenSDK guides](../README.md#guides).

Fatal crashes from uncaught exceptions and signals are written to disk and uploaded on the
next launch. A crash report with a recorded credential and environment keeps that scope.
The SDK attaches a previous session only when the crash matches its install, scope, and timing.
Retries count as one crash.

**Process exits.** When a process dies without a crash report, the next launch can record an
`app.exit` event. An inferred foreground death reports `reason: memory`, which can also
indicate a debugger stop. An unexplained background death reports `unknown`. A witnessed
force-quit reports `user`. The event includes `in_foreground` and `witnessed`. A foreground
death the person did not cause counts toward `sessions_since_failure`. Exit reporting
requires `telemetry` consent.

```swift
let crashReporting = Pharen.shared?.crashReporting
crashReporting?.recordError("payment failed")                              // severity .error, the trail as crumbs
crashReporting?.recordError(error, stack: Thread.callStackSymbols)         // any Error: its description, domain and code
crashReporting?.recordError("payment failed",
                            stack: Thread.callStackSymbols,
                            severity: .warning,                            // .info · .warning · .error
                            breadcrumbs: ["cart_opened", "pay_tapped"])   // crumbs this call carries on its own
```

**Breadcrumbs.** A trail of the steps that led up to a crash, kept in memory and written
into the next crash report — fatal or handled — as it is captured. Leave one wherever a
later reader would want to know you were there:

```swift
Pharen.shared?.crashReporting.leaveBreadcrumb(PharenBreadcrumb(
    category: "nav",
    message: "opened checkout",
    level: .info,                              // debug · info · warning · error · fatal
    data: ["items": 3]                         // JSON values only, no PII
))
```

The trail keeps the most recent hundred crumbs and travels on every fatal crash report, handled
error and diagnostic bundle automatically — on a handled error, ahead of the crumbs that call
passes. A key in a crumb's `data` that names a person (`email`, `phone`, `ssn`) is dropped
before the crumb is kept, the same rule every event's attributes meet. A crumb that cannot travel — a `data` value outside JSON's
vocabulary, or one over 8 KB — is refused with a logged reason and `leaveBreadcrumb` returns
`false`; the trail and the reports around it are never affected. `recordError` also accepts
a `[String]` trail, as above, each entry becoming an `info` crumb in the `manual` category.

**Symbols.** [Request organization approval](https://console.pharen.ai/setup/application) to move beyond
evaluation.
Approved organizations can use test and live keys, and their paid plan determines
which features and usage limits apply. After approval, crashes are symbolicated server-side
against the matching dSYMs you upload —
[Crash reporting](https://www.pharen.ai/docs/crash-reporting) lists the ways. A late upload
still re-symbolicates and re-groups the crashes that already arrived. The SDK ships without
debug symbols, so a frame inside the SDK reads `PharenSDK + 0x…`: attributed to the SDK, not
named.

When you upload your app, Xcode may warn that the archive did not include a dSYM for
PharenSDK.framework. This is expected: the SDK ships without its debug symbols, which Pharen
holds. The warning does not stop the upload, and your own frames still symbolicate from your
app's dSYMs.

**Proving it.** `Pharen.crashTest()` raises an uncaught exception the installed handlers
capture — relaunch, and the report uploads. In Debug builds the same test runs on its own
shortly after start when the app is launched with the `-PharenCrashTest` argument or the
`PharenCrashTest=1` environment variable, so the capture → next-launch upload → symbolication
chain can be automated.

## Running alongside another crash reporter

Pharen's handlers **chain**: the previously installed NSException handler is called
after Pharen's, and the signal handlers restore whatever sigaction was installed
before `Pharen.start()` and re-raise — so a crash reporter installed *before* Pharen
still sees every crash. If the other SDK also chains (mainstream ones do), install
order barely matters; the simple rule is **start Pharen last**, after any other crash
reporter, so Pharen chains to it. Pharen registers an alternate signal stack only when
no other component has one, and never replaces an existing one.
