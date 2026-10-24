# Security policy

## Reporting a vulnerability

Email **hello@pharen.ai** with a description of the issue, the affected version, and
reproduction steps if you have them. Please do not open a public issue for a suspected
vulnerability. You will receive an acknowledgment, and a fix (when one is warranted)
ships as a new SDK release with a CHANGELOG entry.

## Supported versions

Support follows the [SDK support policy](https://www.pharen.ai/docs/sdk-support#commitment).
Supported versions receive critical-defect fixes as drop-in patches in the same minor line.
The policy states the support window and end-of-support/end-of-life notice periods;
only privacy or security defects may shorten them. A crash defect alone does not.
Published archives remain immutable: a patch is a new release.

## Scope notes

- **The archive is signed by the company that operates Pharen.** `PharenSDK.xcframework` is
  codesigned as a whole by Lucubra LLC (Apple Developer team `B542UD8K77`) — the entity named
  in the Terms of Service and in `LICENSE.md`. Verify with `codesign -dv --verbose=2` on the
  unpacked archive; the manifest's SHA-256 pins the bytes independently of the signature, so a
  substituted archive fails resolution before its signature is ever read.

- **Zero third-party dependencies — Foundation and Apple's system frameworks only.** The
  supply chain is reviewable from this repository alone: the manifest declares one binary target and no package
  dependencies, the framework links only system frameworks (`otool -L`), and the archive is
  pinned by SHA-256 in the manifest, so no transitive package and no substituted archive
  can introduce behavior the release does not carry.

- **The ingest key is a public, organization-bound client credential.** It ships inside the app
  binary by design and is extractable from any distributed build; its security property is
  not secrecy but *scope*. Every request it authenticates is confined to the one organization the
  key is bound to — the server stamps `org_id` from the credential (no client value is
  read) and either derives `app_id` from a per-app key or checks the one a client sends against
  the credential's scope, refusing any other (this SDK sends none) — so a key can never read or
  write another organization's data. The server decides `environment` from the credential too: a build
  may declare one of that organization's test environments, which a test key may use and a live key
  never does, so a declaration can neither reach the live environment nor create one, and the
  SDK never stamps an environment itself. Within that organization, the key authenticates a bounded set of
  endpoints, not events alone:
  - `POST /v1/batch` — submit events.
  - `POST /v1/identity` — write identity traits (which may be PII) to the organization's
    restricted attribute store. This is a *write* into a store the key cannot read back.
  - `GET /v1/config` — read this app/build's remote SDK config (the SDK kill switch, delivery
    settings, rating rules, feature state). A read, scoped to the credential.
  - `POST /v1/push/register` — register this install's push token.
  - `POST /v1/feedback/{id}/contact` — attach a way to reach the reporter to a report
    already accepted. A write into the same restricted store, never readable by the key.
  - `POST /v1/diagnostics/declare` and the upload it authorizes — a diagnostic bundle for a
    report or a crash. A write; bundles are not readable by the key.
  - `GET /v1/builds/latest` — read the pointer to the app's newest installable build. Treat
    the returned install/download URL as reachable by any holder of the key; do not put a
    build behind this route that the key's audience should not be able to fetch. Read only
    when the developer panel opens (debug, ad-hoc and in-house builds).
  - `GET /v1/sdk/lifecycle` — read the support status of the SDK version the request names.
    Read only when the developer panel opens, and not in in-house builds.
  - `POST /v1/links/lookup` — resolve a link the app was opened with to its current
    destination and campaign. A read of the organization's own link data, by the link's URL.
  The key does **not** grant read access to the event stream, analytics, or another app's
  scope, and it cannot elevate to the console or query planes (those use distinct credentials).

- **The SDK kill switch, served.** Cached on the device and applied before anything is
  recorded, so a killed SDK stays killed across launches — but it cannot rescue an app that crashes before
  its first successful config fetch. The SDK has no client-side crash-loop breaker; it only
  thins the crash reports a looping build sends.

- **On-disk state is protected at rest.** Everything the SDK persists (pending events, crash
  reports, failed identity payloads, diagnostic bundles) lives under Application Support with
  Data Protection class `completeUntilFirstUserAuthentication` and is excluded from iCloud/
  Finder backup, so nothing the SDK spools is restored onto another device.
