# Monetization funnel

Part of the [PharenSDK guides](../README.md#guides).

The SDK never touches StoreKit — the app owns purchasing and reports three moments. No price,
currency, revenue, transaction id or receipt rides these events; they count that a moment happened.

```swift
Pharen.shared?.monetization.paywallShown(surface: "journal_window")
Pharen.shared?.monetization.purchaseCompleted(plan: .yearly, trial: true, surface: "journal_window")
Pharen.shared?.monetization.limitResolved(limit: "subjects", outcome: .upgrade)
```

`PharenPurchasePlan` is the plan's shape (`yearly`, `monthly`, `lifetime`, `other`) — never a product
identifier or a price. `PharenUsageLimitOutcome` is the exit taken at a usage limit (`upgrade`, `replace`,
`continueUnsaved`, `cancel`); a limit whose outcomes are all `cancel` is a wall rather than a
choice, which is what the field exists to show.
