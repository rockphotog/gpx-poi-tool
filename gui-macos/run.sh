#!/bin/bash
# Run script for GPX POI Tool macOS GUI

# Navigate to the gui-macos directory
cd "$(dirname "$0")"

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
    echo "Installing dependencies..."
    source venv/bin/activate
    pip install -r requirements.txt
else
    echo "Using existing virtual environment..."
    source venv/bin/activate
fi

# Run the GUI application
echo "Starting GPX POI Viewer..."
python main.py