// Copyright (c) 2026 Pharen
// SPDX-License-Identifier: 0BSD
// See Sample/LICENSE.md for the sample license; the SDK has separate terms.

import PharenSDK
import SwiftUI

/// A settings screen the way an app would build one — with the report flow as two rows in
/// it, and consent as switches. Nothing here is special to the sample: a settings menu is
/// where a customer's app embeds the same calls.
struct SettingsView: View {
    @ObservedObject var model: SampleModel

    var body: some View {
        Form {
            Section {
                Button {
                    // The picker: what kind of report is this? The person chooses, then the form.
                    model.presentFeedbackSheet()
                } label: {
                    Label("Send feedback", systemImage: "bubble.left")
                }
                Button {
                    // One kind, directly: a "Report a problem" row already answered the question,
                    // so the picker is skipped and the problem form opens.
                    model.presentProblemForm()
                } label: {
                    Label("Report a problem", systemImage: "exclamationmark.bubble")
                }
            } header: {
                Text("Help")
            } footer: {
                Text("Both rows open the flow a device shake opens, and work whether or not shake is on. A report carries the message, the kind, the pictures the person chose to attach, and an email address if they gave one. Diagnostics ride with it under the telemetry purpose — recent network timings and the breadcrumb trail, never screen or user content. The message, the pictures and the address are the only content collected.")
            }

            Section {
                consentToggle(.telemetry, "Telemetry", "Crashes, handled errors, performance.")
                consentToggle(.behavioral, "Behavioral", "Sessions, screen views, tracked events.")
                consentToggle(.content, "Content", "What a person submits: feedback and its pictures.")
                consentToggle(.identity, "Identity", "Connecting activity to a customer id.")
                // The one purpose an app cannot grant at launch — only a switch like this one, the
                // person's own act. Reserved in this version: nothing is sent under it.
                consentToggle(.health, "Health", "Special-category. Reserved in this version — nothing is sent under it. Runtime-only. Granting it turns report pictures off by default (below).")
            } header: {
                Text("Consent")
            } footer: {
                Text("Every event carries the purposes granted when it was made. An event whose purpose is not granted is dropped on the device — never stored, never sent. A change here takes effect immediately. Health is the one purpose that cannot be granted at launch: it is left out of Info.plist on purpose and granted here, explicitly, on its own.")
            }

            // What a report would carry, live — the pictures default is the one thing consent
            // derives, so it is seen changing here rather than read about.
            Section {
                // One reading of the forecast for the row: its switch and its reason agree.
                let pictures = model.pictures
                ReportPartRow(title: "Pictures", purpose: PharenBundlePartKind.attachment.consentPurpose, isOn: pictures?.isAvailable, detail: SampleModel.picturesLine(pictures))
                ReportPartRow(title: "Network trace", purpose: PharenBundlePartKind.networkTrace.consentPurpose, isOn: model.carries(.networkTrace), detail: "Recent request timings, never bodies")
                ReportPartRow(title: "Breadcrumbs", purpose: PharenBundlePartKind.breadcrumbs.consentPurpose, isOn: model.carries(.breadcrumbs), detail: "Your app's trail before the report")
                // A switch a person can flip. It only narrows, so nothing here can widen collection.
                Toggle(isOn: Binding(
                    get: { model.picturesEnabledAtRuntime },
                    set: { model.setPictures(enabled: $0) }
                )) {
                    RowText(title: "Include pictures", detail: "setAttachmentsEnabled(_:) — persisted; only ever narrows.")
                }
            } header: {
                Text("What a report carries")
            } footer: {
                Text("Live from diagnostics.carries(_:) and attachmentAvailability. Health granted ⇒ pictures start off; mask, then turn them on (start block or remote config). See Guides/Field-Diagnostics.md.")
            }

            Section {
                Button("Sign in as a sample user") { model.signIn() }
            } header: {
                Text("Identity")
            } footer: {
                Text("identify(_:traits:) connects activity to an id you already hold. Traits go to the identity store — a restricted store separate from the event stream — and need the identity purpose.")
            }

            Section {
                LabeledText("PharenSDK", value: PharenSDKInfo.version)
                LabeledText("Event contract", value: PharenSDKInfo.envelopeSchemaVersion)
            } header: {
                Text("About")
            } footer: {
                if let last = model.lastAction {
                    Text(last)
                }
            }
        }
        .tint(Brand.accent)
        .navigationTitle("Settings")
        .onAppear { model.screenAppeared("Settings") }
    }

    private func consentToggle(_ purpose: PharenConsentPurpose, _ title: String, _ detail: String) -> some View {
        Toggle(isOn: Binding(
            get: { model.granted.contains(purpose) },
            set: { model.set(purpose, granted: $0) }
        )) {
            RowText(title: title, detail: detail)
        }
    }
}

/// One part of a bundle: on or off, the purpose it rides, one line on it.
struct ReportPartRow: View {
    let title: String
    let purpose: PharenConsentPurpose
    let isOn: Bool?   // nil: the SDK is off
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RowText(title: title, detail: "\(detail). Rides \(purpose.rawValue).")
            Spacer(minLength: 0)
            Text(isOn.map { $0 ? "On" : "Off" } ?? "SDK off")
                .font(.subheadline)
                .foregroundColor(isOn == true ? .green : .secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct LabeledText: View {
    let label: String
    let value: String

    init(_ label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }
}
