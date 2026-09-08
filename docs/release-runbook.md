# Build and release runbook

## Local development

Use an installed Xcode supporting Swift 6, macOS 14+, Python 3, and Git. Apple Silicon is the validated architecture. XcodeGen 2.45.4 regenerates project structure but is not required for ordinary checkout builds. SwiftPM resolves pinned Sparkle 2.9.6 on first build; keep the committed dependency lock.

```
make run
make test
make check
make package-local
```

Build scripts explicitly resolve Xcode’s macOS SDK. They copy exact source bytes into a fresh local cache snapshot with a SHA-256 manifest, then build outside synchronized Documents folders. Build/test outputs are under `~/Library/Caches/HypergateBar/<workspace-key>/`. `HYPERGATE_BUILD_PATH` can select another local cache directory. Development archives are placed under `dist/` and include checksums, source manifests, and notices. They are ad-hoc signed, not notarized, and must not be advertised as Gatekeeper-approved releases.

`make test` runs offline Swift package tests, application-service XCTest, and the macOS UI smoke target. macOS must permit developer UI automation. A test-runner initialization failure is a host prerequisite failure, not a passing UI test. The source checkout does not change system security settings. A `.xcresult` bundle records the actual outcome.

## Publisher prerequisites

The protected `publisher` GitHub environment must already exist, have required reviewers, and prevent self-review. The workflow checks that protection before its publisher job can access secrets. Repository membership or a certificate on a developer machine does not imply those settings are configured.

Five required publisher settings:

| Setting | Meaning |
| --- | --- |
| `DEVELOPER_ID_APPLICATION` | Full Developer ID Application identity, including matching team suffix |
| `APPLE_TEAM_ID` | Publisher’s ten-character Apple team identifier |
| `NOTARY_KEYCHAIN_PROFILE` | Validated notarytool profile; the workflow creates `HypergateBarPublisher` in its temporary keychain |
| `SPARKLE_PUBLIC_ED_KEY` | Base64 Ed25519 public key, exactly 32 decoded bytes |
| `SPARKLE_FEED_URL` | Verified HTTPS RSS feed belonging to this publisher |

Set the identity, team, public key, and feed as environment variables in the publisher environment. Protected secrets are `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `NOTARY_API_KEY_BASE64`, `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID`, and `SPARKLE_PRIVATE_ED_KEY`. Use a dedicated authorized notarization API key; never copy a credential from an unrelated app or organization. No private key enters the repository, command output, or PR job. The Sparkle secret goes to the signing tool through stdin, and the resulting signature is independently verified with CryptoKit and the configured public key.

The publisher requires `/usr/bin/trash` before creating temporary material. Its `finally` cleanup restores the keychain search list, locks the temporary keychain, and moves each verified temporary file to Trash with no permanent-deletion fallback. SIGINT/SIGTERM enter cleanup; a forcibly destroyed hosted runner relies on the runner’s ephemeral lifetime. A cleanup failure prevents publication.

## Trusted distribution sequence

1. Complete accuracy, service, UI, compatibility, and installed-app acceptance. Review the source diff and dependency changes. Update app version/build, changelog, and validation evidence.
2. Create and push the exact reviewed source tag. Tags use `vMAJOR.MINOR.PATCH`; `CFBundleShortVersionString` must match, and `CFBundleVersion` must increase for updates.
3. Verify the actual empty or existing repository feed at `https://raw.githubusercontent.com/<owner>/<repo>/main/docs/appcast.xml`. An empty feed establishes a URL but does not prove an update or a signed release exists.
4. Dispatch **Protected publisher** with the exact tag and 40-character commit. An independent environment reviewer approves that concrete transition. The workflow runs `make check` and `make test` before importing publisher material.
5. The pipeline validates all five settings, actual identity, notarization access, and feed XML. It archives with hardened runtime, signs nested Sparkle code from the inside out, signs the outer app, and verifies signatures and team identity.
6. Submit a ZIP to notarytool and require Accepted. Staple and validate the app, recheck signatures, assess it with Gatekeeper, then create a new final ZIP containing the stapled app.
7. Sign that final archive with EdDSA and verify it against the configured public key. Create checksums and notices. Create a draft GitHub Release, upload explicit assets, download their bytes back, and compare SHA-256 hashes.
8. Make the verified release public, verify the public ZIP bytes, then atomically append the matching feed entry. Existing releases and assets are never overwritten. Feed writes use the current contents SHA and fail on conflicts or branch-protection denial.

`make release` validates configuration and requires protected publisher execution. It does not silently fall back to ad-hoc distribution. Missing credentials or failed gates block that action while local development remains available. The pipeline is configured source until a complete signed/notarized run proves it works for the publisher.

## Menu-bar updates

Configured publisher builds check the Sparkle feed daily by default. Settings can disable automatic checks; installation always remains a user choice. When Sparkle finds a compatible newer release, the menu label gains an arrow and the popover offers **Update to [version]…**. That action opens Sparkle's review and installation flow. Local and unconfigured fork builds show a disabled update action and explain the missing configuration.

Website/changelog updates publish independently through Vercel. Pushing source alone does not create a native update. Complete the trusted distribution sequence above, increase the build number, and publish the verified archive before its feed entry. Availability states are covered by an injected offline driver; a real download/install/relaunch still requires a completed publisher release and separate acceptance evidence.

## Recovery and forks

Preserve prior assets. If a bad update was published, withdraw only its feed item through a reviewed source change, document the affected version, and publish a subsequent verified release with a higher build number. Do not rewrite tags, replace old archives, or perform destructive data migrations as a rollback shortcut. A failure after public asset publication but before feed publication means the release exists but automatic discovery remains blocked; reconcile those states explicitly before retrying.

Forks must replace app branding, bundle identifiers, copyright/trademark attribution where appropriate, repository links, publisher identity, and feed. MIT code rights remain intact; trademark language must not add restrictions to the code license. Forks without publisher configuration work with updates disabled. This pipeline initially packages arm64 only; cross-compilation of Intel code would not establish Intel runtime acceptance.

CI includes macOS 14/Xcode 16.2 and macOS 26/Xcode 26.6 jobs. The announced macOS 14 hosted-runner retirement on November 2, 2026 requires retaining a real macOS 14 validation environment afterward. Runner labels and installed Xcode paths must be rechecked against the official runner-images inventory when updating CI.
