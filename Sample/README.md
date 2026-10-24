# Pharen sample app

The smallest app that starts the SDK, with one row per capability and a settings screen that
opens the report flow from its own menu — the way an app embeds it.

Before resolving the SDK, read [its license](../LICENSE.md) and the release's
[legal text](../LEGAL-TERMS.txt). For organizational use, an authorized representative
should agree through [onboarding](https://onboard.pharen.ai/start) or arrange written
acceptance with [hello@pharen.ai](mailto:hello@pharen.ai); automated package resolution
does not record that agreement. The sample's separate 0BSD license does not license the SDK.

1. Open `PharenSample.xcodeproj`. The package is the one at this repository's root; the
   sample resolves the compiled framework the manifest names.
2. Set your ingest key: the `PHAREN_INGEST_KEY` build setting (Build Settings, or
   `xcodebuild … PHAREN_INGEST_KEY=…`), or replace the value under `PharenIngestKey` in
   `PharenSample/Info.plist` with the key itself. It is public by design — it scopes what the
   app sends to one app and one environment, and reads none of your data back. With the key
   empty the SDK stays off, and the home screen says so.
3. Run on a device or the Simulator. Each row's button is that capability's whole integration;
   the code behind it is the file next to it.

What it shows: a handled error and a deliberate crash (crash reporting); a tracked event and
screen views (sessions & analytics); the report flow from a button and from two settings rows
(feedback); a contextual report, NPS, CSAT and rating question through their existing public
calls, with the returned presentation or eligibility shown by the sample (the surveys and
rating question need served policies before they can appear); consent switched at runtime —
`health` runtime-only, and reserved — with a live
readout of what a report would carry (grant `health` and the pictures row turns off) and a
switch that turns pictures off on the install; `identify`; an inbound link's domain (deep
links); and the privacy posture, stated in the words the SDK keeps.

The project is generated from `project.yml` with XcodeGen 2.45.4 and committed, so nothing
needs installing to open it; edit the YAML and regenerate with that version to change it.

## License

The files in this sample directory are available under [0BSD](LICENSE.md):
you may copy, adapt and distribute them. The SDK it links, its interfaces,
debug information and trademarks keep their separate terms in
[the SDK license](../LICENSE.md).
