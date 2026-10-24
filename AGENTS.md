# AGENTS.md — integrating PharenSDK (for AI coding agents)

You are integrating **Pharen** (https://www.pharen.ai) into an iOS app: crash reporting, sessions
& analytics, identity & consent, remote config, feedback, rating prompting, deep links, field
diagnostics and storage observability — one SDK, no third-party dependencies, system
frameworks only. This file is the condensed, agent-oriented version of `README.md` and the
capability guides in `Guides/`; https://www.pharen.ai/docs covers the platform around it.

## The shortest correct path

Before resolving the package, present [the SDK license](LICENSE.md) and the selected
release's [legal text](LEGAL-TERMS.txt) to the person responsible for the integration.
Schedule A, Part C governs this proprietary SDK. For organizational use, an authorized
representative should accept through [onboarding](https://onboard.pharen.ai/start) or
arrange written acceptance with [hello@pharen.ai](mailto:hello@pharen.ai). An agent's or
package manager's download is not evidence of that representative's agreement.


1. **Add the package** (Swift Package Manager):
   ```swift
   .package(url: "https://github.com/pharen-ai/pharen-sdk-swift.git", from: "2.0.0")
   ```
   and add `"PharenSDK"` to your target's dependencies. The SDK is a compiled framework:
   resolution downloads `PharenSDK.xcframework.zip` from this repository's Releases and verifies
   its checksum, so the build machine needs to reach `github.com`. Requires Xcode 26.0.1 or
   newer (the README states the floor for each release).

2. **Set the ingest key.** Each app and environment has an ingest key, issued once the
   application is approved (https://www.pharen.ai/docs/api-keys explains how). Add
   `PharenIngestKey` to the app's `Info.plist`; for a key per build configuration, set it to
   `$(PHAREN_INGEST_KEY)` and define `PHAREN_INGEST_KEY` per configuration in build settings or
   an xcconfig. The key is public by design: it submits data for one app and environment and
   cannot read your event data back (`SECURITY.md` lists the few lookups the SDK makes with it),
   so it may be committed. Consent is not set here: it is granted in code (step 3).
   `Guides/Configuration.md` § The Info.plist keys lists every key the SDK reads (`PharenIngestKey`,
   `PharenConsentGrantedAtBuild`, `PharenIngestBaseURL` (development builds only),
   `PharenLinkDomains`, `PharenFeedbackContact`, `PharenAppEnvironment`).

3. **Start the SDK** — one line, as early as possible in the app lifecycle:
   ```swift
   Pharen.start(granting: [.telemetry, .behavioral])
   ```
   `telemetry` covers crashes, errors and performance; `behavioral` covers sessions, screens and
   `track()`. This is the code form; `PharenConsentGrantedAtBuild` in `Info.plist` is the alternative
   when you prefer configuration — and when both are present, **the code value replaces the
   plist value**. Settings that are deliberately code-only (rating thresholds, what a report
   carries, shake, the UI language, storage directories) go in the block after the line:
   ```swift
   Pharen.start(granting: [.telemetry, .behavioral]) { config in
       config.ratings = PharenRatingSettings(minCheckpoints: 5)
   }
   ```
   Rating prompting itself is turned on by the `ratings` policy written in the console, never by
   compiled rules alone — an install with no policy refuses every checkpoint as `config_pending`.

4. **Verify before claiming success** — never assert the integration works without this loop:
   build and launch the app (the Simulator is fine), then confirm the first events arrived
   server-side: in the console's **Events** page (https://console.pharen.ai), or over MCP (below)
   with `pharen_query`. Events are sent by the running app — while it runs, and again when it
   moves to the background — so a clean compile proves nothing. With an empty or missing key
   the SDK stays off and `Pharen.start` returns `nil`.

## Swift 6 / strict concurrency

The framework is compiled with complete strict-concurrency checking in the Swift 5 language
mode. Its public surface is `Sendable`, so a plain `import PharenSDK` works in Swift 6
language mode; `@preconcurrency import PharenSDK` is not needed.
Idiomatic use is to read `Pharen.shared` at each call site rather than caching the instance in
your own singleton.

## Consent is the gate on everything

Purposes: `telemetry` (crashes, errors, performance, storage footprint, the SDK's own
`sdk.error` self-reports) · `behavioral` (sessions, screens, `track()`, deep-link opens, push
receipts, rating and monetization events) · `identity` (`identify()` — its traits go to the identity
store, never the stream) · `content` (user-submitted feedback) · `health` (special-category).

`health` is reserved in this version: no API writes the special-category store. It is a runtime
opt-in only — rejected in the plist and in `start(granting:)` — so keep it out of any "grant all"
action a banner offers: a runtime `setConsent(granted:)` stores exactly the set it is given. A grant
changes one thing the SDK collects: diagnostic attachments default off. Once the app has masked its
screens it turns them back on with `config.diagnostics.attachments.enabled = true` in the start
block, or `diagnostics.attachments.enabled: true` in remote config, which cannot widen a build that
compiled `false` (the compiled settings nest by part and spell the way remote config does).
`Pharen.shared?.diagnostics.attachmentAvailability` reads the live state, and
`diagnostics.setAttachmentsEnabled(false)` turns pictures off on an install at runtime, persisted —
it only ever narrows, so it is safe behind a settings switch.

An event whose purpose is not granted is **dropped at the boundary** — no error reaches the
caller, and the drop is counted in the SDK's own error reports under the key
`consent.denied_drop` (see **SDK health** below) — that is the privacy design, not a bug. If events are missing, check consent before anything else:
`Pharen.shared?.consent.granted`. Zero purposes granted ⇒ the SDK runs but nothing leaves the
device. Runtime changes go through `Pharen.shared?.consent.setConsent(granted:)` (or `grant` /
`revoke`) and persist across launches; the value passed at start is a first-run baseline, not
an override of what the person later chose.

## Module map (call → proof)

Verify each module by observing its data server-side (console, or the MCP tools below) — not by
the call returning. The metrics named below are a starting point, not the reference: the live
catalog is the authority on every metric's name, dimensions and filters. Read it with
`pharen_list_metrics` over MCP, or in the console's metrics catalog, before writing a query.

| Module | Call | Server-side proof |
|---|---|---|
| Analytics | `Pharen.shared?.track("name")`, `.screen("Name")` | `events.count` metric (group by `type`); console Events |
| Sessions | automatic — starts at launch, ends after 15 minutes without activity or 4 hours of life; every start after the first names the session before it | `sessions.count` metric; `session.start` / `session.end` in console Events |
| Identity | `Pharen.shared?.identify(userId, traits:)` — your own id for this user, the one your sign-in system uses (opaque is best; an email or phone works, spelled the same way every time, and a development build logs a warning about one), and scalar traits (`email`, `phone`, `name_given`, `name_family`, `name_display`, `username`, `group_id`, `plan`, your own keys; `NSNull()` removes a key; up to 64 keys and 16 KB per call; whatever the store would not take is refused on its own and reported, the rest still goes); kept on the device across launches (`identity.persistence`), so call it when someone signs in and `Pharen.shared?.reset()` when they sign out (`reset(.userAndInstall)` also gives the next person a new install) — and `.identifyDevice(deviceId:attributes:)`. The SDK's manifest declares User ID and everything the install sends as linked — it all carries the persistent install id, and `identify()` and the report form's contact field (visible by default) tie it to a person — so answer App Privacy as the privacy report shows; a narrower answer is the app's own judgment against Apple's criteria (`Guides/Privacy.md`, Privacy manifest) | the `identity.identify` event, visible in console Events, and `user_id` on every later event from the install (traits never appear on the event stream — restricted store, by design) |
| Crashes | automatic; handled errors via `crashReporting.recordError(_:stack:severity:breadcrumbs:)`; a trail via `crashReporting.leaveBreadcrumb(PharenBreadcrumb(category:message:level:data:))` — the last hundred ride every crash report, and a crumb whose `data` is not JSON is refused (`false`, logged), never the report. To prove the pipeline: upload your app's dSYMs (https://www.pharen.ai/docs/crash-reporting lists the ways; the SDK ships without debug symbols, so a frame inside it reads `PharenSDK + 0x…`), then `Pharen.crashTest()` (or launch a Debug build with the `-PharenCrashTest` argument), relaunch, and look for the symbolicated issue | console Issues; `crashes.count` metric; `pharen_issues` over MCP (next launch delivers, not crash time) |
| Performance | `performance.startScreenRender(_:)` / `.endScreenRender(_:)`, `.recordNetwork(...)`, `.recordAppStart(cold:durationMs:)`, `.recordThermalState(...)`, `.recordSessionSummary(_:)` | `events.count` filtered by `type=perf.*`; `perf.sessions.count`, `perf.serious_seconds`, `perf.critical_seconds`, `perf.duration_ms` metrics |
| Feedback | `Pharen.shared?.presentFeedbackSheet()` opens the SDK's reporting flow, a kind picker (problem / improvement / question) then the form for the kind chosen (shake opens it by default); `presentFeedbackSheet(category: .bug)` skips the picker, and the kind rides the report as its category. A report about one thing in your app: `presentFeedbackReport(category: .bug, context: details)` (`context` ≤ 2,000 characters, refused whole) opens the form with your context shown read-only above the field. Every presenting call is main-actor only and answers a `PharenFeedbackPresentation` — `.presented`, `.refused(reason)` (the form opened to say why), `.unavailable` or `.invalidContext`; show your own "couldn't open" only on `.unavailable` and `.invalidContext`. The sheet is the only way a report reaches the platform: there is no submit call, so do not build your own form; the sheet shows "Sent" itself, only once the report is accepted. `feedback.reportRefusal` says why a report would be refused, before anything opens. On a plan without white-label every step ends in "Powered by Pharen", plain text, drawn only once fetched configuration says so | `feedback.reports` metric; console Feedback (needs `content` consent) |
| Ratings | `ratings.requestRatingIfEligible(scene:)` — **off until a `ratings` policy is written in the console** (`ratings.enabled: true`, versioned with an actor and a note); compiled `PharenRatingSettings` carries thresholds only, and a prompt is never presented from them alone | `ratings.prompts` / `ratings.accepted` / `ratings.declined` metrics; a `rating.refused` event names the first rule that said no |
| Remote config | applied automatically at start/foreground; read `Pharen.shared?.remoteFlag("key")?.boolValue ?? compiledDefault`; observe `Pharen.remoteConfigDidApplyNotification` | `config.rollout` metric — group by `config_version` AND `config_rule`, or a staged rollout reads as fully landed |
| Deep links | SwiftUI: `.pharenDeepLinks { url in router.open(url) }` on your root view. UIKit: `deepLinks.handle(userActivity)` from your scene delegate. Routing: `deepLinks.onLink`, and `deepLinks.onLinkResolved` for the confirmation of a link routed before it arrived; domains: the app's link hosts are served, `deepLinks.linkDomains` adds your own (+ the `applinks:` entitlement) | `links.opened` metric; the console's Universal links page shows what is served for your domains |
| Push | `push.register(token:)` from `didRegisterForRemoteNotifications…`; `push.handle(payload:)` from the receive callback | registration accepted server-side; `push.received` in console Events |
| Background wakes | `Pharen.shared?.recordRunCause(.geofence)` from the callback the system woke you with — optional, and only for those six causes; a link, a notification and a person's own launch already name themselves. Each cause's callback, and where the call goes, is in **Naming a wake** below. **Returns `true` when the cause was taken** and `false` when it was not (the launch window has closed, or the cause is one iOS never has); a refusal also explains itself in the log once per process | `launches.count` grouped by the run's reason (the catalog names the dimension); the console's Launches and background wakes section splits wakes from opens |
| Diagnostics | automatic — a bounded window of recent requests rides feedback reports and crash reports as a bundle; route your own `URLSession` through `diagnostics.recordNetwork(metrics:)`; mark private views with `.pharenPrivacyMask()` — no picture of the screen is taken while one is on screen; `.pharenPrivacyMask(.coverRegion)` fills just its rectangle instead | the bundle attached to the report or issue in the console |
| Storage | automatic footprint snapshot at start; `storage.recordUsage(stores:)`, `storage.reclaimed(...)`, `storage.pressure(...)`; cleanup funnel `cleanupScanCompleted(...)`, `cleanupMarked(...)`, `cleanupFreed(...)` | `events.count` filtered by `type=storage.*` / `cleanup.*`; `cleanup.marked_bytes` / `cleanup.freed_bytes` metrics |
| Monetization | `Pharen.shared?.monetization.paywallShown(surface:)`, `.purchaseCompleted(plan:trial:surface:)`, `.limitResolved(limit:outcome:)` | `monetization.paywall_views` / `monetization.purchases` / `monetization.limit_resolutions` metrics |

Typed monetization, cleanup, performance and storage reports return a discardable
`PharenReportSubmission`: `.submitted` or `.refused(reason)`. Routine calls may ignore it;
optional calls also return `nil` when the SDK is absent. Submitted means valid input was copied
within the bounded input limits and scheduled, not that it reached the queue, disk or server.
Refusal reasons are `invalidInput`, `collectionOff`, `consentRequired` and `unavailable`.
Reports with invalid arguments refuse as a whole, without throwing or silently repairing them.
Input and handoff bounds are documented on `PharenReportSubmission`.

#### Why a run happened — and who says so

`app.launch` carries a `reason` from one closed list. Most of it is handled for you; six of the
twelve are the only ones you ever name.

| reason | who names it |
|---|---|
| `user` | **automatic** — read from the app being in front of the person, with nothing else said |
| `unknown` | **automatic** — the process ran in the background and nothing named a cause |
| `prewarm` | **automatic** — the system ran the launch sequence ahead of the person |
| `url` | **automatic** — from `deepLinks.handle`, or from the launch itself |
| `push` | **automatic** — from `push.handle`, or from the launch itself |
| `location` | from the launch itself where the system still says so, otherwise **yours to name** |
| `bluetooth` | from the launch itself where the system still says so, otherwise **yours to name** |
| `geofence` | **yours to name** — nothing else can |
| `fetch` | **yours to name** — nothing else can |
| `background_task` | **yours to name** — nothing else can |
| `boot` | not applicable here — nothing starts an iOS app this way |
| `system` | not reported here |

**Name `location` and `bluetooth` anyway**, from their callbacks: the launch itself may not say so,
and on an app with scenes often does not, and naming a cause twice costs nothing. `witnessed: false` on a run
always means `user` or `unknown`; naming a cause is what moves a run out of that pair.

#### Naming a wake — one call, six causes, six callbacks

Call it after `Pharen.start`: before it there is no run to name and the call does nothing. Start
the SDK at launch (step 3), never from a view — a wake opens no view. Put the call at the top of
the callback, before your own work, so it is inside the moment the run is still being reported.

**`geofence` — a monitored region boundary was crossed: `didEnterRegion` or `didExitRegion`.**

```swift
func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    Pharen.shared?.recordRunCause(.geofence)
    // … your own work
}
```

**`location` — the system delivered location and did not say which kind: a significant-change
update or a visit, in `didUpdateLocations` or `didVisit`.**

```swift
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    Pharen.shared?.recordRunCause(.location)
    // … your own work
}
```

**`bluetooth` — the system relaunched the app to hand back a connection it was restoring.**

```swift
func centralManager(_ central: CBCentralManager, willRestoreState state: [String: Any]) {
    Pharen.shared?.recordRunCause(.bluetooth)
    // … your own work
}
```

**`fetch` — a `BGAppRefreshTask`, run on the system's schedule rather than yours.**

```swift
BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.refresh", using: nil) { task in
    Pharen.shared?.recordRunCause(.fetch)
    // … your own work, then task.setTaskCompleted(success:)
}
```

**`background_task` — a `BGProcessingTask` you scheduled came due.**

```swift
BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.export", using: nil) { task in
    Pharen.shared?.recordRunCause(.backgroundTask)
    // … your own work, then task.setTaskCompleted(success:)
}
```

**`boot`** has no iOS equivalent. The case exists so one shared mapping in your own code can
carry it on both platforms; `recordRunCause(.boot)` is **refused here**: it returns `false` and
says so in the log.

Only a call made just after the app starts is heard, so these callbacks firing all day costs
nothing. But what you name IS what the run reports: a callback that also fires in that first
moment of an ordinary open names that open too. Where a callback runs in both cases — location
updates you had already requested, rather than a crossing — gate the call on whether your OWN
first view has appeared, not on `applicationState`, which reads as the background at the start
of an ordinary open in an app with scenes.

### SDK health

The SDK reports its own failures as `sdk.error`, at most once per key per launch (and at most five distinct keys per launch, later ones dropped):
the catalog's SDK error metric, grouped by `error_key`, is the health channel. `consent.denied_drop` there means the
consent gate is discarding events (a mis-granted purpose, not lower traffic); `config.fetch_failed` means the remote-config credential
cannot be confirmed live; `transport.offline` is benign in moderation; `identity.trait_refused`
means a trait bag the app passed broke the store's shape rule (`non_scalar=N`, `non_finite=N`,
`unsupported=<types>`, `over_cap=N`, `over_bytes=N` — the rest of the bag went) and
`identity.send_refused` that the platform refused a trait send outright (`status=400`, and the
code beside it in the debug log). Read `sessions.count`
and the catalog's count of installs seen for reach (both default to builds that reached customers), `crashes.count`
for crash health, `ratings.declined` beside `ratings.prompts`, and the `monetization.*` and `cleanup.*`
metrics for the funnels. `pharen_issues` is the crash view for an agent: what is crashing,
grouped by cause, newest first, with one representative symbolicated stack per issue — never a
single crash row or a user.

## Give your agent read access to the data (MCP)

Pharen serves a Model Context Protocol server so you can query your own data mid-development
("did my first event arrive?", "how many sessions today?", "any crashes on the latest build?"):

```bash
claude mcp add pharen --transport http https://mcp.pharen.ai/mcp \
  --header "Authorization: Bearer phq_live_…"
```

The query key is a separate, read-only credential, issued per environment and scoped to the
apps it names (https://www.pharen.ai/docs/api-keys). Scope it to the app you are integrating: a key
with no app scope reads every app the organization has, including ones added later.
The prefix says whether it is live or test: a `development` key starts `phq_test_`, a `production` one
`phq_live_` (the header above shows the production shape).

Tools: `pharen_list_metrics` (the catalog — call it first), `pharen_apps` (the apps you may
name, by name and id — call it when a question names an app in words), `pharen_query`, `pharen_issues`,
`pharen_issue` (one issue with the report behind it — the words of a report ride a key minted
with the `report_text` grant, or a person's own session, as a masked copy), `pharen_user` and
`pharen_user_lookup` (one user, and users found by an exact value — only for a key minted with the
`users` grant and a stated purpose, each read recorded in your user lookup log), `pharen_issue_transition`
(one lifecycle verb, as the person a session is bound to — never a key), `pharen_get_effective_config`,
`pharen_get_rating_policy`, `pharen_set_rating_policy`, `pharen_store_overview`,
`pharen_store_reviews`, `pharen_store_series`. `tools/list` is authoritative if this list and the
server ever disagree. If the first call of a session fails, retry it once before debugging.

## Guides

- https://www.pharen.ai/docs — quickstart and the module index
- https://www.pharen.ai/docs/analytics — sessions, `track()`, `screen()`, the query plane
- https://www.pharen.ai/docs/crash-reporting — capture, symbols, grouping
- https://www.pharen.ai/docs/deep-links — universal links, custom domains, `onLink`
- https://www.pharen.ai/docs/privacy — consent purposes, the restricted store, the manifest
- https://www.pharen.ai/docs/api-keys — ingest keys, query keys, rotation
- https://www.pharen.ai/docs/environments — development / staging / production per build configuration
- https://www.pharen.ai/docs/distribution — test builds and install links
- https://www.pharen.ai/docs/fastlane — the fastlane plugin
- https://www.pharen.ai/docs/xcode-run-script — symbol upload as a build phase
- https://www.pharen.ai/docs/agents — the agent connection
- https://www.pharen.ai/docs/troubleshooting — the FAQ, written from real failures

## Traps that have cost real integrations real time

- **xcconfig comments:** `//` starts a comment anywhere on a line, so a bare URL value
  truncates silently. Escape as `https:/$()/host` if you must put a URL in an xcconfig.
- **XcodeGen users:** an `include:`d spec's `configFiles:` block is dropped silently when your
  own spec has one — the xcconfig mapping must live in **your** project.yml, not the fragment.
  The generated SPM wiring merges fine.
- **Custom Info.plist keys can never come from build settings** — `INFOPLIST_KEY_<name>` only
  carries Apple's known keys and drops custom ones silently. The plist must reference
  `$(PHAREN_INGEST_KEY)` directly; that indirection is what buys the per-configuration split.
- **An empty ingest key is the documented OFF switch** — if the xcconfig mapping is missing,
  `$(PHAREN_INGEST_KEY)` expands to `""` and the SDK stays silent while everything compiles.
  `Pharen.start` returning `nil` is the sign; check it whenever events are mysteriously absent.
- **The ingest key is public by design** (it ships in the binary; the server scopes and
  validates everything). Do not treat it as a secret. A **query key is a secret** — never
  commit one.

## When you are stuck

1. Check that `Pharen.start` returned an instance, that the purposes granted cover what you sent,
   and what the console's **Events** page shows — then search.
2. The troubleshooting FAQ and the module guides, linked above.
3. Tell us at **hello@pharen.ai** at the moment of friction. A report that quotes the exact
   command, expected result, and actual output — including error text verbatim — is acted on
   fastest.
