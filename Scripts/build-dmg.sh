#!/bin/bash
# Build a signed Tinycast.app into build/Tinycast-<version>.dmg. Usage: build-dmg.sh [version]
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
IDENTITY="${CODE_SIGN_IDENTITY:-Tinycast Self-Signed}"
DERIVED="${TINYCAST_DERIVED_DATA_PATH:-build/DerivedData}"
BUILD_SETTINGS=(
    "CODE_SIGN_STYLE=Manual" "CODE_SIGN_IDENTITY=$IDENTITY" "OTHER_CODE_SIGN_FLAGS=--timestamp=none"
)
if [ -n "${1:-}" ]; then
    BUILD_SETTINGS+=("MARKETING_VERSION=$1")
fi
if [ -n "${TINYCAST_BUNDLE_IDENTIFIER:-}" ]; then
    BUILD_SETTINGS+=("TINYCAST_BUNDLE_IDENTIFIER=$TINYCAST_BUNDLE_IDENTIFIER")
fi

if ! security find-identity -p codesigning | grep -q "$IDENTITY"; then
    echo "✗ '$IDENTITY' code-signing identity not found — create it once (docs/signing.md)." >&2
    exit 1
fi

echo "▸ Building signed Tinycast.app (Release)…"
xcodebuild -project Tinycast.xcodeproj -scheme Tinycast -configuration Release \
    -derivedDataPath "$DERIVED" \
    "${BUILD_SETTINGS[@]}" \
    build

APP="$DERIVED/Build/Products/Release/Tinycast.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="build/Tinycast-${VERSION}.dmg"
./Scripts/verify-signature.sh "$APP"

echo "▸ Packaging ${DMG}"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Tinycast.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
diskutil image create from "$STAGE" --format UDZO --volumeName "Tinycast" "$DMG" >/dev/null

echo "✓ $DMG"
