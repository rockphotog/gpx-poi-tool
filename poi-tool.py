#!/usr/bin/env python3
"""
GPX POI Management Tool

A command-line tool for managing Points of Interest (POI) in GPX files for Garmin GPS devices.
Supports importing POIs from GPX files and merging duplicates.

Usage:
    poi-tool -t master-poi-collection.gpx -a new-single-poi.gpx
    poi-tool --target master-poi-collection.gpx --add new-single-poi.gpx
    poi-tool -t master-poi-collection.gpx --dedupe
"""

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass
import math
import glob


@dataclass
class POI:
    """Represents a Point of Interest from a GPX file"""
    lat: float
    lon: float
    name: str
    desc: str = ""
    ele: Optional[float] = None
    link: Optional[str] = None
    
    def distance_to(self, other: 'POI') -> float:
        """Calculate distance between two POIs using Haversine formula (in meters)"""
        R = 6371000  # Earth's radius in meters
        
        lat1_rad = math.radians(self.lat)
        lat2_rad = math.radians(other.lat)
        delta_lat = math.radians(other.lat - self.lat)
        delta_lon = math.radians(other.lon - self.lon)
        
        a = (math.sin(delta_lat/2) * math.sin(delta_lat/2) + 
             math.cos(lat1_rad) * math.cos(lat2_rad) * 
             math.sin(delta_lon/2) * math.sin(delta_lon/2))
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
        
        return R * c
    
    def is_duplicate(self, other: 'POI', distance_threshold: float = 50.0) -> bool:
        """Check if this POI is a duplicate of another POI"""
        # Check by name (exact match)
        if self.name.strip().lower() == other.name.strip().lower():
            return True
        
        # Check by distance (within threshold)
        if self.distance_to(other) <= distance_threshold:
            return True
            
        return False
    
    def merge_with(self, other: 'POI') -> 'POI':
        """Merge this POI with another, keeping the most complete information"""
        # Keep the longer/more detailed name and description
        name = self.name if len(self.name) >= len(other.name) else other.name
        
        # Handle None values for descriptions
        self_desc = self.desc or ""
        other_desc = other.desc or ""
        desc = self_desc if len(self_desc) >= len(other_desc) else other_desc
        
        # Use elevation if available
        ele = self.ele if self.ele is not None else other.ele
        
        # Use link if available
        link = self.link if self.link else other.link
        
        # Use coordinates from the POI with elevation data if available
        if self.ele is not None and other.ele is None:
            lat, lon = self.lat, self.lon
        elif other.ele is not None and self.ele is None:
            lat, lon = other.lat, other.lon
        else:
            # Average the coordinates
            lat = (self.lat + other.lat) / 2
            lon = (self.lon + other.lon) / 2
        
        return POI(lat=lat, lon=lon, name=name, desc=desc, ele=ele, link=link)


class GPXManager:
    """Manages GPX files and POI operations"""
    
    def __init__(self):
        self.namespaces = {
            'gpx': 'http://www.topografix.com/GPX/1/1'
        }
    
    def read_gpx_file(self, file_path: Path) -> List[POI]:
        """Read POIs from a GPX file"""
        try:
            tree = ET.parse(file_path)
            root = tree.getroot()
            
            pois = []
            # Find all waypoints
            for wpt in root.findall('.//gpx:wpt', self.namespaces):
                lat = float(wpt.get('lat'))
                lon = float(wpt.get('lon'))
                
                name_elem = wpt.find('gpx:name', self.namespaces)
                name = name_elem.text if name_elem is not None else f"POI_{lat}_{lon}"
                
                desc_elem = wpt.find('gpx:desc', self.namespaces)
                desc = desc_elem.text if desc_elem is not None else ""
                
                ele_elem = wpt.find('gpx:ele', self.namespaces)
                ele = float(ele_elem.text) if ele_elem is not None else None
                
                link_elem = wpt.find('gpx:link', self.namespaces)
                link = link_elem.get('href') if link_elem is not None else None
                
                poi = POI(lat=lat, lon=lon, name=name, desc=desc, ele=ele, link=link)
                pois.append(poi)
            
            return pois
            
        except ET.ParseError as e:
            print(f"Error parsing GPX file {file_path}: {e}")
            return []
        except FileNotFoundError:
            print(f"GPX file not found: {file_path}")
            return []
        except Exception as e:
            print(f"Error reading GPX file {file_path}: {e}")
            return []
    
    def write_gpx_file(self, file_path: Path, pois: List[POI]):
        """Write POIs to a GPX file with proper formatting"""
        # Create root GPX element with namespaces
        root = ET.Element('gpx')
        root.set('xmlns', 'http://www.topografix.com/GPX/1/1')
        root.set('xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance')
        root.set('xsi:schemaLocation', 'http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd')
        root.set('version', '1.1')
        root.set('creator', 'poi-tool')
        
        # Add metadata
        metadata = ET.SubElement(root, 'metadata')
        
        # Add POIs as waypoints
        for poi in pois:
            wpt = ET.SubElement(root, 'wpt')
            wpt.set('lat', str(poi.lat))
            wpt.set('lon', str(poi.lon))
            
            # Add name
            name_elem = ET.SubElement(wpt, 'name')
            name_elem.text = poi.name
            
            # Add description
            desc_elem = ET.SubElement(wpt, 'desc')
            desc_elem.text = poi.desc or ""
            
            # Add elevation if available
            if poi.ele is not None:
                ele_elem = ET.SubElement(wpt, 'ele')
                ele_elem.text = str(poi.ele)
            
            # Add link if available
            if poi.link:
                link_elem = ET.SubElement(wpt, 'link')
                link_elem.set('href', poi.link)
        
        # Write to file with proper formatting
        self._write_formatted_xml(root, file_path)
    
    def _write_formatted_xml(self, root: ET.Element, file_path: Path):
        """Write XML with proper indentation"""
        self._indent_xml(root)
        tree = ET.ElementTree(root)
        
        with open(file_path, 'wb') as f:
            f.write(b'<?xml version="1.0" encoding="UTF-8"?>\n')
            tree.write(f, encoding='UTF-8', xml_declaration=False)
    
    def _indent_xml(self, elem: ET.Element, level: int = 0):
        """Add proper indentation to XML elements"""
        i = "\n" + level * "    "
        if len(elem):
            if not elem.text or not elem.text.strip():
                elem.text = i + "    "
            if not elem.tail or not elem.tail.strip():
                elem.tail = i
            for child in elem:
                self._indent_xml(child, level + 1)
            if not child.tail or not child.tail.strip():
                child.tail = i
        else:
            if level and (not elem.tail or not elem.tail.strip()):
                elem.tail = i
    
    def merge_pois(self, target_pois: List[POI], source_pois: List[POI]) -> List[POI]:
        """Merge source POIs into target POIs, handling duplicates"""
        result_pois = target_pois.copy()
        
        for source_poi in source_pois:
            # Check if this POI is a duplicate of any existing POI
            duplicate_found = False
            for i, target_poi in enumerate(result_pois):
                if source_poi.is_duplicate(target_poi):
                    # Merge the POIs
                    result_pois[i] = target_poi.merge_with(source_poi)
                    duplicate_found = True
                    break
            
            # If no duplicate found, add the new POI
            if not duplicate_found:
                result_pois.append(source_poi)
        
        return result_pois
    
    def deduplicate_pois(self, pois: List[POI]) -> List[POI]:
        """Remove duplicates from a list of POIs"""
        if not pois:
            return []
        
        result_pois = [pois[0]]  # Start with first POI
        
        for poi in pois[1:]:
            # Check if this POI is a duplicate of any existing POI in result
            duplicate_found = False
            for i, result_poi in enumerate(result_pois):
                if poi.is_duplicate(result_poi):
                    # Merge the POIs
                    result_pois[i] = result_poi.merge_with(poi)
                    duplicate_found = True
                    break
            
            # If no duplicate found, add the POI
            if not duplicate_found:
                result_pois.append(poi)
        
        return result_pois


def main():
    parser = argparse.ArgumentParser(
        description='GPX POI Management Tool for Garmin GPS devices',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  poi-tool -t master-poi-collection.gpx -a new-poi.gpx
  poi-tool -t master-poi-collection.gpx -a "*.gpx"
  poi-tool -t master-poi-collection.gpx -a file1.gpx file2.gpx file3.gpx
  poi-tool --target master-poi-collection.gpx --add new-poi.gpx
  poi-tool -t master-poi-collection.gpx --dedupe
        '''
    )
    
    parser.add_argument(
        '-t', '--target',
        type=Path,
        required=True,
        help='Target GPX file (master POI collection)'
    )
    
    parser.add_argument(
        '-a', '--add',
        nargs='+',
        help='GPX file(s) or pattern to add POIs from (e.g., "file.gpx" or "*.gpx")'
    )
    
    parser.add_argument(
        '--dedupe',
        action='store_true',
        help='Remove duplicates from the target file'
    )
    
    parser.add_argument(
        '--distance-threshold',
        type=float,
        default=50.0,
        help='Distance threshold in meters for duplicate detection (default: 50.0)'
    )
    
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Enable verbose output'
    )
    
    args = parser.parse_args()
    
    # Validate arguments
    if not args.add and not args.dedupe:
        parser.error("Either --add or --dedupe must be specified")
    
    gpx_manager = GPXManager()
    
    # Read target file (create empty if it doesn't exist)
    target_pois = []
    if args.target.exists():
        target_pois = gpx_manager.read_gpx_file(args.target)
        if args.verbose:
            print(f"Loaded {len(target_pois)} POIs from target file: {args.target}")
    else:
        if args.verbose:
            print(f"Target file {args.target} doesn't exist, will be created")
    
    # Handle --add command
    if args.add:
        # Expand patterns and collect all source files
        source_files = []
        target_path_str = str(args.target.resolve())
        
        for pattern in args.add:
            # Check if it's a glob pattern or a direct file
            if '*' in pattern or '?' in pattern or '[' in pattern:
                # Use glob to expand the pattern
                expanded_files = glob.glob(pattern)
                for file_path in expanded_files:
                    path_obj = Path(file_path)
                    # Don't add the target file to itself
                    if str(path_obj.resolve()) != target_path_str and path_obj.suffix.lower() == '.gpx':
                        source_files.append(path_obj)
            else:
                # Direct file path
                path_obj = Path(pattern)
                # Don't add the target file to itself
                if str(path_obj.resolve()) != target_path_str:
                    source_files.append(path_obj)
        
        if not source_files:
            print("Error: No valid GPX source files found")
            sys.exit(1)
        
        # Remove duplicates from source files list
        source_files = list(set(source_files))
        
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
        
        # Merge all POIs
        merged_pois = gpx_manager.merge_pois(target_pois, all_source_pois)
        
        added_count = len(merged_pois) - len(target_pois)
        merged_count = total_loaded - added_count
        
        print(f"Processed {len(source_files)} source files")
        print(f"Added {added_count} new POIs, merged {merged_count} duplicates")
        print(f"Total POIs in collection: {len(merged_pois)}")
        
        # Write back to target file
        gpx_manager.write_gpx_file(args.target, merged_pois)
        print(f"Updated {args.target}")
    
    # Handle --dedupe command
    elif args.dedupe:
        original_count = len(target_pois)
        deduplicated_pois = gpx_manager.deduplicate_pois(target_pois)
        duplicates_removed = original_count - len(deduplicated_pois)
        
        print(f"Removed {duplicates_removed} duplicate POIs")
        print(f"Total POIs in collection: {len(deduplicated_pois)}")
        
        # Write back to target file
        gpx_manager.write_gpx_file(args.target, deduplicated_pois)
        print(f"Updated {args.target}")


if __name__ == '__main__':
    main()