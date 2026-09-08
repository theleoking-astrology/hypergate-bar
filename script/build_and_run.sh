#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
if pgrep -x HypergateBar >/dev/null; then pkill -x HypergateBar; fi
BUILD_SOURCE="$(python3 script/stage-build-source.py "$BUILD_PATH")"
xcodebuild -project "$BUILD_SOURCE/HypergateBar.xcodeproj" -scheme HypergateBar -configuration Debug \
  -sdk macosx -destination 'platform=macOS,arch=arm64' -derivedDataPath "$BUILD_PATH/DerivedData" build
/usr/bin/open "$APP_PATH" --args "$@"
