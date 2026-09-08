# Package, CLI, and JSON reuse

Add the local `Packages/HypergateCore` package or reference that package directory in a checkout. Products are `HypergateCore`, `HypergateAstronomyEngine`, and `hypergate`. The additional `hypergate-benchmark` executable is a developer measurement utility.

`EphemerisProvider` exposes metadata and batched positions through an asynchronous throwing Sendable interface. `EventEngine` accepts that interface and an injectable `WallClock`. It supports typed `EventQuery` values and returns versioned `EventDocument` values. The application and CLI share this engine and `UTCDate.encoder()`; no separate app-specific astronomy algorithm exists.

The compiled example in `Examples/Consumer` requests Moon ingresses using only public package interfaces:

```
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)" swift run --package-path Examples/Consumer
```

Build the CLI with `swift build --package-path Packages/HypergateCore --product hypergate`. Its build directory can be obtained with `swift build --package-path Packages/HypergateCore --show-bin-path`. SDKROOT should be set to Xcode’s macOS SDK when the default Command Line Tools path is unavailable.

```
hypergate sky --at 2026-09-08T19:00:00Z --json
hypergate events --from 2026-09-08T00:00:00Z --to 2026-10-08T00:00:00Z --types ingress,square,opposition,station --json
```

Use `--bodies moon,mercury,mars` for a body filter. Both bodies must be selected for an aspect. `station` expands to direct and retrograde stations; optional types include `conjunction`, `semisquare`, and `sesquiquadrate`. Unknown or duplicate flags, unsupported bodies/types, impossible dates, missing explicit offsets, reversed ranges, and ranges over 90 elapsed days fail with nonzero status. Successful JSON is written only to stdout. Structured failures go to stderr and never masquerade as successful empty forecasts.

`docs/document-v1.schema.json` describes sky and event documents. Schema version 1 includes provider revision/convention, calculation timestamp, UTC dates, query bounds and coverage, canonical event IDs, body/type arrays, and relevant longitude/aspect/sign data. Nullable event-specific values are omitted. UTC timestamps use fractional seconds and `Z`. Clients should distinguish schema changes from provider/model changes and must inspect coverage rather than infer an unlimited forecast.

App export uses a native save dialog and serializes the calculated forecast document. Cancelling the dialog writes nothing. Display-zone formatting does not alter exported instants. The current display filter can differ from the complete calculated forecast; exports retain the document’s explicit query so consumers can apply their own filters.

There is no downloadable code, shell-script extension, or executable plugin mechanism. Extensions are compiled consumers or replacement providers, reviewed and built as ordinary Swift source.
