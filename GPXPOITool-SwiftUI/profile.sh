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
