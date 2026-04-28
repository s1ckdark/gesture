#!/bin/bash
# scripts/make-dmg.sh — Package dist/GestureApp.app into a .dmg suitable
# for distribution. Builds the .app first if it doesn't exist.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"
APP_PATH="$DIST_DIR/GestureApp.app"
VERSION="${1:-0.1.0}"
DMG_NAME="Gesture-$VERSION.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

# Build app if missing — universal by default for distribution
if [ ! -d "$APP_PATH" ]; then
    echo "App bundle not found, building universal..."
    "$SCRIPT_DIR/make-app.sh" universal
fi

# Stage in a temp dir with /Applications symlink for drag-to-install UX
STAGE="$(mktemp -d)/Gesture"
trap "rm -rf $(dirname $STAGE)" EXIT
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# Remove any prior DMG
rm -f "$DMG_PATH"

echo "Creating DMG at $DMG_PATH..."
hdiutil create \
    -volname "Gesture $VERSION" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG_PATH" >/dev/null

DMG_SIZE_KB=$(du -k "$DMG_PATH" | awk '{print $1}')
echo "DMG built: $DMG_PATH (${DMG_SIZE_KB} KB)"
