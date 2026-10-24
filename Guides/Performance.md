# Performance

Part of the [PharenSDK guides](../README.md#guides).

```swift
guard let perf = Pharen.shared?.performance else { return }   // nil until start, or with no key
let render = perf.startScreenRender("Feed")
// … when the screen has drawn:
perf.endScreenRender(render)                                             // perf.screen_render
perf.recordAppStart(cold: true, durationMs: 412)                         // perf.app_start
perf.recordNetwork(urlPattern: "/v1/feed", method: "GET", status: 200,
                   durationMs: 180, failed: false)                       // perf.network
var request = URLRequest(url: ordersURL)                                  // the request you are about to send
let trace = PharenTraceContext.make()                                     // or PharenTraceContext(traceparent:) from a header your tracing set
request.setValue(trace.traceparent, forHTTPHeaderField: "traceparent")   // your request, your header — the SDK never adds one
perf.recordNetwork(urlPattern: "/v1/orders/{id}", method: "POST", status: 201,
                   durationMs: 240, failed: false, trace: trace)         // perf.network with trace_id + span_id
perf.recordThermalState(state: .serious, previous: .fair, previousStateSeconds: 95,
                        degraded: true, lowPowerMode: false,
                        workload: ["stage": "export"])                   // perf.thermal_state
perf.recordSessionSummary(PharenPerfSessionSummary(durationMs: 600_000, peakThermal: .serious,
                                             seriousSeconds: 120, memoryWarnings: 1)) // perf.session_summary
```

`PharenPerfThermalState` mirrors `ProcessInfo.thermalState` (`nominal`, `fair`, `serious`,
`critical`). The device model and OS version travel on every event already; `workload` is
your own bounded description of what was running.
