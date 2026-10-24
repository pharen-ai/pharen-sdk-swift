# Delivery: queue, batches, holds

Part of the [PharenSDK guides](../README.md#guides).

An event call such as `track` or `screen` builds the event on the calling thread and returns;
writing it to disk and sending it run off that thread, and the app is never blocked. Consent is
checked first: an event whose purpose is not granted is dropped there and never stored. A
switched-off SDK records nothing. There is no hook on this path for your own code.

Events are kept on the device until they are delivered, and survive relaunches. A retried event
keeps its id, so the platform counts it once. Events are always sent under the ingest key and
test environment they were recorded with, even when a later launch starts with another — or, if
that key has since been refused as invalid, not sent at all. The SDK sends while the app runs and again each
time it moves to the background. How often it sends, and how much one send carries, are set by
the platform rather than by your configuration, and can change without an app update.

`Pharen.shared?.flush()` asks for a send soon: it returns at once and sends off your thread.
Calls a few seconds apart are combined into one send, so calling it after every event costs no
more than calling it once. It hurries delivery; it does not guarantee it. Nothing is lost while a
send waits: the events stay queued.

**When sending fails.** Failed sends are retried with backoff, and being offline never counts
against an event. `Retry-After` is honored on every request the SDK makes, for up to a day and
across relaunches. A key the service refuses pauses that kind of request for a while, also
across relaunches, with everything kept queued. A single event the service refuses for now, such
as under a rate limit, stays queued and is retried; one it refuses for good is dropped. An event
over 1 MB once encoded is never queued: it is dropped when it is recorded. Because a refused event can be retried on its
own, events can reach the service in a different order from the one they were recorded in.

**What the device keeps.** The SDK keeps at most 30 MB and 15 000 items on the device for
sending, across the queue, crash reports and identity updates; `maxQueueDepth` caps the queue's
share. Past that, it makes room by dropping the oldest events your own calls recorded (tracked
events, screens, screen-render, network and thermal timings, rating, monetization, cleanup and
storage events) before any of its core events (among them sessions, crashes, errors and hangs,
the app start, identity, links and pushes arriving, and everything a person sent). Crash reports
count toward the same budget: an older one can give way, but the newest three are always kept. A device that holds its events for a long time becomes less detailed,
and loses whole sessions last.

## What the platform can hold back

The SDK records every event it is given and sends nothing it was not given; what the platform's
configuration can change is only **what leaves the device, and when**. An event held back stays
queued, within the limits above, and is sent when the rule stops applying, in the session it
belongs to — except what your session sample rate leaves out, below.

- **Degraded mode.** The platform can ask a build to send only its core events for a stated time.
  Core events go, marked as sent core-only; the others wait on the device.
- **Usage limit.** When your organization reaches its plan's allowances, the platform holds what
  devices send until the allowances are raised or the next usage period begins. During the hold
  the SDK still sends crash reports (`app.crash`), hangs that ended the app (`app.anr` with
  `is_fatal: true`), and everything a person sent: feedback reports and survey answers.
  Everything else, handled errors and recovered hangs included, waits on the device and is sent
  when the hold ends. Until a device has received the hold, an event the service refuses for now
  can hold the events behind it back until the device's next configuration refresh.
- **Protective hold.** The platform can hold a build's sends altogether for a stated time, crash
  reports included, which stay on disk. The build sends again when the time is up.
- **Your session sample rate.** If your plan includes it and you set one, each session, and each
  run your app made in the background with nobody present, is kept or left out as a whole. One
  left out sends nothing and is not billed. **Except when it crashes**: then its core events and
  the crash are sent, marked core-only, at the next launch, and it is still not billed. A feedback
  report or survey answer a person sends from a left-out session is sent all the same. The SDK
  applies no sampling of its own.
- **Repeated crashes.** A device sends the first five crash reports of each build, then one a
  day; an app that crashes at every launch before it can send anything reports a few of the
  first crashes, then one a day. Every report held back is counted onto the next one
  that goes out (`represents`), so the platform's crash count stays exact. A hang that ended the
  app counts as a crash.

## Scoping: `app_id`, `platform_app_id` and `org_id`

| Field | Who sets it | How |
|---|---|---|
| `app_id` | Server | The app in Pharen's registry, derived from the ingest key, which is minted for one app; this SDK has no public way to declare it and sends none |
| `build.platform_app_id` | This SDK, observed | `Bundle.main.bundleIdentifier`, read at runtime and sent on every envelope. The platform compares it with the app the key names and flags a mismatch when a key has landed in the wrong app; it never refuses an event for it |
| `build.distribution` | This SDK, observed | **Who was this build distributed to?** `debug` — developers: a debug build, any build run on a simulator, or one signed with a development profile; `tester` — testers, through TestFlight or an ad-hoc install; `store` — the public, through the App Store or an alternative marketplace; `enterprise` — your organization's own people, through an in-house profile; `sideload` — whoever installed it from your website. Absent when the SDK found no evidence, never a guess. Queries group and filter by it; the live metrics catalog (`pharen_list_metrics`, or the console's) names the dimension |
| `build.distributor` | This SDK, observed | **Who supplied it?** `app_store` (the App Store), `testflight`, `ad_hoc` (an ad-hoc provisioning profile), or `other` (an alternative marketplace); absent when nothing supplied it or the SDK cannot prove who — a development-signed or in-house build carries none, and nor does a build whose provisioning profile cannot be read. The `distributor` dimension in queries. A build is on the `released` release track on its own only when this is `app_store`; any other build is on it only once its release is marked released |
| `org_id` | Server | Your organization, stamped from the authenticated `X-Pharen-Ingest-Key`; the SDK never sends it |

The environment is decided server-side, from the key: a live key always sends to your live
environment, and a test key to its own test environment — or to another of your test
environments the build declares in `appEnvironment`. The SDK may declare a test environment, but
it never stamps one: the declaration rides the request, no event carries an environment, and the
platform decides what each request is stamped with.
