# API overview

Part of the [PharenSDK guides](../README.md#guides).

## Modules

| Module | API entry point |
|---|---|
| App lifecycle / start | `Pharen.start(granting:)`, `Pharen.start()`, `Pharen.start(bundle:configure:)`, `Pharen.start(config:)`, `Pharen.shared` |
| Identity (user) | `identify(_:traits:)`, `reset(_:)` |
| Identity (device) | `identifyDevice(deviceId:attributes:)` |
| Analytics tracking | `track(_:properties:)` |
| Screen tracking | `screen(_:)` |
| Sessions | automatic (15-minute inactivity timeout, 4-hour lifetime) |
| Consent gating at the boundary | `consent` |
| Crash reporting (fatal + non-fatal) | `crashReporting`, `crashReporting.recordError(...)`, `crashReporting.leaveBreadcrumb(_:)`, `Pharen.crashTest()` |
| Performance (app start, spans, network, thermal) | `performance` |
| Ratings (rule-driven system rating dialog) | `ratings` |
| Feedback (user → system) | `feedback`, `presentFeedbackSheet()`, `presentFeedbackSheet(category:)`, `PharenFeedbackCategory`; in the start block `config.shake.enabled` and `config.feedback.contact.mode` (`PharenFeedbackContactMode`) |
| Deep links (inbound) | `deepLinks`, `.pharenDeepLinks(route:)` |
| Push transport (system → user) | `push` |
| Remote config and flags | `remoteFlag(_:)`, `Pharen.remoteConfigDidApplyNotification` |
| Field diagnostics | `diagnostics` (`.attachmentAvailability`, `.carries(_:)`, `.setAttachmentsEnabled(_:)`, `.isCollecting`, `.settings`), `config.diagnostics` in the start block (`PharenDiagnosticsSettings`), `.pharenPrivacyMask(_:)`, `PharenPrivacyMask` |
| Storage observability + cleanup funnel | `storage` (`recordUsage`, `reclaimed`, `pressure`); `cleanup*(...)` on the facade |
| Monetization funnel (paywalls, purchases, usage limits) | `monetization` |
| Offline queue, retry/backoff, dedupe | automatic; `flush()` asks for a send soon |
| Ingest transport to `/v1/batch` | automatic |

## Public types

The public interface, by module (what Quick Help and the `.swiftinterface` in the archive
show):

| Module | Public types |
|---|---|
| Facade | `Pharen` (`start` forms, `shared`, `identify`, `identifyDevice`, `track`, `screen`, `flush`, `remoteFlag`, the cleanup emitters, `presentFeedbackSheet`, `crashTest`) |
| Configuration | `PharenConfig`; the parts `PharenCrashReportingSettings`, `PharenRatingSettings`, `PharenShakeSettings`, `PharenDiagnosticsSettings` (`PharenNetworkTraceSettings`, `PharenCrashTraceSettings`, `PharenAttachmentSettings` + `PharenAttachmentLimits`, `PharenUploadPolicy`), `PharenFeedbackSettings` + `PharenFeedbackContactSettings` / `PharenFeedbackContactMode`; `PharenStorageDirectory` |
| Contracts | `PharenConsentPurpose`, `PharenConsentContext`, `PharenAnyCodable`, `PharenSDKInfo` |
| Consent | `PharenConsentManaging` (reached as `Pharen.consent`) |
| Capture | `PharenCrashReporting`, `PharenErrorSeverity`, `PharenBreadcrumb`, `PharenBreadcrumbLevel`; `PharenPerformanceMonitoring`, `PharenScreenRenderToken`, `PharenPerfThermalState`, `PharenPerfSessionSummary`; `PharenStorageReporting`, `PharenStorageStore`, `PharenStorageUsage`, `PharenStorageReclaimReason`, `PharenStoragePressureReason` |
| Engagement | `PharenRatingRequesting`, `PharenRatingEligibility`, `PharenRatingIneligibleReason`; `PharenFeedbackCollecting`, `PharenFeedbackCategory`, `PharenFeedbackRefusal`; `PharenDeepLinking`, `PharenParsedLink`, `PharenLinkResolution`, `PharenLinkCampaign`; `PharenPushRegistering`; `PharenMonetizationEvents`, `PharenPurchasePlan`, `PharenUsageLimitOutcome` |
| Remote config | `PharenFlagValue` |
| Diagnostics | `PharenDiagnosticsModule`; `PharenBundlePartKind`, `PharenAttachmentAvailability`; `.pharenPrivacyMask`, `PharenPrivacyMask`; `PharenURLSessionDelegate`, `PharenNetworkFilter`, `PharenNetworkRingLimits` |

Everything else is the SDK's own and is not part of the interface, the served configuration
document included: you read it through the types above — `remoteFlag` returns a
`PharenFlagValue`, and the settings types carry the compiled half of each rule.
