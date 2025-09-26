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
