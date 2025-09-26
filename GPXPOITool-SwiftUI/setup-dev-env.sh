#!/bin/bash

# Development Environment Setup for GPX POI Tool
# Enhanced with Command Line Tools support

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_ROOT="/Users/espen/git/gpx-poi-tool/GPXPOITool-SwiftUI"

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🛠️  GPX POI Tool - Development Environment Setup"
echo "================================================"

cd "$PROJECT_ROOT"

# Check system requirements
print_status "Checking system requirements..."

# Check macOS version
macos_version=$(sw_vers -productVersion)
print_status "macOS Version: $macos_version"

# Check Swift version
swift_version=$(swift --version | head -1)
print_status "Swift: $swift_version"

# Check Command Line Tools
if xcode-select --print-path > /dev/null 2>&1; then
    dev_tools_path=$(xcode-select --print-path)
    print_success "Command Line Tools: $dev_tools_path"
else
    print_error "Command Line Tools not found"
    echo "Please install with: xcode-select --install"
    exit 1
fi

# Check Git
if command -v git > /dev/null 2>&1; then
    git_version=$(git --version)
    print_success "Git: $git_version"
else
    print_warning "Git not found in PATH"
fi

# Create development directories
print_status "Setting up development directories..."
mkdir -p build
mkdir -p logs
mkdir -p temp

# Create .gitignore if it doesn't exist
if [ ! -f .gitignore ]; then
    print_status "Creating .gitignore..."
    cat > .gitignore << 'EOF'
# Build artifacts
build/
*.o
*.a
*.dylib
GPXPOIToolNative
GPXPOITool_debug
GPXPOITool_release

# Logs
logs/
*.log

# Temporary files
temp/
.DS_Store

# Xcode user-specific files
*.xcuserstate
*.xcuserdatad/
DerivedData/

# Swift Package Manager
.swiftpm/
Package.resolved
EOF
    print_success "Created .gitignore"
fi

# Create development configuration
print_status "Creating development configuration..."
cat > dev-config.json << EOF
{
    "project": {
        "name": "GPX POI Tool",
        "version": "1.0.0",
        "swift_version": "6.2",
        "min_macos_version": "14.0"
    },
    "build": {
        "debug_flags": ["-g", "-Onone"],
        "release_flags": ["-O"],
        "frameworks": [
            "Foundation",
            "SwiftUI",
            "CoreLocation",
            "MapKit"
        ]
    },
    "paths": {
        "source": "GPX POI Tool",
        "build": "build",
        "logs": "logs"
    }
}
EOF

# Create quick test script
print_status "Creating quick test script..."
cat > quick-test.sh << 'EOF'
#!/bin/bash

# Quick test runner for GPX POI Tool

cd "$(dirname "$0")"

echo "🧪 Running Quick Tests"
echo "===================="

# Test 1: Swift syntax check
echo "1️⃣  Testing Swift syntax..."
cd "GPX POI Tool"
if swiftc -parse Models/*.swift Views/*.swift Services/*.swift *.swift > /dev/null 2>&1; then
    echo "   ✅ All files have valid Swift syntax"
else
    echo "   ❌ Syntax errors found"
    exit 1
fi

# Test 2: Check for required services
echo "2️⃣  Checking native services..."
if [ -f "Services/ElevationService.swift" ]; then
    echo "   ✅ ElevationService.swift found"
else
    echo "   ❌ ElevationService.swift missing"
fi

if [ -f "Services/KMLExporter.swift" ]; then
    echo "   ✅ KMLExporter.swift found"
else
    echo "   ❌ KMLExporter.swift missing"
fi

# Test 3: Check imports and dependencies
echo "3️⃣  Checking imports..."
if grep -q "ElevationService" Services/GPXProcessor.swift > /dev/null 2>&1; then
    echo "   ✅ ElevationService imported in GPXProcessor"
else
    echo "   ⚠️  ElevationService not found in GPXProcessor"
fi

if grep -q "KMLExporter" Services/GPXProcessor.swift > /dev/null 2>&1; then
    echo "   ✅ KMLExporter imported in GPXProcessor"
else
    echo "   ⚠️  KMLExporter not found in GPXProcessor"
fi

echo ""
echo "🎉 Quick tests completed!"
EOF

chmod +x quick-test.sh

# Create file watcher script (basic version)
print_status "Creating file watcher script..."
cat > watch-and-build.sh << 'EOF'
#!/bin/bash

# Simple file watcher for GPX POI Tool
# Watches for Swift file changes and rebuilds

echo "👀 Watching Swift files for changes..."
echo "Press Ctrl+C to stop"

LAST_BUILD=0

while true; do
    # Get latest modification time of any Swift file
    LATEST=$(find "GPX POI Tool" -name "*.swift" -exec stat -f %m {} \; | sort -n | tail -1)

    if [ "$LATEST" -gt "$LAST_BUILD" ]; then
        echo "📝 Changes detected, rebuilding..."
        if ./build.sh debug > logs/watch-build.log 2>&1; then
            echo "✅ Build successful $(date)"
        else
            echo "❌ Build failed $(date)"
            echo "Check logs/watch-build.log for details"
        fi
        LAST_BUILD=$LATEST
    fi

    sleep 2
done
EOF

chmod +x watch-and-build.sh

# Create performance profiler script
print_status "Creating performance profiler..."
cat > profile.sh << 'EOF'
#!/bin/bash

# Performance profiler for GPX POI Tool

if [ ! -f "build/GPXPOITool_release" ]; then
    echo "Building release version first..."
    ./build.sh release
fi

echo "📊 Performance Profiling"
echo "======================="

# Binary size analysis
echo "Binary Size:"
ls -lh build/GPXPOITool_release | awk '{print "  Release: " $5}'
if [ -f "build/GPXPOITool_debug" ]; then
    ls -lh build/GPXPOITool_debug | awk '{print "  Debug: " $5}'
fi

# Startup time test (basic)
echo ""
echo "Startup Test:"
echo "  Testing application launch time..."
time timeout 5s ./build/GPXPOITool_release > /dev/null 2>&1 || true

# Memory usage (if available)
echo ""
echo "Memory Analysis:"
echo "  Use Activity Monitor or 'top' to monitor runtime memory usage"
EOF

chmod +x profile.sh

# Test the enhanced build system
print_status "Testing enhanced build system..."
./build.sh test

print_success "Development environment setup complete!"
echo ""
echo "📋 Available Tools:"
echo "  ./build.sh [command]     - Enhanced build system"
echo "  ./quick-test.sh          - Run quick validation tests"
echo "  ./watch-and-build.sh     - Watch files and auto-rebuild"
echo "  ./profile.sh             - Performance profiling"
echo ""
echo "📁 Directory Structure:"
echo "  build/                   - Build outputs"
echo "  logs/                    - Build and error logs"
echo "  temp/                    - Temporary files"
echo ""
echo "🚀 Quick Start:"
echo "  ./build.sh build         - Build debug version"
echo "  ./build.sh release       - Build optimized version"
echo "  ./build.sh bundle        - Create .app bundle"
echo "  ./build.sh run           - Build and run"
