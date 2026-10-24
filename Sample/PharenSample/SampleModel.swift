// Copyright (c) 2026 Pharen
// SPDX-License-Identifier: 0BSD
// See Sample/LICENSE.md for the sample license; the SDK has separate terms.

import Combine
import Foundation
import PharenSDK

/// The calls behind the rows, and what the screen shows about them. Every method is the
/// complete integration for its row; the model only adds the one line of status text.
@MainActor
final class SampleModel: ObservableObject {
    @Published private(set) var lastAction: String?
    @Published private(set) var lastPromptAction: String?
    @Published private(set) var lastLinkHost: String?
    /// What is granted — live from the SDK when it runs; the launch-time grant from
    /// Info.plist when it is off, so the switches show what a key would start with.
    @Published private(set) var granted: Set<PharenConsentPurpose> =
        Pharen.shared?.consent.granted ?? SampleModel.launchGrant()
    private var subscriptions = Set<AnyCancellable>()

    var isRunning: Bool { Pharen.shared != nil }

    // What a report would carry — read from the SDK live, never worked out here.
    var pictures: PharenAttachmentAvailability? { Pharen.shared?.diagnostics.attachmentAvailability }
    var picturesEnabledAtRuntime: Bool { Pharen.shared?.diagnostics.attachmentsEnabled ?? true }

    private static func launchGrant() -> Set<PharenConsentPurpose> {
        let names = Bundle.main.object(forInfoDictionaryKey: "PharenConsentGrantedAtBuild") as? [String] ?? []
        return Set(names.compactMap(PharenConsentPurpose.init(rawValue:)))
    }

    init() {
        // A served config document also changes what a report carries; the readout follows it.
        NotificationCenter.default.publisher(for: Pharen.remoteConfigDidApplyNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subscriptions)
    }

    /// The switch. Persisted, and it only narrows: on hands the answer back to the setting and consent.
    func setPictures(enabled: Bool) {
        guard let diagnostics = Pharen.shared?.diagnostics else {
            return noteOff("diagnostics.setAttachmentsEnabled(\(enabled))")
        }
        diagnostics.setAttachmentsEnabled(enabled)
        note("diagnostics.setAttachmentsEnabled(\(enabled)) — pictures: \(picturesLine)")
    }

    /// Whether a report would carry a part — one answer per part from the SDK, nothing re-derived.
    func carries(_ part: PharenBundlePartKind) -> Bool? {
        Pharen.shared?.diagnostics.carries(part)
    }

    func screenAppeared(_ name: String) {
        Pharen.shared?.screen(name)
    }

    func trackTap() {
        Pharen.shared?.track("sample.run_tapped", properties: ["row": "track"])
        note("track(\"sample.run_tapped\")", needs: .behavioral)
    }

    func recordHandledError() {
        Pharen.shared?.crashReporting.recordError(
            "Sample: a handled error",
            stack: Thread.callStackSymbols,
            severity: .warning,
            breadcrumbs: [PharenBreadcrumb(category: "sample", message: "Run tapped")]
        )
        note("crashReporting.recordError(…)", needs: .telemetry)
    }

    /// The app's own routing, called by the deep-link modifier for every delivered URL —
    /// recognized or not, SDK running or not. The SDK's own handling and counting happen in
    /// the modifier; the sample only shows what arrived.
    func routed(_ url: URL) {
        lastLinkHost = url.host
        note("a link arrived on \(url.host ?? "an unknown host")")
    }

    func presentFeedbackSheet() {
        guard let pharen = Pharen.shared else { return noteOff("presentFeedbackSheet") }
        pharen.presentFeedbackSheet()
    }

    func presentProblemForm() {
        guard let pharen = Pharen.shared else { return noteOff("presentFeedbackSheet(category: .bug)") }
        pharen.presentFeedbackSheet(category: .bug)
    }

    func presentContextualReport() {
        let call = "feedback.presentReport(category:context:)"
        guard let feedback = Pharen.shared?.feedback else { return notePromptOff(call) }
        let result = feedback.presentReport(category: .bug, context: "Sample home screen")
        notePresentation(result, call: call, isReport: true)
    }

    func presentNPS() {
        let call = "feedback.presentNPS()"
        guard let feedback = Pharen.shared?.feedback else { return notePromptOff(call) }
        notePresentation(feedback.presentNPS(), call: call, isReport: false)
    }

    func presentCSAT() {
        let call = "feedback.presentCSAT()"
        guard let feedback = Pharen.shared?.feedback else { return notePromptOff(call) }
        notePresentation(feedback.presentCSAT(), call: call, isReport: false)
    }

    func presentRatingQuestion() {
        let call = "ratings.checkQuestionEligibility()"
        guard let ratings = Pharen.shared?.ratings else { return notePromptOff(call) }
        switch ratings.checkQuestionEligibility() {
        case .eligible(let question):
            notePrompt(question.present()
                ? "\(call) — SDK question opened"
                : "\(call) — eligible, but no question opened")
        case .ineligible(let reason):
            notePrompt("\(call) — ineligible (\(reason.rawValue)); no question opened")
        @unknown default:
            notePrompt("\(call) — SDK returned an unrecognized result")
        }
    }

    private func notePresentation(_ result: PharenFeedbackPresentation, call: String, isReport: Bool) {
        let outcome: String
        switch result {
        case .presented:
            outcome = isReport
                ? "report form opened; submission status is not reported here"
                : "survey form opened; submission status is not reported here"
        case .refused(let reason):
            outcome = isReport
                ? "refusal shown (\(String(describing: reason)))"
                : "refused (\(String(describing: reason))); no form opened"
        case .unavailable:
            outcome = "unavailable; nothing opened"
        case .invalidContext:
            outcome = "invalid context; nothing opened"
        case .ineligible(let reason):
            outcome = "ineligible (\(reason.rawValue)); no form opened"
        @unknown default:
            outcome = "SDK returned an unrecognized result"
        }
        notePrompt("\(call) — \(outcome)")
    }

    private func notePrompt(_ text: String) {
        lastAction = text
        lastPromptAction = text
    }

    private func notePromptOff(_ call: String) {
        noteOff(call)
        lastPromptAction = lastAction
    }

    /// The one line every row shows when the SDK is off: what would have run, and why nothing did.
    func noteOff(_ call: String) {
        lastAction = "\(call) — the SDK is off, so nothing ran; add your ingest key to Info.plist"
    }

    func signIn() {
        // A customer id you already hold, never an email or a name as the id. Traits travel to
        // the identity store, a restricted store separate from the event stream.
        Pharen.shared?.identify("sample-user-1", traits: ["plan": "trial"])
        note("identify(\"sample-user-1\", traits: [plan: trial])", needs: .identity)
    }

    func set(_ purpose: PharenConsentPurpose, granted isGranted: Bool) {
        guard let consent = Pharen.shared?.consent else {
            return noteOff("consent.\(isGranted ? "grant" : "revoke")(.\(purpose.rawValue))")
        }
        if isGranted { consent.grant(purpose) } else { consent.revoke(purpose) }
        granted = consent.granted
        // Health is reserved: the grant is real, nothing is sent under it, and its one effect
        // is the pictures default — so the status line shows that instead of implying a flow.
        let effect = purpose == .health ? "; reserved — pictures: \(picturesLine)" : ""
        note("consent.\(isGranted ? "grant" : "revoke")(.\(purpose.rawValue)) — immediate\(effect)")
    }

    /// The pictures row, in the SDK's own words.
    var picturesLine: String { Self.picturesLine(pictures) }

    /// The line for one reading of the forecast, so a row reads the forecast once and its
    /// switch and its reason cannot disagree.
    static func picturesLine(_ pictures: PharenAttachmentAvailability?) -> String {
        switch pictures {
        case nil: return "SDK off"
        case .available: return "On — the frame at the trigger, plus any the person picks"
        case .offByDefaultForHealth: return "Off by default — health is granted"
        case .offBySetting: return "Off — a setting (compiled, served, count 0, or the kill switch)"
        case .offByRuntimeSetting: return "Off — the switch below"
        case .offByConsent: return "Off — pictures may not leave under the content purpose"
        // A reading a later SDK adds: on or off from the SDK's own answer, so the row's switch
        // and its line still agree.
        @unknown default:
            return pictures?.isAvailable == true ? "On — for a reason this sample does not name" : "Off — for a reason this sample does not name"
        }
    }

    /// The status line: what ran, or why nothing did. A call whose purpose is not granted is
    /// dropped by the SDK at the boundary, and the line says so rather than claiming success.
    private func note(_ text: String, needs purpose: PharenConsentPurpose? = nil) {
        guard isRunning else {
            lastAction = "\(text) — the SDK is off, so nothing was sent"
            return
        }
        if let purpose, !granted.contains(purpose) {
            lastAction = "\(text) — dropped: the \(purpose.rawValue) purpose is not granted"
            return
        }
        lastAction = text
    }
}
