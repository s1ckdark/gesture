#!/bin/bash
# scripts/make-app.sh — Wrap the SwiftPM binary in a proper macOS .app bundle.
# Required for SwiftUI MenuBarExtra to show in the menu bar reliably,
# and for camera/Accessibility permission prompts to work correctly.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$PROJECT_DIR/GestureApp"

CONFIG="${1:-debug}"  # debug | release | universal
case "$CONFIG" in
    debug)
        BUILD_CONFIG="debug"
        BUILD_FLAGS=()
        BIN_PATH="$APP_DIR/.build/arm64-apple-macosx/debug/GestureApp"
        ;;
    release)
        BUILD_CONFIG="release"
        BUILD_FLAGS=()
        BIN_PATH="$APP_DIR/.build/arm64-apple-macosx/release/GestureApp"
        ;;
    universal)
        BUILD_CONFIG="release"
        BUILD_FLAGS=(--arch arm64 --arch x86_64)
        # SwiftPM emits the universal binary at apple/Products/Release/<target>
        BIN_PATH="$APP_DIR/.build/apple/Products/Release/GestureApp"
        ;;
    *) echo "Usage: $0 [debug|release|universal]"; exit 1 ;;
esac

echo "Building Swift app ($CONFIG)..."
cd "$APP_DIR"
swift build -c "$BUILD_CONFIG" "${BUILD_FLAGS[@]}"

OUT="$PROJECT_DIR/dist/GestureApp.app"
echo "Creating bundle at $OUT..."
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS"
mkdir -p "$OUT/Contents/Resources"

cp "$BIN_PATH" "$OUT/Contents/MacOS/GestureApp"

# App icon (generate if missing)
ICON_SRC="$APP_DIR/Resources/AppIcon.icns"
if [ ! -f "$ICON_SRC" ]; then
    echo "Generating app icon..."
    "$SCRIPT_DIR/make-icon.sh"
fi
cp "$ICON_SRC" "$OUT/Contents/Resources/AppIcon.icns"

cat > "$OUT/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.s1ckdark.gesture</string>
    <key>CFBundleExecutable</key>
    <string>GestureApp</string>
    <key>CFBundleName</key>
    <string>Gesture</string>
    <key>CFBundleDisplayName</key>
    <string>Gesture</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>0.1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSCameraUsageDescription</key>
    <string>Gesture needs camera access to recognize hand gestures via the Python engine.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Gesture executes shell commands and AppleScript actions you configure for hand gestures.</string>
</dict>
</plist>
PLIST

# Self-sign so macOS lets it run from the bundle path.
codesign --force --deep --sign - "$OUT" 2>/dev/null || true

echo "App bundle ready: $OUT"
echo "Run with: open $OUT"
