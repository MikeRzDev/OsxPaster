#!/bin/bash
set -e

APP_NAME="OsxPaster"
VERSION="1.0"
SCHEME="OsxPaster"
PROJECT="OsxPaster.xcodeproj"
BUILD_DIR="build"
DERIVED="$BUILD_DIR/DerivedData"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

echo "==> Cleaning..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Building Release..."
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

APP_PATH="$DERIVED/Build/Products/Release/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
  echo "Error: .app not found at $APP_PATH"
  exit 1
fi

# Strip get-task-allow entitlement (debug-only, causes issues on other Macs)
echo "==> Ad-hoc signing (strip debug entitlements)..."
codesign --force --deep --sign - "$APP_PATH"

echo "==> Creating DMG..."
TMP_DMG="$BUILD_DIR/tmp_$APP_NAME.dmg"
MOUNT_DIR="/Volumes/$APP_NAME"

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
echo "==> Done: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"
echo "    Install: open the DMG and drag OsxPaster to Applications"
