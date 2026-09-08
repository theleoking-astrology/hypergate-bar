#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
swift run -c release --package-path Packages/HypergateCore --scratch-path "$BUILD_PATH/SwiftPM" hypergate-benchmark
