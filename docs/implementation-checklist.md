# Implementation checklist

Status: unreleased; implementation in progress.

- [x] Launched offline menu-bar slice: ten bodies, Moon sign, next ingress.
- [ ] Public source audit, repository creation, verified remote.
- [ ] Event engine edge cases and independent reference validation.
- [ ] Progressive cached 90-day forecast and stable identities.
- [ ] Notification planning, reconciliation, persistence and user controls.
- [ ] Dashboard, settings, lifecycle, accessibility and actual screenshots.
- [ ] Shared CLI, JSON schema/export and compiled consumer example.
- [ ] Documentation, CI, package validation and local artifact.
- [ ] Measured launch/forecast/memory/idle behavior.
- [ ] Publisher configuration and trusted release verification (separate gate).

Checks are marked only with observed evidence. Unverified astronomical accuracy
does not become an accuracy claim because the application builds.

## First slice evidence — 2026-09-08

Xcode application built, ad-hoc signed and launched on macOS 27.0 / M3 Max.
The actual Dashboard displayed all ten positions and the next Moon ingress.
Screenshot: screenshots/offline-slice.png. Eleven Swift Testing tests pass,
including synthetic repeated passes and a real Moon ingress sign transition.
This is not independent astronomical accuracy validation or a public binary release.

Build output uses a workspace-specific directory in ~/Library/Caches/HypergateBar.
File-provider metadata added to .app bundles under Documents prevented signing;
building outside the file-provider directory resolved that local issue.
