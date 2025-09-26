#!/usr/bin/env python3
"""
GPX POI Management Tool - Modular Version

A high-performance command-line tool for managing Points of Interest (POI) in GPX files.
Supports importing POIs from GPX/FIT files, deduplication, elevation lookup, and export.

Features:
- O(n) spatial indexing for fast deduplication (vs O(n²) naive approach)
- Garmin device optimization
- Multiple export formats (GPX, KML, CSV)
- Elevation data lookup
- FIT file support

Usage:
    poi-tool-v2 -t master-poi-collection.gpx -a new-single-poi.gpx
    poi-tool-v2 --target master-poi-collection.gpx --dedupe --verbose
    poi-tool-v2 -t master.gpx --elevation-lookup --export-kml output.kml
"""

import argparse
import glob
import sys
from pathlib import Path

# Import our modular components
try:
    from poi_formats import ExportHandler
    from poi_manager import GPXManager
except ImportError as e:
    print(f"Error importing modules: {e}")
    print("Make sure poi_core.py, poi_formats.py, and poi_manager.py are in the same directory")
    sys.exit(1)


def create_argument_parser() -> argparse.ArgumentParser:
    """Create and configure the argument parser."""
    parser = argparse.ArgumentParser(
        description='Manage Points of Interest (POI) in GPX files with high performance',
        epilog='''
Examples:
  %(prog)s -t master.gpx -a new-pois.gpx          # Add POIs from new file
  %(prog)s -t master.gpx --dedupe                 # Remove duplicates
  %(prog)s -t master.gpx --elevation-lookup       # Add elevation data
  %(prog)s -t master.gpx --garmin-optimize        # Optimize for Garmin
  %(prog)s -t master.gpx --export-kml out.kml     # Export to Google Earth
        ''',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    # Required arguments
    parser.add_argument('-t', '--target',
                       type=Path,
                       required=True,
                       help='Target GPX file (will be created if it doesn\'t exist)')

    # Action arguments
    parser.add_argument('-a', '--add',
                       type=str,
                       help='Add POIs from specified file(s) (supports glob patterns)')

    parser.add_argument('--dedupe',
                       action='store_true',
                       help='Remove duplicate POIs from target file')

    parser.add_argument('--sync-utno',
                       action='store_true',
                       help='Sync with ut.no cabin database')

    # Enhancement arguments
    parser.add_argument('--elevation-lookup',
                       action='store_true',
                       help='Look up elevation data for POIs without elevation')

    parser.add_argument('--add-waypoint-symbols',
                       action='store_true',
                       help='Add Garmin waypoint symbols based on POI names')

    parser.add_argument('--garmin-optimize',
                       action='store_true',
                       help='Optimize POI names and create Garmin-compatible file')

    # Export arguments
    parser.add_argument('--export-garmin-poi',
                       type=Path,
                       help='Export to Garmin POI CSV format')

    parser.add_argument('--export-kml',
                       type=Path,
                       help='Export to KML format for Google Earth')

    # Options
    parser.add_argument('-v', '--verbose',
                       action='store_true',
                       help='Enable verbose output')

    return parser


def validate_arguments(args) -> bool:
    """Validate command line arguments."""
    # Must have at least one action
    actions = [args.add, args.dedupe, args.sync_utno, args.elevation_lookup,
               args.add_waypoint_symbols, args.garmin_optimize,
               args.export_garmin_poi, args.export_kml]

    if not any(actions):
        print("Error: Must specify at least one action (--add, --dedupe, etc.)")
        return False

    return True


def main():
    """Main application entry point."""
    parser = create_argument_parser()
    args = parser.parse_args()

    if not validate_arguments(args):
        parser.print_help()
        return 1

    # Initialize GPX manager
    gpx_manager = GPXManager()

    # Load or create target file
    if args.target.exists():
        target_pois = gpx_manager.read_gpx_file(args.target)
        if args.verbose:
            print(f"Loaded {len(target_pois)} POIs from target file: {args.target}")
    else:
        target_pois = []
        if args.verbose:
            print(f"Target file {args.target} not found, starting with empty collection")

    # Handle --add command
    if args.add:
        # Expand glob patterns
        source_files = []
        for pattern in args.add.split(','):
            pattern = pattern.strip()
            matches = glob.glob(pattern)
            if matches:
                source_files.extend([Path(f) for f in matches])
            else:
                # Try as direct file path
                file_path = Path(pattern)
                if file_path.exists():
                    source_files.append(file_path)
                else:
                    print(f"Warning: No files found matching pattern: {pattern}")

        if args.verbose:
            print(f"Processing {len(source_files)} source files:")
            for file_path in source_files:
                print(f"  - {file_path}")

        # Load POIs from all source files
        all_source_pois = []
        total_loaded = 0

        for source_file in source_files:
            if not source_file.exists():
                print(f"Warning: Source file {source_file} not found, skipping")
                continue

            file_pois = gpx_manager.read_gpx_file(source_file)
            all_source_pois.extend(file_pois)
            total_loaded += len(file_pois)

            if args.verbose:
                print(f"Loaded {len(file_pois)} POIs from {source_file}")

        if args.verbose:
            print(f"Total loaded: {total_loaded} POIs from {len(source_files)} files")

        # Merge all POIs using optimized algorithm
        merged_pois = gpx_manager.merge_pois(target_pois, all_source_pois)

        added_count = len(merged_pois) - len(target_pois)
        merged_count = total_loaded - added_count

        print(f"Processed {len(source_files)} source files")
        print(f"Added {added_count} new POIs, merged {merged_count} duplicates")
        print(f"Total POIs in collection: {len(merged_pois)}")

        # Write back to target file
        gpx_manager.write_gpx_file(args.target, merged_pois)
        print(f"Updated {args.target}")

        # Update current POIs for further processing
        target_pois = merged_pois

    # Handle --dedupe command
    if args.dedupe:
        original_count = len(target_pois)
        deduplicated_pois = gpx_manager.deduplicate_pois(target_pois)
        duplicates_removed = original_count - len(deduplicated_pois)

        print(f"Removed {duplicates_removed} duplicate POIs")
        print(f"Total POIs in collection: {len(deduplicated_pois)}")

        # Write back to target file
        gpx_manager.write_gpx_file(args.target, deduplicated_pois)
        print(f"Updated {args.target}")

        # Update current POIs for further processing
        target_pois = deduplicated_pois

    # Handle --sync-utno command
    if args.sync_utno:
        print("ut.no sync not yet implemented in modular version")

    # Apply enhancement operations
    current_pois = target_pois

    # Handle --elevation-lookup command
    if args.elevation_lookup:
        print("Looking up elevation data...")
        current_pois = gpx_manager.lookup_elevations(current_pois, args.verbose)
        print("Elevation lookup completed")

    # Handle --add-waypoint-symbols command
    if args.add_waypoint_symbols:
        print("Adding Garmin waypoint symbols...")
        current_pois = gpx_manager.add_waypoint_symbols(current_pois)
        print("Waypoint symbols added")

    # Handle --garmin-optimize command
    if args.garmin_optimize:
        print("Optimizing for Garmin devices...")
        current_pois = gpx_manager.garmin_optimize(current_pois)
        print("Garmin optimization completed")

        # Write optimized GPX file
        optimized_path = args.target.with_suffix('.garmin.gpx')
        gpx_manager.write_garmin_optimized_gpx(optimized_path, current_pois)
        print(f"Created Garmin-optimized file: {optimized_path}")

    # Handle export commands
    if args.export_garmin_poi:
        print(f"Exporting to Garmin POI CSV format...")
        gpx_manager.export_garmin_poi_csv(current_pois, args.export_garmin_poi, args.verbose)
        print(f"Exported to {args.export_garmin_poi}")

    if args.export_kml:
        print(f"Exporting to KML format for Google Earth...")
        gpx_manager.export_to_kml(current_pois, args.export_kml, args.verbose)
        print(f"Exported to {args.export_kml}")

    # Save changes if any processing operations were performed
    if any([args.elevation_lookup, args.add_waypoint_symbols]) and not args.garmin_optimize:
        gpx_manager.write_gpx_file(args.target, current_pois)
        print(f"Updated {args.target} with processed data")

    return 0


if __name__ == '__main__':
    try:
        exit_code = main()
        sys.exit(exit_code)
    except KeyboardInterrupt:
        print("\nOperation cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(1)
