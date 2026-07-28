#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
OUTPUT_DIR="$PROJECT_DIR/outputs"
APP_DIR="$OUTPUT_DIR/Nelyr.app"
CONTENTS_DIR="$APP_DIR/Contents"
SIGN_IDENTITY="${NELYR_SIGN_IDENTITY:-${DAILY_DESK_SIGN_IDENTITY:--}}"

cd "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/work/swift/cache" "$PROJECT_DIR/work/swift/config" \
    "$PROJECT_DIR/work/swift/security" "$PROJECT_DIR/work/swift/modules"
CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/work/swift/modules" swift build \
    --disable-sandbox \
    --jobs 1 \
    --cache-path "$PROJECT_DIR/work/swift/cache" \
    --config-path "$PROJECT_DIR/work/swift/config" \
    --security-path "$PROJECT_DIR/work/swift/security" \
    --scratch-path "$PROJECT_DIR/.build" \
    -c release

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp ".build/release/Nelyr" "$CONTENTS_DIR/MacOS/Nelyr"
if [[ ! -f "$PROJECT_DIR/assets/AppIcon.png" ]]; then
    "$PROJECT_DIR/scripts/make-icon.sh" community "$PROJECT_DIR/assets/AppIcon.png"
fi
cp "$PROJECT_DIR/assets/AppIcon.png" "$CONTENTS_DIR/Resources/AppIcon.png"
cp "$PROJECT_DIR/assets/Info.plist" "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
rm -f "$OUTPUT_DIR/Nelyr.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$OUTPUT_DIR/Nelyr.zip"
echo "$APP_DIR"
