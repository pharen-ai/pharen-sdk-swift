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

Registration is gated by `behavioral` — without it the token never leaves the device — and
carries the build's APNs environment (sandbox or production). A token handed over while the SDK is switched off, or while push is not
being provided to this install, is kept on the device and sent once it is.
