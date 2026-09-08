#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
BUILD_SOURCE="$(python3 script/stage-build-source.py "$BUILD_PATH")"
RESULT_PATH="$BUILD_PATH/TestResults/$(date -u +%Y%m%dT%H%M%SZ).xcresult"
mkdir -p "$BUILD_PATH/TestResults"
xcodebuild -project "$BUILD_SOURCE/HypergateBar.xcodeproj" -scheme HypergateBar \
  -configuration Debug -sdk macosx -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$BUILD_PATH/DerivedData" -resultBundlePath "$RESULT_PATH" test "$@"
