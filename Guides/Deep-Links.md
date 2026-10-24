# Deep links

Part of the [PharenSDK guides](../README.md#guides).

Inbound only — links are minted on the platform. The SDK accepts universal links on your app's
link hosts, confirms each link with the platform without making the app wait, hands the result to
your router, and reports the open.

```swift
// SwiftUI: one modifier wires both delivery paths and de-dupes the double-fire.
WindowGroup {
    ContentView().pharenDeepLinks { url in router.open(url) }
}

// UIKit: from your scene / app delegate.
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    Pharen.shared?.deepLinks.handle(userActivity)
}

// Your routing hook, and the domains you accept.
Pharen.shared?.deepLinks.linkDomains.insert("myapp.example")
Pharen.shared?.deepLinks.onLink = { link in
    router.open(path: link.targetPath, params: link.params)   // on the main thread, once per open
}
Pharen.shared?.deepLinks.onLinkResolved = { link in
    router.confirm(link)                                      // the confirmation of a link routed as .parsed
}
Pharen.shared?.deepLinks.handle(url: url, deferred: true)     // resolving a deferred link on first launch
```

**Your app's link hosts.** The platform's configuration names the hosts whose links your app
opens — your organization's link host and the custom domains serving your links — and once a launch
has received them, those hosts are matched exactly and a link on any other host is not taken.
`linkDomains` adds hosts of your own (a host, or any subdomain of it); `pharen.link` in it matches
any of its subdomains only until the platform has named your hosts, so a first launch still opens
its links.

**Confirmed, or read from the URL.** On `handle` the SDK asks the platform what the link opens now
and routes on the answer when it comes within a fraction of a second: `link.resolution` is
`.resolved`, `targetPath` and `params` are the link's current destination (which can differ from
the URL), and `linkId` and `campaign` say which link and campaign it was. When the answer is late,
the link routes from the URL at once — `.parsed`, with no id — and is never routed a second time;
the answer, when it comes, reaches `onLinkResolved`. A link that grants something, such as an
invitation, should act on the confirmed value. A link the platform answers in time has ended is
not routed (when that answer is late, the link has routed and no confirmation follows), and while
the platform holds your organization's links none is routed. Answers are kept for five minutes, so
opening the same link again routes at once. A domain you list yourself that the platform does not
serve for your app routes from the URL and is still reported.

The SwiftUI modifier hands `route` every URL as delivered and reports the open; it does not route
on the confirmed destination, and it does not withhold an ended link or a link while your
organization's links are held — those rules apply to `onLink`. To route on it, call `handle` from `.onOpenURL` and
`.onContinueUserActivity` yourself and route in `onLink`. SwiftUI can deliver one open through both
paths: `handle` collapses the repeat for a link on your link hosts, and a URL it returns false for
is yours to route — collapse a repeat of one of those yourself.

`handle` returns true for a link on one of your app's link hosts and false for anything else,
which is yours to route. The same link handed over twice within two seconds — one open arriving through
two delivery paths you both wired, say, or a link opened and then resolved again as a deferred
link — is routed and counted once; the repeat still returns true, so your fallback never routes
it a second time.

Routing fires for every recognized link regardless of consent — navigation is app
functionality; consent gates telemetry only, so the confirmation is asked for whatever the consent
and only the report of the open waits on it. The `deeplink.opened` event, sent once per open after the answer arrives, carries the
host the link arrived on, the deferred flag, whether the open began the session
(`started_session`), and — when the platform answered — the link's id and campaign words; **never
the path or query string**. Every domain in `linkDomains` (or `PharenLinkDomains`) needs its
`applinks:` associated-domain entitlement twin; a Debug build started from the Info.plist forms
logs it when the two drift.
