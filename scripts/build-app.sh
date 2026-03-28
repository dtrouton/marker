#!/bin/bash
# Build Marker.app bundle from swift build output
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_DIR="$PROJECT_DIR/build/Marker.app"
CONTENTS_DIR="$APP_DIR/Contents"

echo "Building release..."
cd "$PROJECT_DIR"
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS"
mkdir -p "$CONTENTS_DIR/Resources"

# Copy binary
cp "$BUILD_DIR/MDMgr" "$CONTENTS_DIR/MacOS/Marker"

# Copy Info.plist and resolve Xcode build variables for SPM
sed \
    -e 's/$(EXECUTABLE_NAME)/Marker/g' \
    -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/com.marker.app/g' \
    -e 's/$(CURRENT_PROJECT_VERSION)/1/g' \
    -e 's/$(MARKETING_VERSION)/1.0.0/g' \
    -e 's/$(MACOSX_DEPLOYMENT_TARGET)/14.0/g' \
    "$PROJECT_DIR/Sources/App/Info.plist" > "$CONTENTS_DIR/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "Built: $APP_DIR"
echo "Run with: open \"$APP_DIR\""
