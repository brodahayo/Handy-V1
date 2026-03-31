#!/bin/bash
set -e

echo "=== Building Handy.app DMG Installer ==="
echo ""

# Navigate to the project directory
cd "$(dirname "$0")"

PROJECT_DIR="$(pwd)"
BUILD_DIR="${PROJECT_DIR}/build_dmg"
ARCHIVE_PATH="${BUILD_DIR}/Handy.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
APP_NAME="Handy"
DMG_NAME="Handy"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}.dmg"
DMG_TEMP="${BUILD_DIR}/${DMG_NAME}_temp.dmg"
VOL_NAME="Handy"
DMG_SIZE="200m"

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build the app in Release configuration
echo "Building ${APP_NAME}.app (Release)..."
xcodebuild \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}/DerivedData" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=NO \
    build 2>&1 | tail -5

# Find the built .app bundle
APP_PATH=$(find "${BUILD_DIR}/DerivedData" -name "${APP_NAME}.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "ERROR: Could not find ${APP_NAME}.app in build output"
    exit 1
fi

echo "Found app at: ${APP_PATH}"
echo ""

# Copy app to export directory
mkdir -p "$EXPORT_DIR"
cp -R "$APP_PATH" "${EXPORT_DIR}/${APP_NAME}.app"
APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"

# Ad-hoc sign with entitlements so macOS persists permission grants (mic, accessibility)
ENTITLEMENTS="${PROJECT_DIR}/Handy/Handy.entitlements"
echo "Signing app with entitlements..."
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP_PATH"
echo "Signature verified:"
codesign -dv "$APP_PATH" 2>&1 | head -5

echo "=== Creating DMG ==="

# Create a temporary DMG
hdiutil create -size "$DMG_SIZE" -fs HFS+ -volname "$VOL_NAME" "$DMG_TEMP"

# Mount it
MOUNT_DIR=$(hdiutil attach "$DMG_TEMP" -readwrite | grep -o '/Volumes/.*')
echo "Mounted at: $MOUNT_DIR"

# Copy the app
cp -R "$APP_PATH" "$MOUNT_DIR/"

# Create Applications symlink for drag-to-install
ln -s /Applications "$MOUNT_DIR/Applications"

# Set icon positions using AppleScript
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

# Clean up intermediate build files (keep the DMG and app)
rm -rf "${BUILD_DIR}/DerivedData"

echo ""
echo "=== Done! ==="
echo "DMG: ${DMG_PATH}"
echo "App: ${APP_PATH}"
echo ""
echo "To install: Open the DMG and drag Handy to Applications"
