#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
PROJECT_KEY="$(printf '%s' "$PROJECT_ROOT" | shasum -a 256 | cut -c1-12)"
BUILD_PATH="${HYPERGATE_BUILD_PATH:-$HOME/Library/Caches/HypergateBar/$PROJECT_KEY}"
APP_PATH="$BUILD_PATH/DerivedData/Build/Products/Debug/HypergateBar.app"
mkdir -p "$BUILD_PATH"
