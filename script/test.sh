#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
swift test --package-path Packages/HypergateCore --scratch-path "$BUILD_PATH/SwiftPM" "$@"
if [[ $# -eq 0 ]]; then "$PROJECT_ROOT/script/app-tests.sh"; fi
