# App notices

Part of the [PharenSDK guides](../README.md#guides).

The configuration can carry notices about your app — written by you in the console, shown by the
SDK with no code in your app. This release draws every notice that blocks the app as a full-screen
cover, one window per scene, above everything your app presents:

- **Update required** — this version may no longer be used. The cover's button opens your App
  Store listing in the app. It is shown only on an install from a store whose OS can run the update.
- **Retired** — this version or app has ended; the button leads to its successor, a web version
  or a help page.
- **Outage** — your service is unusable. The cover checks again by itself every few minutes, and
  its **Try again** checks at once. It stands at most an hour after the last answer that carried
  it.
- **Kill switch** — the break-glass for a build that is flooding your servers, compromised or
  corrupting data. See below.
- **Waiting room** — when you cap how fast launches are admitted, a launch over the cap waits
  behind a cover with no button and is let in as the platform admits it, or after two minutes
  without an answer.

A cover is in the person's language — your words where you wrote them, the SDK's own otherwise —
follows Dynamic Type at every size, is announced by VoiceOver and keeps it inside the cover,
respects Reduce Motion, and follows light and dark mode. It shows your app's icon and nothing
that names this SDK. Override any of the SDK's own words key by key in `Pharen.strings` (see
[Localization](Localization-and-Branding.md#localization)). A debug build is never covered: it logs, once per launch, the
cover it would have shown.

**A failed check never lifts a cover.** A cover ends when an answer no longer carries it, when the
person updates or reinstalls the app, or when one of the bounded clocks above runs out — never on a
timeout, an error or a platform restart. A cover stays standing while the app cannot reach the
platform, and every return to the foreground checks again, so a cover you lift releases people the
next time they open the app.

After the person updates the app, the notices cached for the old version are set aside until the
first answer for the new one, so nobody who has just updated meets the old version's cover. The
first launch after an update reports the version it came from on `app.launch` as `updated_from`.

Showing a notice, and pressing its button, are reported as `app.notice_shown` and
`app.notice_action` under `telemetry`, gated like every event; an install that has not granted
`telemetry` shows the notice and reports nothing.

## The kill switch

A kill stops your app for everyone on the versions it names. While it holds:

- the SDK shows its cover and switches itself off exactly as `sdkKillSwitch` does — it captures
  nothing and sends nothing but its configuration fetch, which is how a kill is lifted;
- your app is told, so it can stop its own timers and network, which the SDK cannot stop for it:

```swift
if Pharen.shared?.appNotices.killSwitch != nil { syncEngine.stop() }
Pharen.shared?.appNotices.onKillSwitchChange = { kill in
    kill == nil ? syncEngine.start() : syncEngine.stop()
}
```

`killSwitch` is set from the first moment of a launch the kill names, and the callback runs on the
main queue each time it changes. It stays set while the device is offline, even when you wrote the
kill to stand aside offline, so work queued offline is not sent the moment the network returns.

A kill holds with no answer while the device is online. With no answer at all, a kill is released
only after the app has failed to reach the platform at launch on at least three separate days
spanning at least six months; a permanent kill never is. An update to a version the kill does not
name, or a reinstall, ends it.

Its honest limits: a kill is a client-side control, not a security boundary. Anything your app
sends before `Pharen.start()` has already gone; your app's own networking keeps running behind the
cover unless it stops when told; a device that never reaches the platform never learns of the
kill; and a modified build can skip it. For a compromised build, your own backend is the boundary:
refuse that build's credentials.
