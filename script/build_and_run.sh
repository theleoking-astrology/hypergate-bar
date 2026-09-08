#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
if pgrep -x HypergateBar >/dev/null; then pkill -x HypergateBar; fi
xcodebuild -project HypergateBar.xcodeproj -scheme HypergateBar -configuration Debug \
  -sdk macosx -destination 'platform=macOS,arch=arm64' -derivedDataPath "$BUILD_PATH/DerivedData" build
if [[ "${1:-}" == "--dashboard" ]]; then
  /usr/bin/open "$APP_PATH" --args --dashboard
else
  /usr/bin/open "$APP_PATH"
fi
