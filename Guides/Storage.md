# Storage observability and cleanup

Part of the [PharenSDK guides](../README.md#guides).

The SDK measures the app's own footprint — documents, application support, caches, the
temporary directory, plus any app-group container or directory you name in `PharenConfig` —
off the main thread under a time budget, and reports a `storage.snapshot` when the picture has
changed. Stores only the app can total, and the moments storage bites, are yours to report:

```swift
Pharen.shared?.storage.recordUsage(stores: [PharenStorageUsage(store: .userLibrary, bytes: 2_400_000_000, items: 1_812)])
Pharen.shared?.storage.reclaimed(store: .appCache, bytes: 48_000_000, reason: .sizeCap)
Pharen.shared?.storage.pressure(reason: .insufficientSpace, store: .appDownloads, neededBytes: 120_000_000)
```

For an app with a cleanup feature, the funnel has three typed calls:
`cleanupScanCompleted(itemsTotal:durationMs:…)`, `cleanupMarked(items:bytes:…)` and
`cleanupFreed(items:bytes:…)`. `bytes`/`items` on the last two are incremental — this action
only — because the platform sums them. A `store:` on any of them names which body of
storage the funnel ran over. `storage.*` and the scan ride `telemetry`; marked and freed ride
`behavioral`.
