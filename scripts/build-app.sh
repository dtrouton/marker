#!/bin/bash
# Build MD Mgr.app bundle from swift build output
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_DIR="$PROJECT_DIR/build/MD Mgr.app"
CONTENTS_DIR="$APP_DIR/Contents"

echo "Building release..."
cd "$PROJECT_DIR"
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS"
mkdir -p "$CONTENTS_DIR/Resources"

# Copy binary
cp "$BUILD_DIR/MDMgr" "$CONTENTS_DIR/MacOS/MD Mgr"

# Copy Info.plist
cp "$PROJECT_DIR/Sources/App/Info.plist" "$CONTENTS_DIR/Info.plist"

# Copy web editor bundle if it exists
if [ -d "$PROJECT_DIR/Resources/WebEditor" ]; then
    cp -R "$PROJECT_DIR/Resources/WebEditor" "$CONTENTS_DIR/Resources/WebEditor"
fi

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "Built: $APP_DIR"
echo "Run with: open \"$APP_DIR\""
