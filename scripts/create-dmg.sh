#!/bin/bash
# create-dmg.sh  —  Build the GUI app and package it into a distributable DMG.
# Usage: ./scripts/create-dmg.sh  (or: make dmg)

set -e

APP_NAME="MacinTouch"
DMG_LABEL="MacinTouch"
VERSION="1.0.1"
BUILD_DIR="build"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
STAGING_DIR="${BUILD_DIR}/dmg-staging"
DMG_TMP="${BUILD_DIR}/MacinTouch-${VERSION}-rw.dmg"
DMG_PATH="${BUILD_DIR}/MacinTouch-${VERSION}.dmg"
ICON_SRC="MacinTouchApp/Resources/AppIcon.icns"

# ── 1. Build ────────────────────────────────────────────────────────────────
echo "🔨 Building GUI (release)..."
make gui 2>&1 | tail -3

if [ ! -d "$APP_PATH" ]; then
    echo "❌ App bundle not found at $APP_PATH"
    exit 1
fi

# ── 2. Stage DMG contents ───────────────────────────────────────────────────
echo "📁 Staging DMG contents..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Set custom volume icon on staging folder
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$STAGING_DIR/.VolumeIcon.icns"
    # Mark the folder as having a custom icon (Finder info bit 0x0400)
    python3 -c "
import subprocess, sys
info = bytearray(32)
info[9] = 0x04  # hasCustomIcon bit in fdFlags
subprocess.run(['xattr', '-wx', 'com.apple.FinderInfo', info.hex(), sys.argv[1]])
" "$STAGING_DIR"
fi

# ── 3. Create writable DMG, set icon, convert to compressed ────────────────
echo "💿 Creating DMG..."
rm -f "$DMG_TMP" "$DMG_PATH"

# Step A: create a writable image so we can set the volume icon
hdiutil create \
    -volname "$DMG_LABEL $VERSION" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDRW \
    "$DMG_TMP"

# Step B: mount, copy volume icon, set custom-icon bit, unmount
VOLUME_PATH="/Volumes/$DMG_LABEL $VERSION"
hdiutil attach "$DMG_TMP" -noautoopen -quiet

if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$VOLUME_PATH/.VolumeIcon.icns"
    # Try SetFile first (Xcode dev tools); fall back to xattr
    if /usr/bin/SetFile -a C "$VOLUME_PATH" 2>/dev/null; then
        :
    else
        python3 -c "
import subprocess, sys
info = bytearray(32)
info[9] = 0x04
subprocess.run(['xattr', '-wx', 'com.apple.FinderInfo', info.hex(), sys.argv[1]])
" "$VOLUME_PATH"
    fi
fi

hdiutil detach "$VOLUME_PATH" -quiet

# Step C: convert writable image to compressed final DMG
hdiutil convert "$DMG_TMP" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

rm -f "$DMG_TMP"

# ── 4. Clean up ─────────────────────────────────────────────────────────────
rm -rf "$STAGING_DIR"

SIZE=$(du -sh "$DMG_PATH" | cut -f1)
echo ""
echo "✅ DMG ready: $DMG_PATH  ($SIZE)"
echo ""
echo "To install:"
echo "  1. Double-click $(basename $DMG_PATH)"
echo "  2. Drag MacinTouch → Applications"
echo "  3. Launch from Applications or Launchpad"
