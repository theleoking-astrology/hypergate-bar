# Validation record — 2026-09-08

Unreleased development software. Host: Apple Silicon M3 Max, macOS 27.0, Xcode 26.6 / Swift 6.3.3. macOS 14 deployment target; physical macOS 14 and Intel execution are unverified.

## Automated checks

- Package: 25 Swift Testing tests passed, including wrapping, re-entry, repeated aspects, two interior roots, tangency, provider errors, cancellation, concurrent provider instances, persistence recovery, reminder races/quiet hours/DST, CLI, independent references and time-model contributions.
- Application-service XCTest: two passed (display zone preserves UTC events; unconfigured updater disabled).
- make check passed provenance/hash, public-content audit, schema/CLI errors, formatting, package/project and compiled consumer checks. Twelve synthetic publisher cases test configuration failure without credentials.
- Full app/UI test command failed before UI execution: “Timed out while enabling automation mode.” DevToolsSecurity reported developer mode disabled. No host security setting changed. Target compilation is not a passed UI suite.
- make package-local built an ad-hoc signed arm64 Debug ZIP, checksums and source manifest.
- make release rejected missing publisher configuration; no distribution operation followed.

The committed CI matrix requests macOS 14/Xcode 16.2 and macOS 26/Xcode 26.6. A definition is not a passed hosted run: consult actual Actions results. Retain a physical macOS 14 environment after announced runner retirement (release runbook).

## Actual app inspection

Real Today, Upcoming, Planets, UTC details, Settings and introduction were inspected. App-only light/dark screenshots were captured. Command-comma opens Settings. Closing Dashboard left the process running during five-minute idle measurement; Quit terminated it. Export cancellation returned to Dashboard. A native save-dialog export and CLI agreed on provider, query, all 325 identities and UTC instants; schema validation passed.

Remaining: actual MenuBarExtra popover capture, menu-item removal/recovery, full VoiceOver navigation, changed reduced-motion/transparency preferences and notification-click navigation. Native accessibility labels were inspected; this is not a full assistive-technology test.

## Real reminders

Explicit Enable Alerts and macOS permission controls were exercised. Temporarily enabling HypergateBar permission produced actual readback of 44 ordinary pending requests; last covered event: 2026-10-03 00:10:06 America/Los_Angeles. Forecast extended later. A labeled test was submitted; visible banner/delivered history was not verified. Global display-sharing notification suppression remained unchanged.

Afterward alerts were disabled, ordinary pending requests reached zero, and HypergateBar OS permission was restored off. Scheduling is verified; visible delivery and clicks remain manual acceptance rows. Focus, sleep/off, permission and OS policy can suppress delivery. Replenishment needs another app run; missed events appear in-app without stale catch-up banners.

## Accuracy and distribution

All frozen gates passed for 1,040 independent position samples and 88 representative events. See [accuracy](accuracy.md), including numerical precision versus measured event errors and time-model differences. Exhaustive 51-year event topology is not proved.

The protected publisher environment was absent and all five publisher settings missing. Local ZIPs are development artifacts. Publisher scripts/Sparkle are implemented/configured-only; certificate import, notarization, stapling, Gatekeeper, signed archive publication and actual updater delivery were not attempted. An empty appcast is not an update release.
