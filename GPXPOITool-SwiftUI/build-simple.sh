#!/bin/bash

# Simplified Enhanced Build System for GPX POI Tool
# Works with macOS Command Line Tools

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${BLUE}▶${NC} $1"; }
print_success() { echo -e "${GREEN}✅${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }

PROJECT_ROOT="/Users/espen/git/gpx-poi-tool/GPXPOITool-SwiftUI"
cd "$PROJECT_ROOT"

# Build configurations
BASE_FLAGS="-target arm64-apple-macos14.0 -framework Foundation -framework SwiftUI -framework CoreLocation -framework MapKit -Xlinker -rpath -Xlinker /usr/lib/swift"

case "${1:-build}" in
    "clean")
        print_status "Cleaning build artifacts..."
        rm -rf build temp *.log
        rm -f GPXPOIToolNative GPXPOITool_*
        print_success "Clean completed"
        ;;

    "debug"|"build")
        print_status "Building debug version..."
        mkdir -p build

        # Create preview-free versions
        ./preview-free.sh create > /dev/null

        # Build with debug flags
        swiftc $BASE_FLAGS -g -Onone \
               temp/preview-free/*.swift \
               temp/preview-free/{Models,Views,Services}/*.swift \
               -o build/GPXPOITool_debug

        ./preview-free.sh cleanup > /dev/null
        print_success "Debug build: build/GPXPOITool_debug"
        ;;

    "release")
        print_status "Building optimized release..."
        mkdir -p build

        # Create preview-free versions
        ./preview-free.sh create > /dev/null

        # Build optimized
        swiftc $BASE_FLAGS -O \
               temp/preview-free/*.swift \
               temp/preview-free/{Models,Views,Services}/*.swift \
               -o build/GPXPOITool_release

        ./preview-free.sh cleanup > /dev/null

        # Show size
        size=$(ls -lh build/GPXPOITool_release | awk '{print $5}')
        print_success "Release build: build/GPXPOITool_release ($size)"
        ;;

    "run")
        # Build debug if needed
        if [ ! -f build/GPXPOITool_debug ]; then
            $0 debug
        fi
        print_status "Running GPX POI Tool..."
        ./build/GPXPOITool_debug
        ;;

    "bundle")
        # Build release if needed
        if [ ! -f build/GPXPOITool_release ]; then
            $0 release
        fi

        print_status "Creating app bundle..."
        bundle_dir="build/GPX POI Tool.app"
        rm -rf "$bundle_dir"
        mkdir -p "$bundle_dir/Contents/MacOS"

        # Copy executable
        cp build/GPXPOITool_release "$bundle_dir/Contents/MacOS/GPX POI Tool"

        # Create Info.plist
        cat > "$bundle_dir/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>GPX POI Tool</string>
    <key>CFBundleIdentifier</key>
    <string>com.yourname.gpx-poi-tool</string>
    <key>CFBundleName</key>
    <string>GPX POI Tool</string>
    <key>CFBundleDisplayName</key>
    <string>GPX POI Tool</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

        print_success "App bundle: $bundle_dir"
        print_status "Run with: open '$bundle_dir'"
        ;;

    "test")
        print_status "Running syntax validation..."
        cd "GPX POI Tool"
        for file in *.swift {Models,Views,Services}/*.swift; do
            if [ -f "$file" ]; then
                swiftc -parse "$file" > /dev/null 2>&1
                echo "  ✅ $file"
            fi
        done
        print_success "All syntax checks passed"
        ;;

    "help")
        echo "🛠️  GPX POI Tool - Enhanced Build System"
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  build, debug   Build debug version"
        echo "  release        Build optimized release"
        echo "  run           Build and run debug version"
        echo "  bundle        Create macOS .app bundle"
        echo "  test          Run syntax validation"
        echo "  clean         Clean build artifacts"
        echo "  help          Show this help"
        ;;

    *)
        print_error "Unknown command: $1"
        $0 help
        exit 1
        ;;
esac
