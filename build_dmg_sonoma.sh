#!/bin/bash
set -e

APP_NAME="OsxPaster"
VERSION="1.0"
SCHEME="OsxPaster"
PROJECT="OsxPaster.xcodeproj"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION-sonoma.dmg"

echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving..."
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  MACOSX_DEPLOYMENT_TARGET=14.0

# Pull the .app directly from the archive (no Developer ID cert required).
# To use proper developer-id signing instead, you need a "Developer ID
# Application" certificate from the Apple Developer portal.
APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
  echo "Error: .app not found in archive at $APP_PATH"
  exit 1
fi
echo "==> Using app from archive: $APP_PATH"

echo "==> Creating DMG..."
TMP_DMG="$BUILD_DIR/tmp_$APP_NAME.dmg"
MOUNT_DIR="/Volumes/$APP_NAME"

# Size the image to fit the app + some padding
APP_SIZE_KB=$(du -sk "$APP_PATH" | cut -f1)
DMG_SIZE_KB=$(( APP_SIZE_KB + 10240 ))

hdiutil create \
  -size "${DMG_SIZE_KB}k" \
  -fs HFS+ \
  -volname "$APP_NAME" \
  -layout NONE \
  "$TMP_DMG"

hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_DIR"

cp -R "$APP_PATH" "$MOUNT_DIR/"
ln -s /Applications "$MOUNT_DIR/Applications"

hdiutil detach "$MOUNT_DIR"

hdiutil convert "$TMP_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH"

rm -f "$TMP_DMG"

echo ""
echo "==> Done: $DMG_PATH"
