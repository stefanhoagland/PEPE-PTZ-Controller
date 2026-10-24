#!/bin/bash
# Builds "PEPE PTZ Controller.app" for Apple silicon and Intel Macs, and zips it into dist/.
# Usage: scripts/build-app.sh [version]   (defaults to the git tag name, without the leading "v")
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-${GITHUB_REF_NAME:-0.0.0}}"
VERSION="${VERSION#v}"
APP_NAME="PEPE PTZ Controller"
APP="dist/$APP_NAME.app"

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/PEPEPTZController" "$APP/Contents/MacOS/PEPEPTZController"
sed "s/__VERSION__/$VERSION/g" scripts/Info.plist > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"

# Ad-hoc signature: enough for the app to run, but it isn't notarized by Apple.
codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP"

(cd dist && ditto -c -k --keepParent "$APP_NAME.app" PEPE-PTZ-Controller.zip)
lipo -info "$APP/Contents/MacOS/PEPEPTZController"
echo "Built dist/PEPE-PTZ-Controller.zip (version $VERSION)"
