#!/bin/bash
set -e

echo "=== Building Handy.app ==="

cd "$(dirname "$0")"

# Clean previous builds
rm -rf build dist

# Build the .app bundle
python3 setup_app.py py2app

echo ""
echo "=== Creating DMG ==="

APP_PATH="dist/Handy.app"
DMG_NAME="Handy"
DMG_PATH="dist/${DMG_NAME}.dmg"
DMG_TEMP="dist/${DMG_NAME}_temp.dmg"
VOL_NAME="Handy"
DMG_SIZE="200m"

# Create a temporary DMG
hdiutil create -size "$DMG_SIZE" -fs HFS+ -volname "$VOL_NAME" "$DMG_TEMP"

# Mount it
MOUNT_DIR=$(hdiutil attach "$DMG_TEMP" -readwrite | grep "/Volumes/" | awk '{print $NF}')
echo "Mounted at: $MOUNT_DIR"

# Copy the app
cp -R "$APP_PATH" "$MOUNT_DIR/"

# Create Applications symlink for drag-to-install
ln -s /Applications "$MOUNT_DIR/Applications"

# Set background and icon positions using AppleScript
osascript <<'APPLESCRIPT'
tell application "Finder"
    tell disk "Handy"
        open
        set current view of container window to icon view
        set theViewOptions to the icon view options of container window
        set icon size of theViewOptions to 128
        set arrangement of theViewOptions to not arranged
        set position of item "Handy.app" of container window to {140, 200}
        set position of item "Applications" of container window to {400, 200}
        set the bounds of container window to {100, 100, 640, 460}
        close
    end tell
end tell
APPLESCRIPT

# Unmount
sync
hdiutil detach "$MOUNT_DIR"

# Convert to compressed DMG
hdiutil convert "$DMG_TEMP" -format UDZO -o "$DMG_PATH"
rm -f "$DMG_TEMP"

echo ""
echo "=== Done! ==="
echo "DMG: $DMG_PATH"
echo ""
echo "To install: Open the DMG and drag Handy to Applications"
