// Copyright (c) 2026 Pharen
// SPDX-License-Identifier: 0BSD
// See Sample/LICENSE.md for the sample license; the SDK has separate terms.

import SwiftUI
import UIKit

/// The sample's look: one accent, system type, and the wordmark as text.
enum Brand {
    /// Pharen's accent color.
    static let accent = Color(red: 0x36 / 255, green: 0x51 / 255, blue: 0xd4 / 255)
    /// The accent as TEXT: the fill reads at 6.4:1 on a light ground and 2.7:1 on a dark one,
    /// under the 3:1 floor for large text, so the wordmark lightens in dark mode.
    static let accentText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x7b / 255, green: 0x8c / 255, blue: 0xff / 255, alpha: 1)
            : UIColor(red: 0x36 / 255, green: 0x51 / 255, blue: 0xd4 / 255, alpha: 1)
    })

    static let name = "Pharen"
    static let tagline = "iOS app infrastructure — crash reporting, test-build distribution, analytics, deep links and in-app feedback behind one small SDK."
}

/// The wordmark and the tagline, as the top of every screen shows them.
struct BrandHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Brand.name)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(Brand.accentText)
            Text(Brand.tagline)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
