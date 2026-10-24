# Crashes and errors

Part of the [PharenSDK guides](../README.md#guides).

Fatal crashes — uncaught exceptions and signals — are written to disk at crash time and
uploaded on the **next** launch, stamped with the session they happened in. A crash is counted
once, however many times its upload is retried, and its report stays on the device until the
upload is settled.

**Deaths no report describes.** A memory kill, a watchdog kill, a force-quit: none of these runs
a handler, so none leaves a report. The next launch reports them instead, as `app.exit` — the
last event of the session that died, with a `reason` (`memory`, `watchdog`, `crash`, `user`,
`unknown`), whether the app was `in_foreground`, and whether the reason was `witnessed` —
named by the system — or inferred. An inferred foreground death with no report is reported as a
memory kill, which can also be a debugger stop; a death in the background, which nothing tells
apart from a quit while suspended, is `unknown`. A
foreground death the person did not cause counts as a failure for `sessions_since_failure`,
exactly as a crash report does; a background death and a quit do not. `app.exit` rides
`telemetry`.

**Hangs.** When the main thread stops answering for long enough, the system diagnoses the hang
and delivers the diagnostic later — at the next launch, or from iOS 27 sometimes while the app
is still running — and the SDK reports it as `app.anr`: the blocked
main thread as `frames` and `images` — addresses, symbolicated on the platform from your
uploaded symbols, the same way a crash's are — `duration_ms`, how long it lasted, and the
`screen` the app last reported. It is `is_fatal: false` — the diagnostic does not say the process
ended — unless the system ended the app for that hang: a watchdog kill of the same process, a few
seconds after the hang. That hang is reported `is_fatal: true`, with `in_foreground`, and carries
the death itself, so no `app.exit` is sent for it: one death, one event (iOS 17 and later; on iOS
15–16 such a hang is reported recovered, beside the `app.exit`). The frames reported are the path
the system sampled most. A hang is reported with the build that hung; on iOS 17 and later it is
also placed in the session it happened in, with the screen the app last reported, and where the
system does not say which process hung, no session or screen is claimed, and where it says the
hang began before the session did, no session is. A hang the system
reports for a build this install no longer runs, and cannot place, is not reported. Nothing to
turn on, and it rides `telemetry`.

The screen a hang carries is the last name passed to `screen(_:)` in the process that hung — not
necessarily the one on screen at the instant it stopped answering, and absent if the app
reported none. It is kept on the device for that purpose whether or not `behavioral` is granted,
and sent with a hang under `telemetry`: pass a route or screen identifier, never anything about
the person using it.

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

**Symbols.** Crashes are symbolicated server-side against your app's dSYMs, which you upload —
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
