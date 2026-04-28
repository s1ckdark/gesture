#!/bin/bash
# scripts/make-icon.sh — Generate AppIcon.icns from a rendered SF Symbol.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RES_DIR="$PROJECT_DIR/GestureApp/Resources"
BUILD_DIR="$(mktemp -d)"
trap "rm -rf $BUILD_DIR" EXIT

mkdir -p "$RES_DIR"

# Render 1024x1024 PNG: blue rounded square + white hand.raised.fill SF Symbol.
cat > "$BUILD_DIR/render.swift" <<'SWIFT'
import AppKit
import Foundation

let outPath = CommandLine.arguments[1]
let size: CGFloat = 1024

let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

// Background — blue rounded square (macOS app icon convention)
let bgColor = NSColor(calibratedRed: 0.13, green: 0.49, blue: 0.95, alpha: 1.0)
bgColor.setFill()
let radius = size * 0.225  // macOS Big Sur+ corner radius ratio
let path = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                        xRadius: radius, yRadius: radius)
path.fill()

// Foreground — SF Symbol "hand.raised.fill" in white
let config = NSImage.SymbolConfiguration(pointSize: size * 0.62, weight: .semibold)
guard let symbol = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else {
    fputs("failed to load symbol\n", stderr)
    exit(1)
}

let symSize = symbol.size
let drawRect = NSRect(
    x: (size - symSize.width) / 2,
    y: (size - symSize.height) / 2 - size * 0.02,  // slight upward offset
    width: symSize.width, height: symSize.height
)
let tinted = NSImage(size: symSize)
tinted.lockFocus()
NSColor.white.set()
let symPath = NSBezierPath(rect: NSRect(origin: .zero, size: symSize))
symPath.fill()
symbol.draw(in: NSRect(origin: .zero, size: symSize), from: .zero,
            operation: .destinationIn, fraction: 1.0)
tinted.unlockFocus()
tinted.draw(in: drawRect)

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("failed to encode png\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: outPath))
SWIFT

swift "$BUILD_DIR/render.swift" "$BUILD_DIR/icon-1024.png"

# Build iconset with all required sizes
ICONSET="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
for sz in 16 32 64 128 256 512 1024; do
    sips -z $sz $sz "$BUILD_DIR/icon-1024.png" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
done
# @2x variants
cp "$ICONSET/icon_32x32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"
rm "$ICONSET/icon_64x64.png"  # not a standard slot

iconutil -c icns "$ICONSET" -o "$RES_DIR/AppIcon.icns"
echo "AppIcon.icns generated at $RES_DIR/AppIcon.icns"
