# Sessions

Part of the [PharenSDK guides](../README.md#guides).

Automatic, no code. A session is a run of activity in one process, and time ends it: **15
minutes** since it was last seen — the later of its last event and the app leaving the
foreground — or **4 hours** since it started. Leaving the foreground ends nothing; come back
inside 15 minutes and the same session continues, come back later and a new one starts
(`source: resume`). Past four hours the next event starts a new session with the app still in
use (`source: rollover`). A process that dies — a crash, a memory kill, a quit — ends its session
too: the next launch reports that session's end at the moment it was last seen, then starts a
new one (`source: launch`). Every `session.start` after an install's first names the session
before it (`previous_session_id`) and the pause since it (`previous_session_gap_seconds`), so
sessions can be joined under any longer threshold on the platform. `session.end` goes out once
per session and carries its duration; both events ride `behavioral`. Both numbers are the
platform's — one for every platform, not a setting.

A process the **platform** starts — to make a later open feel fast, to deliver a notification,
to hand over a location, to run a task that came due — runs the whole launch with nobody in the
app, sometimes hours before anyone opens it. Such a launch starts no session: events emitted
then carry none, and the session begins at the first foreground, measured from there.

**The run itself is reported**, so a wake is never simply missing: one `app.launch` per process,
riding `telemetry` and belonging to no session, with `reason` (`user`, `prewarm`, `push`,
`geofence`, `location`, `bluetooth`, `fetch`, `background_task`, `url`, `boot`, `system`,
`unknown`), `in_foreground` — a wake or an open — `witnessed`, whether the cause was stated — by
the system, or by your app passing it on — or read by the SDK, and `signals`, every cause named. Only the name of the cause is
kept: no notification payload, link or address reaches the event.

To have a launch a link or a notification caused reported as such, hand them to the SDK as you
already do for those modules (`deepLinks.handle`, `push.handle`), within about a second of
`start`; later calls name nothing, and a late `recordRunCause` returns `false` and logs why. For a cause that reaches a
callback of your own, name it there: `Pharen.shared?.recordRunCause(.geofence)` from
`didEnterRegion` turns a launch the system reported only as `location` into `geofence`. With
nothing handed over, a launch reports `user` in the foreground and `unknown` behind it — a
common answer. Every cause named is kept in `signals`.
