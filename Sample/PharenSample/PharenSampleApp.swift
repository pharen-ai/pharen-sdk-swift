// Copyright (c) 2026 Pharen
// SPDX-License-Identifier: 0BSD
// See Sample/LICENSE.md for the sample license; the SDK has separate terms.

import PharenSDK
import SwiftUI

@main
struct PharenSampleApp: App {
    init() {
        // One line, as early as possible. The key and the launch-time consent come from
        // Info.plist (`PharenIngestKey`, `PharenConsentGrantedAtBuild`) — the plist form, so the
        // settings screen can show the launch grant even with no key; in your app,
        // `Pharen.start(granting:)` is the line to prefer, where a reviewer sees it. With no
        // key the SDK stays off and `start` returns nil — the recommended way to keep a
        // local build silent. No configure block here, so the settings screen shows consent
        // deciding the pictures default.
        Pharen.start()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
