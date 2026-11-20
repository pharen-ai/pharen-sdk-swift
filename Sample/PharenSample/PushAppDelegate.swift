// Copyright (c) 2026 Pharen
// SPDX-License-Identifier: 0BSD
// See Sample/LICENSE.md for the sample license; the SDK has separate terms.

import PharenSDK
import UIKit

/// Push for an app built with the SwiftUI life cycle, ready to copy.
///
/// Apple hands an app its push token in one place only: the application delegate. A SwiftUI
/// app with no delegate of its own needs one to send pushes through Pharen, and this is all it
/// has to do. Copy this file into your app and attach it in your `App`:
///
///     @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var appDelegate
///
/// If your app already has a delegate, copy the three methods into it instead: a SwiftUI app
/// attaches one delegate.
///
/// It never asks the person for permission. Registering with Apple's push service shows nothing
/// to the person; it gives the app the token Pharen sends to. The only prompt is the one your app
/// asks for, and whether a push is shown is the person's answer to it. When to ask is your app's
/// decision — `UNUserNotificationCenter.current().requestAuthorization(options:)`, at the moment
/// the notifications make sense to the person. The SDK reads their answer on its own each time the
/// app becomes active, so nothing here needs to change when they decide.
///
/// Your target needs the Push Notifications capability, and Background Modes with Remote
/// notifications for the silent pushes (`content-available`) that arrive while the app is in
/// the background.
final class PushAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // On every launch: the token can change, and handing over the same one again costs nothing.
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // The token arrives after your `App` has started Pharen. With Pharen off — no ingest
        // key — there is no instance to hand it to, and the next launch brings the token again.
        Pharen.shared?.push.register(token: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Pharen's own pushes are recorded; any other payload is ignored by the SDK and is yours.
        Pharen.shared?.push.handle(payload: userInfo)
        completionHandler(.noData)
    }
}
