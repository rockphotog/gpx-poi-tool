# GPX POI Tool - macOS GUI

A modern interface for viewing and managing GPX files with Points of Interest (POIs). 

**Two interface options available:**
- 🖥️ **Native Desktop GUI** - Modern customtkinter interface (requires tkinter)
- 🌐 **Web-based Viewer** - Browser-based interface (works everywhere)

## Features

- 📁 **Open GPX Files** - Browse and load GPX files 
- 📊 **File Statistics** - View POI counts, elevation data, and file information
- 📋 **Organized Display** - View POIs in a sortable table with all key information
- 🎨 **Modern Interface** - Native macOS look and feel with dark/light mode support
- ⚡ **Fast Performance** - Optimized for smooth operation
- 🔄 **Automatic Fallback** - Uses web viewer if native GUI unavailable

## Installation

### Prerequisites

You need Python with tkinter support. The easiest way to get this on macOS is:

```bash
# Install Python with tkinter via Homebrew
brew install python-tk

# Or use pyenv to install a Python version with tkinter
pyenv install 3.11.0
pyenv local 3.11.0
```

### Setup

1. Navigate to the gui-macos directory:
```bash
cd gui-macos
```

2. Run the setup script (recommended):
```bash
./run.sh
```

Or manually:

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the application
python main.py
```

## Quick Start

**Option 1: Native Desktop GUI (if tkinter is available)**
```bash
./run.sh
```

**Option 2: Web-based Viewer (works anywhere)**
```bash
python3 web_viewer.py
```

The native GUI will automatically fall back to the web viewer if tkinter is not available.

## Usage

### Native Desktop GUI

1. **Launch**: `./run.sh`
2. **Open GPX file**: Click "📁 Open GPX File" button
3. **Browse**: Use native file dialog to select your GPX file
4. **View**: POIs appear in a sortable table with statistics

### Web-based Viewer

1. **Launch**: `python3 web_viewer.py` (opens browser automatically)
2. **Select file**: Use the file input to choose a GPX file
3. **View**: POIs display in a responsive web table
4. **Access**: Visit `http://localhost:8000` in any browser

## Troubleshooting

### "No module named '_tkinter'" Error

This means Python was installed without tkinter support. Solutions:

1. **Using Homebrew** (recommended):
   ```bash
   brew install python-tk
   ```

2. **Using pyenv**:
   ```bash
   pyenv install 3.11.0
   pyenv local 3.11.0
   ```

3. **Using conda**:
   ```bash
   conda create -n gpx-gui python=3.11 tk
   conda activate gpx-gui
   ```

### GUI doesn't appear

- Make sure you're running on a machine with a display
- Try running from Terminal.app (not SSH)
- Check that X11/XQuartz is installed if needed

## Development

The GUI is built with:
- **customtkinter** - Modern widgets and styling
- **tkinter** - Base GUI framework (built into Python)
- **poi_formats.py** - GPX file parsing (from parent directory)

### File Structure

```
gui-macos/
├── main.py           # Main GUI application
├── requirements.txt  # Python dependencies
├── run.sh           # Launch script
├── venv/            # Virtual environment
└── README.md        # This file
```

### Extending the GUI

The application is designed to be easily extensible. Key areas for enhancement:

- **POI Editing**: Add functionality to modify POI data
- **Export Options**: Export filtered or modified POI data
- **Map Integration**: Display POIs on an interactive map
- **Batch Processing**: Handle multiple GPX files
- **Advanced Filtering**: Filter POIs by elevation, name, etc.

## Integration with Main Tool

This GUI uses the same core modules as the command-line tool:
- Shares `poi_formats.py` for GPX parsing
- Compatible with all GPX files supported by the CLI tool
- Can be used alongside the CLI tool

## App Bundling (Future)

To create a standalone .app bundle:

```bash
# Install py2app
pip install py2app

# Create app bundle
python setup.py py2app
```

(Note: setup.py for py2app not yet created)