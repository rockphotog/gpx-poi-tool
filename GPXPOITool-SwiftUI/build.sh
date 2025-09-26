#!/bin/bash

# Enhanced GPX POI Tool Build System
# Requires: macOS Command Line Tools (installed ✓)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT_ROOT="/Users/espen/git/gpx-poi-tool/GPXPOITool-SwiftUI"
APP_NAME="GPXPOITool"
BUILD_DIR="$PROJECT_ROOT/build"
SOURCE_DIR="$PROJECT_ROOT/GPX POI Tool"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Enhanced GPX POI Tool Build System"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  build      Build the application (default)"
    echo "  clean      Clean build artifacts"
    echo "  test       Run syntax and compilation tests"
    echo "  run        Build and run the application"
    echo "  lint       Run Swift linting/syntax checks"
    echo "  debug      Build with debug symbols"
    echo "  release    Build optimized release version"
    echo "  bundle     Create macOS app bundle structure"
    echo "  help       Show this help message"
}

# Function to clean build artifacts
clean_build() {
    print_status "Cleaning build artifacts..."
    rm -rf "$BUILD_DIR"
    rm -f "$PROJECT_ROOT/$APP_NAME" "$PROJECT_ROOT/GPXPOIToolNative"
    print_success "Clean completed"
}

# Function to create build directory
setup_build_dir() {
    mkdir -p "$BUILD_DIR"
}

# Function to check Swift syntax
lint_swift() {
    print_status "Running Swift syntax checks..."
    cd "$SOURCE_DIR"

    local files=(
        "GPXPOIToolApp.swift"
        "ContentView.swift"
        "Models/POI.swift"
        "Views/MapView.swift"
        "Views/POIListView.swift"
        "Services/GPXProcessor.swift"
        "Services/ElevationService.swift"
        "Services/KMLExporter.swift"
    )

    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            print_status "Checking syntax: $file"
            swiftc -parse "$file" > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "  ${GREEN}✓${NC} $file"
            else
                echo -e "  ${RED}✗${NC} $file - syntax error"
                swiftc -parse "$file"
                return 1
            fi
        else
            print_warning "File not found: $file"
        fi
    done

    print_success "All syntax checks passed"
}

# Function to test compilation
test_compilation() {
    print_status "Testing full project compilation..."
    cd "$SOURCE_DIR"

    # Test compilation without generating executable
    swiftc -parse Models/*.swift Views/*.swift Services/*.swift *.swift
    if [ $? -eq 0 ]; then
        print_success "Compilation test passed"
    else
        print_error "Compilation test failed"
        return 1
    fi
}

# Function to build debug version
build_debug() {
    print_status "Building debug version..."
    setup_build_dir

    # Create preview-free versions for command-line compilation
    ./preview-free.sh create > /dev/null 2>&1

    local build_result
    swiftc -target arm64-apple-macos14.0 \
           -framework Foundation \
           -framework SwiftUI \
           -framework CoreLocation \
           -framework MapKit \
           -g \
           -Onone \
           -Xlinker -rpath \
           -Xlinker /usr/lib/swift \
           "temp/preview-free"/*.swift \
           "temp/preview-free/Models"/*.swift \
           "temp/preview-free/Views"/*.swift \
           "temp/preview-free/Services"/*.swift \
           -o "$BUILD_DIR/${APP_NAME}_debug"

    build_result=$?

    # Clean up temp files
    ./preview-free.sh cleanup > /dev/null 2>&1

    if [ $build_result -eq 0 ]; then
        print_success "Debug build completed: $BUILD_DIR/${APP_NAME}_debug"
    else
        print_error "Debug build failed"
        return 1
    fi
}

# Function to build release version
build_release() {
    print_status "Building optimized release version..."
    setup_build_dir

    # Create preview-free versions for command-line compilation
    ./preview-free.sh create > /dev/null 2>&1

    local build_result
    swiftc -target arm64-apple-macos14.0 \
           -framework Foundation \
           -framework SwiftUI \
           -framework CoreLocation \
           -framework MapKit \
           -O \
           -Xlinker -rpath \
           -Xlinker /usr/lib/swift \
           "temp/preview-free"/*.swift \
           "temp/preview-free/Models"/*.swift \
           "temp/preview-free/Views"/*.swift \
           "temp/preview-free/Services"/*.swift \
           -o "$BUILD_DIR/${APP_NAME}_release"

    build_result=$?

    # Clean up temp files
    ./preview-free.sh cleanup > /dev/null 2>&1

    if [ $build_result -eq 0 ]; then
        print_success "Release build completed: $BUILD_DIR/${APP_NAME}_release"

        # Show binary size
        local size=$(ls -lh "$BUILD_DIR/${APP_NAME}_release" | awk '{print $5}')
        print_status "Binary size: $size"
    else
        print_error "Release build failed"
        return 1
    fi
}

# Function to create macOS app bundle
create_app_bundle() {
    print_status "Creating macOS app bundle..."
    setup_build_dir

    local bundle_dir="$BUILD_DIR/GPX POI Tool.app"
    local contents_dir="$bundle_dir/Contents"
    local macos_dir="$contents_dir/MacOS"
    local resources_dir="$contents_dir/Resources"

    # Create bundle structure
    mkdir -p "$macos_dir" "$resources_dir"

    # Build the executable if it doesn't exist
    if [ ! -f "$BUILD_DIR/${APP_NAME}_release" ]; then
        build_release
    fi

    # Copy executable
    cp "$BUILD_DIR/${APP_NAME}_release" "$macos_dir/GPX POI Tool"

    # Create Info.plist for bundle
    cat > "$contents_dir/Info.plist" << 'EOF'
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
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
EOF

    print_success "App bundle created: $bundle_dir"
    print_status "You can run: open '$bundle_dir'"
}

# Function to run the application
run_app() {
    # Build if executable doesn't exist
    if [ ! -f "$BUILD_DIR/${APP_NAME}_debug" ]; then
        build_debug
    fi

    print_status "Running GPX POI Tool..."
    "$BUILD_DIR/${APP_NAME}_debug"
}

# Main script logic
cd "$PROJECT_ROOT"

case "${1:-build}" in
    "build")
        lint_swift && build_debug
        ;;
    "clean")
        clean_build
        ;;
    "test")
        lint_swift && test_compilation
        ;;
    "run")
        lint_swift && build_debug && run_app
        ;;
    "lint")
        lint_swift
        ;;
    "debug")
        lint_swift && build_debug
        ;;
    "release")
        lint_swift && build_release
        ;;
    "bundle")
        lint_swift && create_app_bundle
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac
