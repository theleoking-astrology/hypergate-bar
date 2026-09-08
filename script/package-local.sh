#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
BUILD_SOURCE="$(python3 script/stage-build-source.py "$BUILD_PATH")"
xcodebuild -project "$BUILD_SOURCE/HypergateBar.xcodeproj" -scheme HypergateBar \
  -configuration Debug -sdk macosx -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$BUILD_PATH/DerivedData" build
codesign --verify --deep --strict "$APP_PATH"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTPUT="$PROJECT_ROOT/dist/HypergateBar-development-arm64-$STAMP"
mkdir -p "$OUTPUT"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$OUTPUT/HypergateBar-development.zip"
cp LICENSE THIRD_PARTY_NOTICES.md "$OUTPUT/"
cp "$BUILD_SOURCE/source-manifest.json" "$OUTPUT/"
python3 - "$OUTPUT" <<'PY'
import pathlib, sys
folder = pathlib.Path(sys.argv[1])
(folder / 'DEVELOPMENT-ARTIFACT.txt').write_text('Ad-hoc signed development artifact. Not notarized. Not a trusted public release. Apple Silicon build. Build locally with Xcode when Gatekeeper blocks execution; do not disable Gatekeeper.\n')
PY
(cd "$OUTPUT" && shasum -a 256 HypergateBar-development.zip > SHA256SUMS)
echo "Development artifact: $OUTPUT"
