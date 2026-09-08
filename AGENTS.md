# HypergateBar

Standalone MIT-licensed native macOS utility. Do not introduce private product code,
cloud dependencies, accounts, telemetry, or generated astronomical values.

Use Swift 6 with a macOS 14 deployment target. Keep platform services in App and
Foundation-only models/algorithms in HypergateCore. All C provider calls share the
adapter's process-wide executor. Never use heliocentric longitude for zodiac data.

Read docs/product-specification.md and docs/implementation-checklist.md before
changing scope. Write regression tests before fixes. Use make test, make check,
and make package-local; launch with make run. Preserve dependency notices and
verify vendor hashes. Do not edit generated project files without project.yml.

Keep public source free of credentials and operational/private tracker material.
Signing/notarization and runtime acceptance are separate from compilation.
Release automation must fail closed. Never publish an unverified binary.
