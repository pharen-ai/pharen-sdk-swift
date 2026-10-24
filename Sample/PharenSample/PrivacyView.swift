// Copyright (c) 2026 Pharen
// SPDX-License-Identifier: 0BSD
// See Sample/LICENSE.md for the sample license; the SDK has separate terms.

import SwiftUI

/// The privacy posture, in the words the SDK is built to keep — each one a property of the
/// boundary, not of a version.
struct PrivacyView: View {
    private let statements: [(String, String)] = [
        ("Consent is stamped on every event.",
         "Each event carries the purposes granted at the moment it was made — present even when empty — so what was allowed is on the record beside what was sent."),
        ("No event leaves the device without a purpose you granted.",
         "An event whose purpose is not granted is dropped at the boundary, before it is stored or sent. Consent is opt-in, and a change takes effect immediately."),
        ("No personal data rides the event stream.",
         "Identity traits travel by their own call to the identity store, a restricted store the stream cannot reach. Free text a person submits is content they chose to send, handled as content."),
        ("The ingest key is public by design.",
         "It ships in the app and scopes writes to one app: a live key to your live environment, a test key to its own test environment or another registered test environment the build declares. It reads nothing, and the platform derives the organization and stamps the environment from it — the app never does."),
        ("Your agent reads your app — nothing about a person without a grant you chose.",
         "The connection an agent uses is a separate, read-only credential scoped to the apps and the one environment it names. It returns counts and groups, crashes grouped by cause, and the reports people filed — their words only on a key minted with a grant you chose by name, with addresses and phone numbers replaced."),
        ("A link's path and query stay on the device.",
         "Routing fires regardless of consent; the open event reports only the domain the link arrived on."),
    ]

    /// The line under the statements: this screen summarizes; the Terms and the Privacy Notice
    /// are what apply.
    private let termsNote = "This screen is a plain-language summary, not the terms. The Pharen Terms of Service and Privacy Notice at pharen.ai/legal are what apply; if anything here differs from them, they take precedence."

    var body: some View {
        List {
            Section {
                ForEach(statements, id: \.0) { statement in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statement.0).font(.body.weight(.semibold))
                        Text(statement.1)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text("Consent as architecture, not paperwork. The full statement, and what it means under GDPR and CCPA, is at pharen.ai/privacy.\n\n\(termsNote)")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Privacy")
    }
}
