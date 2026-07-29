#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_PATH="${1:-$PROJECT_DIR/outputs/Nelyr.app}"
OUTPUT_DIR="$PROJECT_DIR/outputs"
ALLOW_UNNOTARIZED="${NELYR_ALLOW_UNNOTARIZED:-0}"
NOTARY_PROFILE="${NELYR_NOTARY_PROFILE:-}"
DMG_SIGN_IDENTITY="${NELYR_DISTRIBUTION_IDENTITY:-}"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Missing app bundle: $APP_PATH" >&2
    echo "Build Nelyr first with ./scripts/build-signed-app.sh" >&2
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" \
    "$APP_PATH/Contents/Info.plist")
DMG_PATH="${2:-$OUTPUT_DIR/Nelyr-${VERSION}-${BUILD}.dmg}"

mkdir -p "$OUTPUT_DIR" "$PROJECT_DIR/work"
STAGING_DIR=$(mktemp -d "$PROJECT_DIR/work/Nelyr-DMG.XXXXXX")
cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

if [[ "$ALLOW_UNNOTARIZED" != "1" ]]; then
    if [[ "$DMG_SIGN_IDENTITY" != Developer\ ID\ Application:* ]]; then
        echo "NELYR_DISTRIBUTION_IDENTITY must be a Developer ID Application identity." >&2
        exit 1
    fi
    if [[ -z "$NOTARY_PROFILE" ]]; then
        echo "NELYR_NOTARY_PROFILE is required for a public release DMG." >&2
        exit 1
    fi
fi

ditto "$APP_PATH" "$STAGING_DIR/Nelyr.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "Nelyr" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    "$DMG_PATH"

if [[ -n "$DMG_SIGN_IDENTITY" ]]; then
    codesign --force --timestamp --sign "$DMG_SIGN_IDENTITY" "$DMG_PATH"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
    spctl --assess --type open \
        --context context:primary-signature \
        --verbose=2 \
        "$DMG_PATH"
elif [[ "$ALLOW_UNNOTARIZED" == "1" ]]; then
    echo "Created an unnotarized preview. Do not publish this DMG." >&2
fi

shasum -a 256 "$DMG_PATH"
echo "$DMG_PATH"
