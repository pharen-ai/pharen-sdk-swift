// swift-tools-version:5.10
// Copyright (c) 2026 Pharen. All rights reserved.
// SPDX-License-Identifier: LicenseRef-Pharen-SDK-Binary-License
// Licensed, not sold, under Schedule A (Software License), Part C, of the Pharen Terms of Service:
// https://www.pharen.ai/legal/terms#schedule-a — LICENSE.md identifies the terms, and
// LEGAL-TERMS.txt preserves their release snapshot beside this file and inside the archive.
// Schedule A, A7 permits manifest edits for authorized private build and cache workflows.

// PharenSDK — the iOS SDK for Pharen.ai, distributed as a compiled framework.
//
// One binary target. The archive is an xcframework carrying a dynamic framework for the iOS
// device, the iOS Simulator (arm64 and x86_64) and macOS; each slice ships with its own dSYM,
// its textual module interface, the SDK's privacy manifest and its localizations. The
// checksum is the SHA-256 of the release archive, and Swift Package Manager verifies it
// before anything is linked — an archive whose contents differ from the one published is not
// this release.
//
// No third-party dependencies: the framework links Foundation and the system frameworks only.
import PackageDescription

let version = "2.0.0"
let checksum = "13a3054b8ac84d9334abe50fc03ba02fe13fabe0f38349d58641cd0ce8cb8c2a"

// PHAREN_SDK_LOCAL_XCFRAMEWORK=<absolute path to a PharenSDK.xcframework> points this package at
// a local build instead of the release archive — the way the SDK's own samples and verification
// builds run before a release exists. A shipping app never sets it. A local binary target must
// be named relative to the package directory, so the absolute path is made relative here.
let binary: Target = {
    if let local = Context.environment["PHAREN_SDK_LOCAL_XCFRAMEWORK"], !local.isEmpty {
        precondition(
            local.hasPrefix("/"),
            "PHAREN_SDK_LOCAL_XCFRAMEWORK must be an absolute path (got \(local))"
        )
        return .binaryTarget(name: "PharenSDK", path: relativePath(to: local, from: Context.packageDirectory))
    }
    return .binaryTarget(
        name: "PharenSDK",
        url: "https://github.com/pharen-ai/pharen-sdk-swift/releases/download/v\(version)/PharenSDK.xcframework.zip",
        checksum: checksum
    )
}()

/// `to` and `from` are absolute paths; the result walks up from `from` and down into `to`.
func relativePath(to target: String, from base: String) -> String {
    let t = target.split(separator: "/", omittingEmptySubsequences: true)
    let b = base.split(separator: "/", omittingEmptySubsequences: true)
    var shared = 0
    while shared < t.count, shared < b.count, t[shared] == b[shared] { shared += 1 }
    let up = Array(repeating: "..", count: b.count - shared)
    return (up + t[shared...].map(String.init)).joined(separator: "/")
}

let package = Package(
    name: "PharenSDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(name: "PharenSDK", targets: ["PharenSDK"])
    ],
    targets: [binary]
)
