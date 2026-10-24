// Copyright (c) 2026 Pharen
// SPDX-License-Identifier: 0BSD
// See Sample/LICENSE.md for the sample license; the SDK has separate terms.

import PharenSDK
import SwiftUI

/// One screen, one row per capability, one action each. What each row does is the whole
/// integration for that capability — there is nothing behind the button the row does not show.
struct HomeView: View {
    @StateObject private var model = SampleModel()
    @State private var confirmCrash = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    BrandHeader()
                        .padding(.vertical, 6)
                    StatusRow(model: model)
                }

                Section("Crash reporting") {
                    ActionRow(
                        title: "Record a handled error",
                        detail: "A non-fatal error with the current stack, a breadcrumb and a severity. Telemetry-class.",
                        accessibilityIdentifier: "sample.crash.handled-error"
                    ) {
                        model.recordHandledError()
                    }
                    ActionRow(
                        title: "Crash on purpose",
                        detail: "A deliberate crash inside the SDK. The report is written at crash time and delivered on the next launch.",
                        accessibilityIdentifier: "sample.crash.deliberate"
                    ) {
                        if model.isRunning { confirmCrash = true } else { model.noteOff("crashTest") }
                    }
                }

                Section("Sessions & analytics") {
                    ActionRow(
                        title: "Track an event",
                        detail: "A named event with properties. Sessions start on their own; this screen view was recorded when the screen appeared. Behavioral-class.",
                        accessibilityIdentifier: "sample.analytics.track"
                    ) {
                        model.trackTap()
                    }
                }

                Section("Feedback") {
                    ActionRow(
                        title: "Send feedback",
                        detail: "The report flow a device shake opens — a problem, an improvement, a question, and in a development build the developer panel — from a button instead. Content-class.",
                        accessibilityIdentifier: "sample.feedback.picker"
                    ) {
                        model.presentFeedbackSheet()
                    }
                    NavigationLink(destination: SettingsView(model: model)) {
                        RowText(
                            title: "Settings",
                            detail: "The same flow embedded in a settings menu, and consent switched at runtime."
                        )
                    }
                }

                Section("SDK forms and rating") {
                    ActionRow(
                        title: "feedback.presentReport(category:context:)",
                        detail: "Opens the report form with a fixed sample context.",
                        accessibilityIdentifier: "sample.feedback.contextual-report"
                    ) {
                        model.presentContextualReport()
                    }
                    ActionRow(
                        title: "feedback.presentNPS()",
                        detail: "Asks the served NPS policy whether to show its form.",
                        accessibilityIdentifier: "sample.feedback.nps"
                    ) {
                        model.presentNPS()
                    }
                    ActionRow(
                        title: "feedback.presentCSAT()",
                        detail: "Asks the served CSAT policy whether to show its form.",
                        accessibilityIdentifier: "sample.feedback.csat"
                    ) {
                        model.presentCSAT()
                    }
                    ActionRow(
                        title: "ratings.checkQuestionEligibility()",
                        detail: "Checks the served rating-question policy once, then presents only an eligible question.",
                        accessibilityIdentifier: "sample.ratings.question"
                    ) {
                        model.presentRatingQuestion()
                    }
                    if let lastPromptAction = model.lastPromptAction {
                        Text(lastPromptAction)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("sample.prompt-status")
                    }
                }

                Section("Deep links") {
                    RowText(
                        title: model.lastLinkHost.map { "Last link arrived on \($0)" } ?? "No link yet",
                        detail: "Add your associated domain to the target's entitlements and to PharenLinkDomains in Info.plist, then open a universal link to this app: one modifier on the root view routes every link to the app and, for a domain you listed, reports only the domain it arrived on — never the path or the query."
                    )
                }

                Section {
                    NavigationLink(destination: PrivacyView()) {
                        RowText(title: "Privacy, plainly", detail: "What the SDK sends, and what it never does.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Sample")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Crash the app?", isPresented: $confirmCrash) {
                Button("Crash", role: .destructive) { Pharen.crashTest() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The app exits now. Relaunch it: the crash report is delivered on the next start.")
            }
            .onAppear { model.screenAppeared("Home") }
        }
        .navigationViewStyle(.stack)
        // Universal links reach a SwiftUI scene by two different paths depending on the iOS
        // version, sometimes both for one open; this modifier wires both, routes each open once
        // to the app, and lets the SDK count it.
        .pharenDeepLinks { url in model.routed(url) }
    }
}

/// Whether the SDK is running, which version, and what the last action did.
struct StatusRow: View {
    @ObservedObject var model: SampleModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if model.isRunning {
                Label("PharenSDK \(PharenSDKInfo.version) is running", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Label("PharenSDK is off — add your ingest key to Info.plist", systemImage: "pause.circle")
                    .foregroundColor(.orange)
            }
            if let last = model.lastAction {
                Text(last)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .font(.subheadline)
        .padding(.vertical, 2)
    }
}

/// A row that explains itself and offers one action.
struct ActionRow: View {
    let title: String
    let detail: String
    let accessibilityIdentifier: String
    let action: () -> Void

    // The whole row is the button, the way a list row is tapped — and the way a hardware
    // keyboard reaches it: the list moves focus from row to row and draws it, and Space runs it.
    // The capsule is drawn only; the row is the control.
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                RowText(title: title, detail: detail)
                Spacer(minLength: 0)
                Text("Run")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Brand.accent)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .fixedSize()
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .foregroundColor(.primary)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct RowText: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.body.weight(.medium))
            Text(detail)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
