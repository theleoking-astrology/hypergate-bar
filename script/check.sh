#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
git diff --check
python3 script/verify-vendor.py
python3 script/check-provenance.py
python3 script/schema.py
python3 script/audit-public.py
python3 script/test-publisher.py
python3 -m compileall -q script
for SCRIPT in script/*.sh; do bash -n "$SCRIPT"; done
plutil -lint HypergateBar.xcodeproj/project.pbxproj App/Resources/Info.plist
xcrun swift-format lint --strict --recursive App Packages/HypergateCore/Sources/HypergateCore \
  Packages/HypergateCore/Sources/HypergateAstronomyEngine Packages/HypergateCore/Sources/HypergateCLI \
  Packages/HypergateCore/Sources/HypergateBenchmark Packages/HypergateCore/Tests Tests Examples script/verify-update.swift
swift package --package-path Packages/HypergateCore dump-package > "$BUILD_PATH/package-description.json"
swift build --package-path Packages/HypergateCore --scratch-path "$BUILD_PATH/SwiftPM" --product hypergate
BIN_PATH="$(swift build --package-path Packages/HypergateCore --scratch-path "$BUILD_PATH/SwiftPM" --show-bin-path)"
python3 script/check-cli.py "$BIN_PATH/hypergate" "$BUILD_PATH/SchemaExamples"
swift run --package-path Examples/Consumer --scratch-path "$BUILD_PATH/Consumer" > "$BUILD_PATH/consumer-example.json"
python3 script/schema.py "$BUILD_PATH/consumer-example.json"
