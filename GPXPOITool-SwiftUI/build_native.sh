#!/bin/bash

echo "🚀 Building GPX POI Tool (Native Swift App)"
echo "==========================================="

cd "/Users/espen/git/gpx-poi-tool/GPXPOITool-SwiftUI"

echo "🔨 Compiling Swift application..."
swiftc -target arm64-apple-macos14.0 \
       -framework Foundation \
       -framework SwiftUI \
       -framework CoreLocation \
       -framework MapKit \
       -Xlinker -rpath \
       -Xlinker /usr/lib/swift \
       "GPX POI Tool/GPXPOIToolApp.swift" \
       "GPX POI Tool/ContentView.swift" \
       "GPX POI Tool/Models/POI.swift" \
       "GPX POI Tool/Services/GPXProcessor.swift" \
       "GPX POI Tool/Services/ElevationService.swift" \
       "GPX POI Tool/Services/KMLExporter.swift" \
       "GPX POI Tool/Views/MapView.swift" \
       "GPX POI Tool/Views/POIListView.swift" \
       -o "GPXPOIToolNative"

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful!"
    echo ""
    echo "🎯 Application built as: GPXPOIToolNative"
    echo ""
    echo "📱 To run the native app:"
    echo "   ./GPXPOIToolNative"
    echo ""
    echo "Note: For full macOS app bundle with proper sandboxing,"
    echo "      you'll need to open the project in Xcode."
    echo "      The current Xcode project issue will need to be"
    echo "      resolved by manually adding the files in Xcode UI."
else
    echo "❌ Compilation failed!"
    exit 1
fi
