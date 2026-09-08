#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
python3 script/validate-publisher.py
if [[ "${GITHUB_ACTIONS:-}" != true || "${HYPERGATE_PROTECTED_PUBLISHER:-}" != verified ]]; then
  echo 'Publisher execution requires the protected GitHub publisher workflow. Local development uses make package-local.' >&2
  exit 1
fi
: "${HYPERGATE_RELEASE_TAG:?Exact existing source tag required}"
: "${HYPERGATE_RELEASE_SHA:?Exact source commit required}"
[[ "$(git rev-parse HEAD)" == "$HYPERGATE_RELEASE_SHA" ]]
[[ "$(git rev-parse "$HYPERGATE_RELEASE_TAG^{commit}")" == "$HYPERGATE_RELEASE_SHA" ]]
[[ -z "$(git status --porcelain)" ]]
[[ "$HYPERGATE_RELEASE_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
VERSION="${HYPERGATE_RELEASE_TAG#v}"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' App/Resources/Info.plist)" == "$VERSION" ]]
RELEASE_PATH="$(mktemp -d "$BUILD_PATH/publisher-XXXXXX")"
export RELEASE_PATH
security find-identity -v -p codesigning | /usr/bin/grep -F "$DEVELOPER_ID_APPLICATION" > "$RELEASE_PATH/identity-verification.txt"
xcrun notarytool history --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --output-format json > "$RELEASE_PATH/notary-access.json"
curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' "$SPARKLE_FEED_URL" -o "$RELEASE_PATH/existing-appcast.xml"
python3 - "$RELEASE_PATH/existing-appcast.xml" <<'PY'
import sys, plistlib, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
assert root.tag == 'rss' and root.find('channel') is not None, 'Not an RSS update feed'
with open('App/Resources/Info.plist', 'rb') as file:
    build = int(plistlib.load(file)['CFBundleVersion'])
for item in root.findall('channel/item'):
    previous = item.findtext('{http://www.andymatuschak.org/xml-namespaces/sparkle}version')
    assert previous is not None and build > int(previous), 'Build number must increase beyond every published update'
PY
BUILD_SOURCE="$(python3 script/stage-build-source.py "$BUILD_PATH")"
xcodebuild -project "$BUILD_SOURCE/HypergateBar.xcodeproj" -scheme HypergateBar -configuration Release \
  -sdk macosx -destination 'generic/platform=macOS' -archivePath "$RELEASE_PATH/HypergateBar.xcarchive" \
  -derivedDataPath "$BUILD_PATH/PublisherDerivedData" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" DEVELOPMENT_TEAM="$APPLE_TEAM_ID" ENABLE_HARDENED_RUNTIME=YES archive
PUBLISH_APP="$RELEASE_PATH/HypergateBar.xcarchive/Products/Applications/HypergateBar.app"
export PUBLISH_APP
python3 - <<'PY'
import os, pathlib, plistlib
path = pathlib.Path(os.environ['PUBLISH_APP']) / 'Contents/Info.plist'
with path.open('rb') as file: info = plistlib.load(file)
info.update(SUFeedURL=os.environ['SPARKLE_FEED_URL'], SUPublicEDKey=os.environ['SPARKLE_PUBLIC_ED_KEY'],
            HypergatePublisherVerified=True, SUEnableAutomaticChecks=True, SUAutomaticallyUpdate=False,
            SUScheduledCheckInterval=86400, SUAllowsAutomaticUpdates=False, SUEnableSystemProfiling=False,
            SUShowReleaseNotes=False)
with path.open('wb') as file: plistlib.dump(info, file)
PY
# Re-sign known embedded code from the inside out with this publisher identity.
# Never use --deep for signing or add library-validation/JIT exceptions.
SPARKLE_FRAMEWORK="$PUBLISH_APP/Contents/Frameworks/Sparkle.framework"
for NESTED in "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Downloader.xpc" \
              "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Installer.xpc" \
              "$SPARKLE_FRAMEWORK/Versions/B/Autoupdate" \
              "$SPARKLE_FRAMEWORK/Versions/B/Updater.app" \
              "$SPARKLE_FRAMEWORK"; do
  test -e "$NESTED"
  codesign --force --options runtime --timestamp --preserve-metadata=identifier,entitlements --sign "$DEVELOPER_ID_APPLICATION" "$NESTED"
done
codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$PUBLISH_APP"
codesign --verify --deep --strict --verbose=2 "$PUBLISH_APP"
codesign --display --verbose=4 "$PUBLISH_APP" 2> "$RELEASE_PATH/signature.txt"
/usr/bin/grep -F "TeamIdentifier=$APPLE_TEAM_ID" "$RELEASE_PATH/signature.txt"
ditto -c -k --keepParent "$PUBLISH_APP" "$RELEASE_PATH/notarization-upload.zip"
xcrun notarytool submit "$RELEASE_PATH/notarization-upload.zip" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait --output-format json > "$RELEASE_PATH/notarization.json"
python3 - "$RELEASE_PATH/notarization.json" <<'PY'
import json, sys
assert json.load(open(sys.argv[1]))['status'] == 'Accepted', 'Notarization did not succeed'
PY
xcrun stapler staple "$PUBLISH_APP"
xcrun stapler validate "$PUBLISH_APP"
codesign --verify --deep --strict "$PUBLISH_APP"
spctl --assess --type execute --verbose=4 "$PUBLISH_APP"
OUTPUT="$PROJECT_ROOT/dist/$HYPERGATE_RELEASE_TAG"
mkdir -p "$OUTPUT"
ditto -c -k --sequesterRsrc --keepParent "$PUBLISH_APP" "$OUTPUT/HypergateBar-$VERSION-arm64.zip"
cp LICENSE THIRD_PARTY_NOTICES.md "$OUTPUT/"
python3 script/sign-update.py "$OUTPUT/HypergateBar-$VERSION-arm64.zip" "$OUTPUT/update-signature.json" "$BUILD_PATH/PublisherDerivedData"
(cd "$OUTPUT" && shasum -a 256 "HypergateBar-$VERSION-arm64.zip" LICENSE THIRD_PARTY_NOTICES.md > SHA256SUMS)
echo "Verified publisher artifacts: $OUTPUT"
