# GPX POI Management Tool

A Python command-line tool for managing Points of Interest (POI) in GPX files for Garmin GPS devices. This tool helps you build and maintain a master collection of POIs by importing from multiple GPX files and automatically handling duplicates.

## Features

- **Import POIs**: Add POIs from any GPX file to your master collection
- **Duplicate Detection**: Automatically detects duplicates based on:
  - Exact name matches (case-insensitive)
  - Geographic proximity (configurable distance threshold, default 50m)
- **Smart Merging**: When duplicates are found, combines the best information from both POIs:
  - Keeps the longer/more detailed name and description
  - Preserves elevation data when available
  - Merges coordinate data intelligently
- **Deduplication**: Remove duplicates from existing GPX files
- **Proper GPX Formatting**: Outputs properly formatted XML compatible with Garmin devices

## Installation

No installation required. Just ensure you have Python 3.6+ installed on your system.

## Usage

### Basic Commands

```bash
# Add POIs from a single source file to your master collection
python3 poi-tool.py -t master-poi-collection.gpx -a new-poi-file.gpx

# Add POIs from ALL GPX files in the current directory (excluding the target file)
python3 poi-tool.py -t master-poi-collection.gpx -a "*.gpx"

# Add POIs from multiple specific files
python3 poi-tool.py -t master-poi-collection.gpx -a file1.gpx file2.gpx file3.gpx

# Remove duplicates from your master collection
python3 poi-tool.py -t master-poi-collection.gpx --dedupe

# Verbose output to see what's happening
python3 poi-tool.py -t master-poi-collection.gpx -a new-poi-file.gpx -v
```

### Command Line Options

- `-t, --target TARGET`: Target GPX file (your master POI collection) - **Required**
- `-a, --add ADD [ADD ...]`: GPX file(s) or pattern to import POIs from
  - Single file: `-a cabin.gpx`
  - Multiple files: `-a cabin1.gpx cabin2.gpx cabin3.gpx`
  - Wildcard pattern: `-a "*.gpx"` (processes all GPX files, excluding the target)
- `--dedupe`: Remove duplicates from the target file
- `--distance-threshold DISTANCE`: Distance threshold in meters for duplicate detection (default: 50.0)
- `--sync-ut-no`: Sync POI information with ut.no database for DNT cabins
- `--elevation-lookup`: Automatically add elevation data using online services
- `--add-waypoint-symbols`: Add Garmin-compatible symbols/icons to waypoints
- `--garmin-optimize`: Optimize GPX file structure for Garmin devices
- `--export-garmin-poi FILE.csv`: Export to Garmin POI CSV format for BaseCamp
- `--export-kml FILE.kml`: Export to KML format for Google Earth
- `-v, --verbose`: Enable detailed output
- `-h, --help`: Show help message

### Examples

```bash
# Import POIs from a single hiking trail file
python3 poi-tool.py -t master-poi-collection.gpx -a hiking-trails.gpx

# Import ALL GPX files from current directory (wildcard pattern)
python3 poi-tool.py -t master-poi-collection.gpx -a "*.gpx"

# Import from multiple specific files
python3 poi-tool.py -t master-poi-collection.gpx -a cabins.gpx trails.gpx peaks.gpx

# Import with verbose output to see processing details
python3 poi-tool.py -t master-poi-collection.gpx -a "*.gpx" -v

# Clean up duplicates in your collection
python3 poi-tool.py -t master-poi-collection.gpx --dedupe

# Use custom distance threshold (100 meters instead of default 50)
python3 poi-tool.py -t master-poi-collection.gpx -a mountain-peaks.gpx --distance-threshold 100.0

# Export to different formats
python3 poi-tool.py -t master-poi-collection.gpx --export-kml google-earth.kml
python3 poi-tool.py -t master-poi-collection.gpx --export-garmin-poi garmin-basecamp.csv
```

## How Duplicate Detection Works

The tool identifies duplicates using two methods:

1. **Name Matching**: POIs with identical names (case-insensitive) are considered duplicates
2. **Geographic Proximity**: POIs within a specified distance (default 50 meters) are considered duplicates

When duplicates are found, the tool intelligently merges them by:
- Keeping the longer, more descriptive name
- Preserving the more detailed description
- Using elevation data when available
- Averaging coordinates or using the more precise location

## File Format

The tool works with standard GPX 1.1 format files and outputs properly formatted files compatible with:

- Garmin GPS devices
- Most mapping software
- GPX standard specifications
- Google Earth (via KML export)
- Garmin BaseCamp (via CSV export)

## Export Formats

### KML for Google Earth
The `--export-kml` feature creates KML files optimized for Google Earth with:
- **Organized folders** by POI type (DNT Cabins, Mountain Peaks, Fishing Spots, etc.)
- **Custom icons** and colors for different POI categories
- **Rich descriptions** with elevation data, coordinates, and clickable links
- **3D visualization** support with elevation data

### Garmin POI CSV
The `--export-garmin-poi` feature creates CSV files for Garmin BaseCamp with:
- **BaseCamp compatibility** for easy import
- **Symbol assignments** based on POI type
- **Complete metadata** including coordinates, elevation, and descriptions

## Example Workflow

```bash
# Start with an empty master collection
python3 poi-tool.py -t master-poi-collection.gpx -a cabin1.gpx

# Add more POIs from different sources
python3 poi-tool.py -t master-poi-collection.gpx -a cabin2.gpx
python3 poi-tool.py -t master-poi-collection.gpx -a hiking-waypoints.gpx
python3 poi-tool.py -t master-poi-collection.gpx -a fishing-spots.gpx

# Clean up any duplicates that might have been introduced
python3 poi-tool.py -t master-poi-collection.gpx --dedupe

# Your master-poi-collection.gpx now contains all unique POIs!
```