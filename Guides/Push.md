# Push

Part of the [PharenSDK guides](../README.md#guides).

System → user transport. The SDK registers the token and reports receipts; it never presents
a notification and never builds a chat surface.

```swift
func application(_ app: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
    Pharen.shared?.push.register(token: token)          // POST /v1/push/register; call it on every launch
}
func application(_ app: UIApplication, didReceiveRemoteNotification payload: [AnyHashable: Any],
                 fetchCompletionHandler completion: @escaping (UIBackgroundFetchResult) -> Void) {
    Pharen.shared?.push.handle(payload: payload)     // emits push.received for Pharen payloads; ignores others
    completion(.noData)                                  // still yours to call
}
```

### In a SwiftUI app

Apple hands an app its push token only through the application delegate. A SwiftUI app with no
delegate of its own adds one: the sample app's
[`PushAppDelegate.swift`](../Sample/PharenSample/PushAppDelegate.swift) is the whole of it, ready
to copy into your app, and one line attaches it:

```swift
@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var appDelegate
    // …
}
```

An app that already has a delegate copies the file's three methods into it instead, a SwiftUI
app attaching one delegate: the two above, and
`application(_:didFinishLaunchingWithOptions:)`, which asks Apple for the token — an app that
never makes that call is never handed one:

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    application.registerForRemoteNotifications()         // on every launch; asks nothing of the person
    return true
}
```

Neither the file nor the SDK asks the person for permission. Registering with Apple's push
service shows nothing to the person; it gives the app the token Pharen sends to. The only
prompt is the one your app asks for, and whether a push is shown is the person's answer to it.
When to ask is your app's decision — `UNUserNotificationCenter.current().requestAuthorization(options:)`, at a
moment the notifications make sense. The SDK reads the answer on its own each time the app
becomes active.

Registration is gated by `behavioral` — without it the token never leaves the device — and
carries the build's APNs environment (sandbox or production). A token handed over while the SDK is switched off, or while push is not
being provided to this install, is kept on the device and sent once it is.
