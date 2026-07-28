#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
DERIVED_DATA="$PROJECT_DIR/work/DerivedData"
OUTPUT_DIR="$PROJECT_DIR/outputs"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/Nelyr.app"
OUTPUT_APP="$OUTPUT_DIR/Nelyr.app"

cd "$PROJECT_DIR"
xcodegen generate
xcodebuild \
    -quiet \
    -project Nelyr.xcodeproj \
    -scheme Nelyr \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    -allowProvisioningUpdates \
    build

# Replace the generated bundle instead of merging with a previous build. Merging
# can leave stale files behind and invalidate the bundle's resource seal.
rm -rf "$OUTPUT_APP"
ditto "$BUILT_APP" "$OUTPUT_APP"
rm -f "$OUTPUT_DIR/Nelyr.zip"
ditto -c -k --sequesterRsrc --keepParent "$OUTPUT_APP" "$OUTPUT_DIR/Nelyr.zip"

# Xcode may register the Widget extension from DerivedData while building. If
# that registration remains alongside an installed copy, WidgetKit can select
# a stale development bundle. The packaged app will register its own extension
# when opened or installed.
BUILT_WIDGET="$BUILT_APP/Contents/PlugIns/NelyrWidget.appex"
if [[ -d "$BUILT_WIDGET" ]]; then
    /usr/bin/pluginkit -r "$BUILT_WIDGET" >/dev/null 2>&1 || true
fi

echo "$OUTPUT_APP"
