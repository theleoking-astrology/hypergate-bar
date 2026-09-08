# Measured performance

Measured 2026-09-08 on M3 Max, 48 GiB RAM, macOS 27.0 (26A5425a), Xcode 26.6 / Swift 6.3.3, arm64. Individual observations, not percentile or cross-machine guarantees.

| Measurement | Result | Conditions |
|---|---:|---|
| Launch to first real sky | 0.545 s | Fresh Debug process, 10 ms receipt polling; excludes build and pixel-presentation latency |
| Ten positions | 0.00166 s | Release benchmark |
| Today, cold | 0.0369 s | Three events |
| 90 days, cold | 3.756 s | All types, 324 events |
| Same 90 days, warm | 0.474 s | Cached samples |
| Benchmark peak resident memory | 18.64 MiB | CLI process |
| App maximum observed idle resident memory | 99.25 MiB | Periodic sampling, not allocation tracing |
| Five-minute CPU increase | 0.00 s reported | 300.098 s wall time, process CPU sampled every 30 s |

Idle conditions: forecast completed; Dashboard, Settings and popover closed; alerts/updater disabled. Other development activity continued. CPU time uses ps hundredth-second resolution: zero reported increase means below measurement resolution, not literally zero instructions. Visible sky updates are minute bounded; event-boundary work remains scheduled.

Raw evidence: [benchmark](performance-measurements.json), [launch](launch-measurement.json), [idle](idle-measurement.json). Reproduce with `script/benchmark.sh`, `python3 script/measure-launch.py APP_PATH OUTPUT.json`, and `python3 script/measure-idle.py PID OUTPUT.json` using the stated conditions. Native export had 325 events for different local-midnight UTC bounds.
