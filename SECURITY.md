# Security

HypergateBar 0.1.0 is unreleased. There is no supported public binary release yet. The application has no account, remote backend, downloaded executable extension system, or core network dependency. Local notifications and exports are user-controlled.

For a potential vulnerability, use GitHub’s **Report a vulnerability** option on this repository if private vulnerability reporting is enabled. If that option is unavailable, open a minimal issue asking maintainers to establish a private reporting channel; do not include credentials, private data, or exploit-sensitive details in a public issue. This repository does not claim an unconfigured reporting address or guaranteed response time.

Include affected source revision/build, macOS version, reproduction conditions, expected behavior, and a minimal non-sensitive proof when a private channel is available. Dependencies and coordinate conventions are pinned and documented. Changes to signing, update verification, URL handling, ownership boundaries, or notification reconciliation require focused review and tests.

Trusted publisher builds require Developer ID signing, hardened runtime, notarization, stapling, Gatekeeper assessment, and an EdDSA signature on the final archive. Publisher secrets must never enter pull-request jobs or source. Local ad-hoc artifacts are not trusted public releases; do not disable Gatekeeper to disguise that distinction.
