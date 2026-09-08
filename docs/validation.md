# Validation record — 2026-09-08

Unreleased development software. Host: Apple Silicon M3 Max, macOS 27.0, Xcode 26.6 / Swift 6.3.3. macOS 14 deployment target; physical macOS 14 and Intel execution are unverified.

## Automated checks

- Package: 25 Swift Testing tests passed, including wrapping, re-entry, repeated aspects, two interior roots, tangency, provider errors, cancellation, concurrent provider instances, persistence recovery, reminder races/quiet hours/DST, CLI, independent references and time-model contributions.
- Application-service XCTest: two initially passed locally. All three, including rejection of an incomplete provider snapshot, passed on both hosted macOS versions after the regression fix.
- make check passed provenance/hash, public-content audit, schema/CLI errors, formatting, package/project and compiled consumer checks. Twelve synthetic publisher cases test configuration failure without credentials.
- Full app/UI test command failed before UI execution: “Timed out while enabling automation mode.” DevToolsSecurity reported developer mode disabled. No host security setting changed. Target compilation is not a passed UI suite.
- make package-local built an ad-hoc signed arm64 Debug ZIP, checksums and source manifest.
- make release rejected missing publisher configuration; no distribution operation followed.

Hosted CI passed on macOS 14/Xcode 16.2 and macOS 26/Xcode 26.6 at source commit `9f1146d9f3c039a076096adea0ea47033a8ec065`: [run 34283168283](https://github.com/theleoking-astrology/hypergate-bar/actions/runs/34283168283). Each job passed source/provenance checks, 25 package tests, three app-service tests, one actual UI flow and development packaging. The earlier run exposed ambiguous role/Cancel selectors; stable accessibility identifiers and a save-dialog-scoped selector fixed them without weakening the behavior assertions. Retain an actual macOS 14 environment after announced runner retirement (release runbook).

## Actual app inspection

Real Today, Upcoming, Planets, UTC details, Settings and introduction were inspected. App-only light/dark screenshots were captured. Command-comma opens Settings. Closing Dashboard left the process running during five-minute idle measurement; Quit terminated it. Export cancellation returned to Dashboard. A native save-dialog export and CLI agreed on provider, query, all 325 identities and UTC instants; schema validation passed.

Hosted UI automation additionally opened the actual MenuBarExtra, checked its next Moon ingress and Dashboard control, captured the popover, reopened exactly one Dashboard, then clicked Quit HypergateBar and observed process termination. [Original hosted screenshot](screenshots/menu-popover-hosted-macos26.png) was exported from the successful xcresult attachment and visually inspected; it uses the runner's UTC display zone. [Final local screenshot](screenshots/dashboard-final.png) uses America/Los_Angeles.

Remaining: menu-item removal/recovery, full VoiceOver navigation, changed reduced-motion/transparency preferences and notification-click navigation. Native accessibility labels were inspected; this is not a full assistive-technology test.

## Real reminders

Explicit Enable Alerts and macOS permission controls were exercised. Temporarily enabling HypergateBar permission produced actual readback of 44 ordinary pending requests; last covered event: 2026-10-03 00:10:06 America/Los_Angeles. Forecast extended later. A labeled test was submitted; visible banner/delivered history was not verified. Global display-sharing notification suppression remained unchanged.

Afterward alerts were disabled, ordinary pending requests reached zero, and HypergateBar OS permission was restored off. Scheduling is verified; visible delivery and clicks remain manual acceptance rows. Focus, sleep/off, permission and OS policy can suppress delivery. Replenishment needs another app run; missed events appear in-app without stale catch-up banners.

## Accuracy and distribution

All frozen gates passed for 1,040 independent position samples and 88 representative events. See [accuracy](accuracy.md), including numerical precision versus measured event errors and time-model differences. Exhaustive 51-year event topology is not proved.

The protected publisher environment was absent and all five publisher settings missing. Local ZIPs are development artifacts. Publisher scripts/Sparkle are implemented/configured-only; certificate import, notarization, stapling, Gatekeeper, signed archive publication and actual updater delivery were not attempted. The empty HTTPS appcast was fetched successfully after source publication; it is not an update release.

Final local artifact: `dist/HypergateBar-development-arm64-20260908T215538Z/HypergateBar-development.zip`, SHA-256 `16020e124a122ce2e767d32e1e002c4962edc0a2bdabc0d530838fe7af55d855`. All 53 app/package/project/test source files match its SHA-256 source manifest. Bundle identity `ai.hypergate.HypergateBar`, arm64, ad-hoc signing, deep/strict signature verification passed. Later documentation-only commits do not change those application source bytes.
