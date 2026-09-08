# Architecture

HypergateBar is a native macOS menu-bar application with an on-demand singleton Dashboard. SwiftUI owns the views; a small AppKit delegate owns the Dashboard window, reopen behavior, wake/clock observers, and explicit Quit lifecycle. All UI state is MainActor isolated. Closing Dashboard cancels its visible-data task; the menu popover has a separate visibility-scoped task. The next Moon ingress schedules a boundary refresh without a permanent one-second timer.

`HypergateCore` uses Foundation and contains immutable Sendable/Codable domain values, strict UTC parsing, event searches, aspect status, notification planning, reconciliation, and atomic JSON storage. It does not import SwiftUI, AppKit, UserNotifications, ServiceManagement, or Sparkle. `EphemerisProvider` is an asynchronous throwing Sendable interface. Callers can replace the provider and inject a clock, storage, and notification client.

`HypergateAstronomyEngine` wraps the pinned C source through one process-wide actor. All instances share that executor because upstream has mutable Pluto cache state, a delta-T function pointer, and a Moon calculation counter. The CLI and app use the same package engine and JSON encoder.

Searches use canonical UTC day intervals, interior samples and relative-velocity turning points, angle unwrapping, deterministic bisection, and half-open subinterval ownership. Event IDs combine semantic bodies/type/directed branch, UTC day, and pass ordinal. Persisted candidates are matched one-to-one within two seconds; distinct candidates are never collapsed merely because their instants are close. The stationary display threshold is separate from station root detection.

Each query is limited to 90 elapsed days and 500,000 distinct requested sky-sample epochs. Cached accesses at the same epoch do not repeatedly consume this budget. Budget exhaustion and unresolved intervals throw explicit errors; the app retains earlier completed coverage and labels extension failure as incomplete. Provider revisions and coordinate conventions determine cache compatibility. Optional aspect types are calculated with the forecast so display filters can reuse results.

The app loads a saved forecast, calculates current positions and the next Moon ingress, then extends Today, seven days, 30 days, and 90 days. Superseded visible refreshes reject stale generations. Search cancellation checks run during sampling and refinement. Calculations run through actors rather than on the UI actor.

The pure reminder planner selects absolute UTC delivery instants. A single draining reconciliation worker serializes ordinary queue changes across awaits; newer preferences supersede old plans. The macOS adapter reads actual pending requests back. Only requests with HypergateBar-owned prefixes are removed or replaced. Versioned preferences, events, and request identities use atomic local writes. A malformed cache is reported and recalculated rather than silently treated as valid.

Sparkle is an application-only dependency. An updater is instantiated only for structurally valid publisher configuration explicitly marked verified by the distribution pipeline. Development builds have updates disabled.

The build scripts stage exact source bytes into uniquely named local cache snapshots and record SHA-256 manifests. This avoids cloud-file coordination and extended-attribute signing problems in synchronized checkouts. The selected checkout remains authoritative, and the committed Xcode project builds without XcodeGen. XcodeGen is required only when regenerating the project after changing its structure.
