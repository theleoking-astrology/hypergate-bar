# Measured accuracy

Measured on 2026-09-08 using the pinned provider and committed independent fixtures. These are sampled results, not an exhaustive accuracy guarantee.

The 1,040 longitude fixtures use Earth-center origin, ICRF vectors, explicit UTC epochs, and LT+S corrections from JPL Horizons. PyERFA 2.0.1.5 independently transforms them to the IAU 2006/2000A true ecliptic/equinox-of-date frame. The reference generator never calls HypergateCore or Astronomy Engine. Raw requests/responses, metadata, and hashes are retained in `reference-data/`.

The 88 independent event fixtures are derived from dense reference sampling and confirmed using fresh local samples. Independent polynomial degree comparisons must converge within one second. Longitude and event-time thresholds were frozen in `accuracy-gates.json` before comparison. See `accuracy-measurements.json` for every residual.

| Measurement | Samples | Maximum residual | Unit | Gate result |
| --- | ---: | ---: | --- | --- |
| Jupiter | 104 | 8.762 | arcseconds | PASS |
| Mars | 104 | 10.227 | arcseconds | PASS |
| Mercury | 104 | 6.800 | arcseconds | PASS |
| Moon | 104 | 12.822 | arcseconds | PASS |
| Neptune | 104 | 18.178 | arcseconds | PASS |
| Pluto | 104 | 4.978 | arcseconds | PASS |
| Saturn | 104 | 12.462 | arcseconds | PASS |
| Sun | 104 | 2.252 | arcseconds | PASS |
| Uranus | 104 | 11.362 | arcseconds | PASS |
| Venus | 104 | 9.163 | arcseconds | PASS |
| Ingress | 8 | 11057.072 | seconds | PASS |
| Moon ingress | 1 | 4.139 | seconds | PASS |
| Opposition | 29 | 365.517 | seconds | PASS |
| Square | 32 | 453.345 | seconds | PASS |
| Station Direct | 9 | 3010.372 | seconds | PASS |
| Station Retrograde | 9 | 4486.327 | seconds | PASS |

Acceptance gates: longitude ≤60 arcseconds per body; numerical root bracket ≤1 second; Moon ingress ≤300 seconds; other ingress/aspect with local rate ≥1 degree/day ≤3,600 seconds; slower crossings ≤21,600 seconds; stations ≤21,600 seconds with matching direction change.

Numerical bisection uses a 0.005-second bracket. Independent reference interpolation convergence, angular residual, and event-time residual are separate measurements. Slow angular motion amplifies small angular error into larger event-time differences; the largest ingress residual must not be interpreted as the Moon timing error.

The measured residuals include differences in ephemeris models, frame approximations, omitted deflection, and UTC/TT modeling. The generator records the Horizons TDB−UT correction and uses ERFA TDB−TT for the reference frame epoch. Isolated delta-T/model contribution measurements and exhaustive event-count/topology validation remain distinct from these matched-fixture results; no unmeasured component is claimed as zero.

Reproduce the comparison offline with `HYPERGATE_ACCURACY_REPORT="$PWD/docs/accuracy-measurements.json" ./script/test.sh --filter independentHorizonsAccuracy`, then `python3 script/accuracy-report.py`. Reference regeneration is a separate network-enabled task: install `script/fixture-requirements.txt` in an isolated environment and run `script/generate-reference-fixtures.py`. Failed gates must remain visible and block related release claims.

## UTC/TT model contribution

At 104 independently referenced epochs, the provider TT−UTC offset differs from the Horizons/ERFA offset by -0.337378 to 25.776595 seconds. Every measurement is in `time-model-measurements.json`.

This isolates the time-conversion component rather than assigning all angular error to the ephemeris. Future UTC leap seconds are not known; the reference and upstream delta-T models make different assumptions. Remaining angular and event-time residuals also include ephemeris and frame-model differences. A time-offset difference cannot simply be subtracted from every event residual to claim corrected accuracy.

Reproduce this diagnostic with `HYPERGATE_TIME_MODEL_REPORT="$PWD/docs/time-model-measurements.json" ./script/test.sh --filter timeModelContributionsAreMeasuredSeparately`. The diagnostics expose the provider’s existing conversion without changing its delta-T function or applying a second correction.
