# Contributing

HypergateBar is a standalone native macOS utility under Hypergate AI Open Source. Original code is MIT licensed. Contributions must not include commercial Hypergate code, accounts, prompts, assets, customer data, credentials, or private operational records.

Use macOS 14 or newer, a Swift 6 compatible Xcode, Python 3, Git, and the committed shared Xcode scheme. No Apple Developer account is needed for local builds. Run `make run`, `make test`, and `make check`. `make package-local` produces a clearly labeled ad-hoc development archive. XcodeGen 2.45.4 is needed only when changing `project.yml`; regenerate and commit the project and shared scheme together.

Keep calculation models immutable and Sendable, platform services outside the calculation package, and UI state on MainActor. Add a failing behavioral test for new logic. Preserve explicit failure/coverage states, canonical UTC instants, provider provenance, deterministic event identities, and notification ownership boundaries.

Ordinary tests must not fetch live ephemerides or manufacture reference answers using our engine. Changing the provider, time conventions, search algorithm, or accuracy criteria requires a documented comparison against independent fixtures. Never relax an accuracy threshold solely to make a test pass. Reference regeneration is an explicit maintainer task using the pinned tool requirements.

Submit a focused pull request explaining the user-visible behavior and actual verification. Distinguish a build from a launched app, a queued notification from delivered UI, and an ad-hoc artifact from notarized distribution. Include real app screenshots for visual changes, with private desktop content excluded. Respect keyboard access, VoiceOver labels, native light/dark appearances, reduced motion, and reduced transparency.

Report bugs using the repository issue templates. Security reports follow [SECURITY.md](SECURITY.md). Do not attach credentials or personal information. Forks may reuse MIT code but must use their own branding, bundle identifier, publisher identity, and update feed and must not imply official endorsement.
