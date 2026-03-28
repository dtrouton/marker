#!/bin/bash
# Build Marker.app bundle
# Usage:
#   ./build-app.sh              Build with swift build (no Quick Look extension)
#   ./build-app.sh --xcode      Build with xcodebuild (includes Quick Look extension)
#   ./build-app.sh --install    Build with swift build and install to /Applications
#   ./build-app.sh --xcode --install  Build with xcodebuild and install
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$PROJECT_DIR/build/Marker.app"
CONTENTS_DIR="$APP_DIR/Contents"

USE_XCODE=false
DO_INSTALL=false

for arg in "$@"; do
    case "$arg" in
        --xcode) USE_XCODE=true ;;
        --install) DO_INSTALL=true ;;
    esac
done

cd "$PROJECT_DIR"

if [ "$USE_XCODE" = true ]; then
    echo "Building with xcodebuild (includes Quick Look extension)..."

    # Regenerate project if xcodegen is available
    if command -v xcodegen &>/dev/null; then
        xcodegen generate
    fi

    xcodebuild -project MDMgr.xcodeproj -scheme MDMgr -configuration Release build

    # Find the built app in DerivedData
    XCODE_BUILD_DIR=$(xcodebuild -project MDMgr.xcodeproj -scheme MDMgr -configuration Release -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')
    XCODE_APP="$XCODE_BUILD_DIR/Marker.app"

    if [ ! -d "$XCODE_APP" ]; then
        echo "Error: Built app not found at $XCODE_APP"
        exit 1
    fi

    echo "Copying app bundle..."
    rm -rf "$APP_DIR"
    mkdir -p "$(dirname "$APP_DIR")"
    cp -R "$XCODE_APP" "$APP_DIR"

    echo "Built: $APP_DIR (with Quick Look extension)"
else
    BUILD_DIR="$PROJECT_DIR/.build/release"

    echo "Building with swift build..."
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

    # Copy app icon (SPM doesn't compile asset catalogs, so we use iconutil)
    ICON_DIR="$PROJECT_DIR/Resources/Assets.xcassets/AppIcon.appiconset"
    if [ -f "$ICON_DIR/icon_512x512@2x.png" ]; then
        ICONSET_DIR=$(mktemp -d)/Marker.iconset
        mkdir -p "$ICONSET_DIR"
        cp "$ICON_DIR/icon_16x16.png" "$ICONSET_DIR/icon_16x16.png"
        cp "$ICON_DIR/icon_16x16@2x.png" "$ICONSET_DIR/icon_16x16@2x.png"
        cp "$ICON_DIR/icon_32x32.png" "$ICONSET_DIR/icon_32x32.png"
        cp "$ICON_DIR/icon_32x32@2x.png" "$ICONSET_DIR/icon_32x32@2x.png"
        cp "$ICON_DIR/icon_128x128.png" "$ICONSET_DIR/icon_128x128.png"
        cp "$ICON_DIR/icon_128x128@2x.png" "$ICONSET_DIR/icon_128x128@2x.png"
        cp "$ICON_DIR/icon_256x256.png" "$ICONSET_DIR/icon_256x256.png"
        cp "$ICON_DIR/icon_256x256@2x.png" "$ICONSET_DIR/icon_256x256@2x.png"
        cp "$ICON_DIR/icon_512x512.png" "$ICONSET_DIR/icon_512x512.png"
        cp "$ICON_DIR/icon_512x512@2x.png" "$ICONSET_DIR/icon_512x512@2x.png"
        iconutil -c icns -o "$CONTENTS_DIR/Resources/AppIcon.icns" "$ICONSET_DIR" 2>/dev/null
        rm -rf "$(dirname "$ICONSET_DIR")"
    fi

    # Copy Quick Look extension if previously built with xcodebuild
    XCODE_BUILD_DIR=$(xcodebuild -project MDMgr.xcodeproj -scheme MDMgr -configuration Release -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}' || true)
    QL_EXT="${XCODE_BUILD_DIR:-}/MarkerQuickLook.appex"
    if [ -d "$QL_EXT" ]; then
        echo "Copying Quick Look extension from previous xcodebuild..."
        mkdir -p "$CONTENTS_DIR/PlugIns"
        cp -R "$QL_EXT" "$CONTENTS_DIR/PlugIns/"
    fi

    # Create PkgInfo
    echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

    echo "Built: $APP_DIR"
fi

# Install to /Applications if --install flag passed
if [ "$DO_INSTALL" = true ]; then
    echo "Installing to /Applications..."
    killall "Marker" 2>/dev/null || true
    sleep 1
    rm -rf /Applications/Marker.app
    cp -R "$APP_DIR" /Applications/Marker.app
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Marker.app
    echo "Installed to /Applications/Marker.app"
    open /Applications/Marker.app
else
    echo "Run with: open \"$APP_DIR\""
    echo "Install with: $0 --install"
fi
