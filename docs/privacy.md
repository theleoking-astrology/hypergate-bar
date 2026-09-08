# Privacy and network behavior

Core planetary calculations, forecasts, saved preferences, and local reminders operate offline. HypergateBar has no account, backend, telemetry, analytics, paid API, AI generation, birth-information collection, or location-permission request.

Local files live in `~/Library/Application Support/HypergateBar/`: `preferences-v1.json`, `events-v1.json`, and `requests-v1.json`. They contain display/reminder preferences and public astronomical events. Diagnostic messages use local OSLog. JSON export occurs only through a user-invoked native save dialog.

Notifications use macOS UserNotifications. Permission is requested from Enable Alerts. macOS controls banners, Focus behavior, sleep/shutdown delivery, and notification history. The app reconciles its own pending requests when running; it cannot promise indefinite replenishment after quitting. Quiet hours use the current device time zone, even if a different display zone is selected.

Development and fork builds without verified publisher settings do not instantiate Sparkle or contact an update feed. A configured publisher build checks its explicitly configured HTTPS feed daily by default; users can disable automatic checks in Settings. A valid newer release adds an update indicator to the menu-bar label and an Update action in the popover. Installation requires the user's choice through Sparkle; automatic installation and system profiling are disabled. Manual Check for Updates remains available. Source/documentation links open only when clicked.

The separate product website is a static Vercel site with no analytics, cookies, account system, embedded third-party scripts, or runtime API calls. Vercel may process ordinary hosting request metadata under its own privacy policy. The changelog is generated from the public repository at build time. Visiting the website is not required to run the native app.

Developer setup may download the pinned Sparkle dependency from GitHub. Regenerating reference fixtures explicitly contacts NASA/JPL Horizons and requires the pinned reference-tool dependencies; ordinary calculation and fixture tests use committed offline data. CI and publisher workflows contact their documented source, artifact, signing, and notarization services.

HypergateBar is independent of commercial Hypergate products. The shared umbrella name does not connect this app to their accounts or services.
