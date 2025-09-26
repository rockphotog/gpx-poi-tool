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
