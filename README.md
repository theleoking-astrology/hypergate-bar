# HypergateBar

**Hypergate AI Open Source** — a native macOS menu-bar astrology utility.

Unreleased, under active implementation. Calculates the sky offline using the
MIT-licensed C Astronomy Engine. No account, backend, AI model, paid API, telemetry,
birth information, or location permission is required.

## Local development

Requires macOS 14+, Xcode with Swift 6, and Apple's command-line tools. The Xcode
project and shared scheme are committed; project regeneration additionally uses
XcodeGen 2.45.4. Apple Silicon is the initial runtime validation target.

```sh
make test
make run
```

`./script/build_and_run.sh --dashboard` launches the companion window immediately.
Closing Dashboard leaves the menu-bar app running. Use Quit HypergateBar to exit.
Reopen the app from Finder to recover access after removing its menu-bar item.

## Status

The initial offline slice calculates all ten planetary positions and the next
Moon ingress. Full event forecasting, reminders, export and release infrastructure
are being implemented. See docs/implementation-checklist.md for acceptance status.
The calculation window is currently restricted to 2000–2050; independent accuracy
validation is not yet complete. Root precision is not astronomical accuracy.

Local ad-hoc builds are development artifacts, not notarized public releases.
No public binary release exists yet.

## License

Original code: MIT. See LICENSE and THIRD_PARTY_NOTICES.md. HypergateBar is an
independent open-source utility. Forks should use their own identity and must not
imply official endorsement; the MIT software license remains unrestricted.
