#!/bin/bash
set -euo pipefail

SCHEME="ScriptFlow"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build/release"
ARCHIVE_ARM="$BUILD_DIR/ScriptFlow-arm64.xcarchive"
ARCHIVE_X86="$BUILD_DIR/ScriptFlow-x86_64.xcarchive"
APP_NAME="ScriptFlow.app"
OUTPUT_DIR="$BUILD_DIR/universal"
OUTPUT_APP="$OUTPUT_DIR/$APP_NAME"

# Extract version from Xcode project for DMG naming
VERSION=$(xcodebuild -project "$PROJECT_DIR/ScriptFlow.xcodeproj" \
  -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
  | grep MARKETING_VERSION | head -1 | awk '{print $NF}' || echo "0.1.0")
if [ -z "$VERSION" ]; then
  VERSION="0.1.0"
fi

DMG_NAME="ScriptFlow-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

echo "Building ScriptFlow v${VERSION}"
echo ""

echo "Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

echo "Building for Apple Silicon (arm64)..."
xcodebuild archive \
  -project "$PROJECT_DIR/ScriptFlow.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_ARM" \
  -destination "generic/platform=macOS" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -quiet

echo "Building for Intel (x86_64)..."
xcodebuild archive \
  -project "$PROJECT_DIR/ScriptFlow.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_X86" \
  -destination "generic/platform=macOS" \
  ARCHS=x86_64 \
  ONLY_ACTIVE_ARCH=NO \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -quiet

ARM_APP="$ARCHIVE_ARM/Products/Applications/$APP_NAME"
X86_APP="$ARCHIVE_X86/Products/Applications/$APP_NAME"

echo "Creating universal binary..."
cp -R "$ARM_APP" "$OUTPUT_APP"

# Find all Mach-O binaries and lipo them together
find "$ARM_APP" -type f | while read -r arm_file; do
  rel="${arm_file#$ARM_APP}"
  x86_file="$X86_APP$rel"
  out_file="$OUTPUT_APP$rel"

  if [ -f "$x86_file" ] && file "$arm_file" | grep -q "Mach-O"; then
    lipo -create "$arm_file" "$x86_file" -output "$out_file" 2>/dev/null || true
  fi
done

# Ad-hoc codesign the universal binary
echo "Ad-hoc code signing..."
codesign --force --deep --sign - "$OUTPUT_APP"

echo "Creating DMG..."
rm -f "$DMG_PATH"

# Create a temporary DMG folder with the app, Applications symlink, and README
DMG_STAGING="$BUILD_DIR/dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$OUTPUT_APP" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
cp "$PROJECT_DIR/README.txt" "$DMG_STAGING/" 2>/dev/null || true

hdiutil create \
  -volname "ScriptFlow" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH" \
  -quiet

rm -rf "$DMG_STAGING"

echo ""
echo "Done!"
echo "   App:  $OUTPUT_APP"
echo "   DMG:  $DMG_PATH"
echo ""
lipo -info "$OUTPUT_APP/Contents/MacOS/ScriptFlow"
