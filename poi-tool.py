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
import csv
import glob
import json
import math
import re
import sys
import time
import xml.etree.ElementTree as ET
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple
from urllib.parse import urljoin, urlparse

import requests

# Optional FIT file support
try:
    from fitparse import FitFile
    FIT_SUPPORT = True
except ImportError:
    FIT_SUPPORT = False


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


class SpatialGrid:
    """
    Grid-based spatial index for fast POI proximity searches.
    Reduces duplicate detection from O(n²) to approximately O(n).
    """

    def __init__(self, cell_size_meters: float = 1000):
        self.cell_size_meters = cell_size_meters
        # Convert meters to degrees (approximate)
        self.cell_size_degrees = cell_size_meters / 111320.0  # ~111.32km per degree
        self.grid: Dict[Tuple[int, int], List[int]] = defaultdict(list)
        self.pois: List[POI] = []

    def _get_grid_coords(self, lat: float, lon: float) -> Tuple[int, int]:
        """Convert lat/lon to grid coordinates."""
        grid_lat = int(lat / self.cell_size_degrees)
        grid_lon = int(lon / self.cell_size_degrees)
        return (grid_lat, grid_lon)

    def _get_neighbor_cells(self, grid_lat: int, grid_lon: int) -> List[Tuple[int, int]]:
        """Get all neighboring grid cells (including the center cell)."""
        neighbors = []
        for dlat in [-1, 0, 1]:
            for dlon in [-1, 0, 1]:
                neighbors.append((grid_lat + dlat, grid_lon + dlon))
        return neighbors

    def add_poi(self, poi: POI, index: int):
        """Add POI to spatial index."""
        grid_coords = self._get_grid_coords(poi.lat, poi.lon)
        self.grid[grid_coords].append(index)

        # Store POI reference
        if len(self.pois) <= index:
            self.pois.extend([None] * (index - len(self.pois) + 1))  # type: ignore
        self.pois[index] = poi

    def find_nearby_pois(self, poi: POI, max_distance_meters: float = 100) -> List[Tuple[int, float]]:
        """Find POIs within max_distance of the given POI."""
        grid_coords = self._get_grid_coords(poi.lat, poi.lon)
        neighbor_cells = self._get_neighbor_cells(*grid_coords)

        nearby = []
        for cell_coords in neighbor_cells:
            if cell_coords in self.grid:
                for poi_index in self.grid[cell_coords]:
                    if poi_index < len(self.pois) and self.pois[poi_index] is not None:
                        candidate_poi = self.pois[poi_index]
                        distance = poi.distance_to(candidate_poi)
                        if distance <= max_distance_meters:
                            nearby.append((poi_index, distance))

        return sorted(nearby, key=lambda x: x[1])  # Sort by distance


class GPXManager:
    """Manages GPX files and POI operations"""

    def __init__(self):
        self.namespaces = {
            'gpx': 'http://www.topografix.com/GPX/1/1'
        }
        self.fit_support = FIT_SUPPORT
        self.duplicate_threshold = 100.0  # meters

    def read_gpx_file(self, file_path: Path) -> List[POI]:
        """Read POIs from a GPX or FIT file"""
        # Detect file type and delegate to appropriate reader
        if file_path.suffix.lower() == '.fit':
            return self.read_fit_file(file_path)

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

    def read_fit_file(self, file_path: Path) -> List[POI]:
        """Read POIs from a Garmin FIT file"""
        if not self.fit_support:
            print(f"FIT file support not available. Install fitparse: pip install fitparse")
            return []

        try:
            fitfile = FitFile(str(file_path))
            pois = []

            # Extract waypoints
            for record in fitfile.get_messages('waypoint'):
                name = None
                lat = None
                lon = None

                for field in record:
                    if field.name == 'waypoint_name':
                        name = field.value
                    elif field.name == 'position_lat':
                        lat = field.value * (180.0 / 2**31) if field.value else None
                    elif field.name == 'position_long':
                        lon = field.value * (180.0 / 2**31) if field.value else None

                if lat is not None and lon is not None:
                    if not name:
                        name = f"Waypoint_{lat:.6f}_{lon:.6f}"

                    poi = POI(
                        lat=lat,
                        lon=lon,
                        name=name,
                        desc="Imported from FIT file"
                    )
                    pois.append(poi)

            # Extract course points
            for record in fitfile.get_messages('course_point'):
                name = None
                lat = None
                lon = None

                for field in record:
                    if field.name == 'name':
                        name = field.value
                    elif field.name == 'position_lat':
                        lat = field.value * (180.0 / 2**31) if field.value else None
                    elif field.name == 'position_long':
                        lon = field.value * (180.0 / 2**31) if field.value else None

                if lat is not None and lon is not None:
                    if not name:
                        name = f"Course_Point_{lat:.6f}_{lon:.6f}"

                    poi = POI(
                        lat=lat,
                        lon=lon,
                        name=name,
                        desc="Course point from FIT file"
                    )
                    pois.append(poi)

            return pois

        except Exception as e:
            print(f"Error reading FIT file {file_path}: {e}")
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
        """
        Optimized merge using spatial indexing - O(n+m) vs O(n*m) performance.
        """
        if not source_pois:
            return target_pois.copy()
        if not target_pois:
            return source_pois.copy()

        # Use optimized algorithm for large datasets
        if len(target_pois) * len(source_pois) > 10000:
            return self._merge_pois_optimized(target_pois, source_pois)

        # Use original algorithm for small datasets (overhead not worth it)
        return self._merge_pois_original(target_pois, source_pois)

    def _merge_pois_original(self, target_pois: List[POI], source_pois: List[POI]) -> List[POI]:
        """Original O(n*m) merge algorithm for small datasets."""
        result_pois = target_pois.copy()

        for source_poi in source_pois:
            duplicate_found = False
            for i, target_poi in enumerate(result_pois):
                if source_poi.is_duplicate(target_poi):
                    result_pois[i] = target_poi.merge_with(source_poi)
                    duplicate_found = True
                    break

            if not duplicate_found:
                result_pois.append(source_poi)

        return result_pois

    def _merge_pois_optimized(self, target_pois: List[POI], source_pois: List[POI]) -> List[POI]:
        """Optimized merge using spatial grid - O(n+m) average case."""
        # Create spatial index with target POIs
        grid = SpatialGrid(cell_size_meters=self.duplicate_threshold * 3)
        result_pois = target_pois.copy()

        # Index all target POIs
        for i, poi in enumerate(result_pois):
            grid.add_poi(poi, i)

        # Process source POIs
        for source_poi in source_pois:
            nearby = grid.find_nearby_pois(source_poi, self.duplicate_threshold)

            duplicate_found = False
            for nearby_index, distance in nearby:
                if nearby_index < len(result_pois):
                    target_poi = result_pois[nearby_index]
                    if source_poi.is_duplicate(target_poi):
                        result_pois[nearby_index] = target_poi.merge_with(source_poi)
                        duplicate_found = True
                        break

            if not duplicate_found:
                new_index = len(result_pois)
                result_pois.append(source_poi)
                grid.add_poi(source_poi, new_index)

        return result_pois

    def deduplicate_pois(self, pois: List[POI]) -> List[POI]:
        """
        Optimized deduplication using spatial indexing - O(n) vs O(n²) performance.
        """
        if not pois:
            return []
        if len(pois) == 1:
            return pois.copy()

        # Use optimized algorithm for large datasets
        if len(pois) > 500:
            return self._deduplicate_pois_optimized(pois)

        # Use original algorithm for small datasets
        return self._deduplicate_pois_original(pois)

    def _deduplicate_pois_original(self, pois: List[POI]) -> List[POI]:
        """Original O(n²) deduplication algorithm for small datasets."""
        result_pois = [pois[0]]

        for poi in pois[1:]:
            duplicate_found = False
            for i, result_poi in enumerate(result_pois):
                if poi.is_duplicate(result_poi):
                    result_pois[i] = result_poi.merge_with(poi)
                    duplicate_found = True
                    break

            if not duplicate_found:
                result_pois.append(poi)

        return result_pois

    def _deduplicate_pois_optimized(self, pois: List[POI]) -> List[POI]:
        """Optimized deduplication using spatial grid - O(n) average case."""
        grid = SpatialGrid(cell_size_meters=self.duplicate_threshold * 3)
        result_pois = []
        processed_indices: Set[int] = set()

        for i, poi in enumerate(pois):
            if i in processed_indices:
                continue

            # Find nearby POIs that might be duplicates
            nearby = grid.find_nearby_pois(poi, self.duplicate_threshold)

            # Check if any nearby POI is a duplicate in our results
            duplicate_found = False
            for nearby_index, distance in nearby:
                if nearby_index < len(result_pois):
                    result_poi = result_pois[nearby_index]
                    if poi.is_duplicate(result_poi):
                        result_pois[nearby_index] = result_poi.merge_with(poi)
                        duplicate_found = True
                        processed_indices.add(i)
                        break

            if not duplicate_found:
                # Add new unique POI
                result_index = len(result_pois)
                result_pois.append(poi)
                grid.add_poi(poi, result_index)
                processed_indices.add(i)

        return result_pois



    def garmin_optimize(self, pois: List[POI]) -> List[POI]:
        """Optimize POI data for Garmin devices"""
        optimized_pois = []

        for poi in pois:
            # Create optimized copy
            optimized_poi = POI(
                lat=poi.lat,
                lon=poi.lon,
                name=self._garmin_optimize_name(poi.name),
                desc=self._garmin_optimize_description(poi.desc),
                ele=poi.ele,
                link=poi.link
            )
            optimized_pois.append(optimized_poi)

        return optimized_pois

    def _garmin_optimize_name(self, name: str) -> str:
        """Optimize POI name for Garmin devices"""
        if not name:
            return name

        # Garmin devices typically work best with shorter names
        # Remove special characters that might cause issues
        optimized = re.sub(r'[^\w\s\-øæåØÆÅ]', '', name)

        # Limit to 30 characters for better Garmin compatibility
        if len(optimized) > 30:
            optimized = optimized[:27] + "..."

        return optimized.strip()

    def _garmin_optimize_description(self, desc: str) -> str:
        """Optimize POI description for Garmin devices"""
        if not desc:
            return desc

        # Garmin devices typically have limited description display
        # Limit to 100 characters
        if len(desc) > 100:
            desc = desc[:97] + "..."

        return desc.strip()

    def add_waypoint_symbols(self, pois: List[POI]) -> List[POI]:
        """Add Garmin-compatible symbols to waypoints based on POI type"""
        symbol_pois = []

        for poi in pois:
            symbol = self._determine_garmin_symbol(poi)
            # For now, we'll store the symbol in a special format in the description
            # In a full implementation, this would be added to GPX extensions
            enhanced_desc = poi.desc or ""
            if symbol:
                if enhanced_desc:
                    enhanced_desc += f" [Symbol: {symbol}]"
                else:
                    enhanced_desc = f"[Symbol: {symbol}]"

            symbol_poi = POI(
                lat=poi.lat,
                lon=poi.lon,
                name=poi.name,
                desc=enhanced_desc,
                ele=poi.ele,
                link=poi.link
            )
            symbol_pois.append(symbol_poi)

        return symbol_pois

    def _determine_garmin_symbol(self, poi: POI) -> str:
        """Determine appropriate Garmin symbol based on POI characteristics"""
        name_lower = poi.name.lower()
        desc_lower = (poi.desc or "").lower()

        # DNT cabins and mountain lodges
        if any(word in name_lower for word in ['hytta', 'bu', 'heim', 'stul', 'lodge']):
            return "Lodge"

        # Peaks and mountains
        if any(word in name_lower for word in ['peak', 'topp', 'tind', 'horn', 'nuten']):
            return "Summit"

        # Fishing spots
        if any(word in desc_lower for word in ['fishing', 'fisk']):
            return "Fishing Hot Spot Facility"

        # Beaches
        if any(word in name_lower for word in ['beach', 'strand']):
            return "Beach"

        # Viewpoints
        if any(word in desc_lower for word in ['view', 'utsikt', 'panoramic']):
            return "Scenic Area"

        # Default for cabins/shelters
        return "Campground"

    def lookup_elevations(self, pois: List[POI], verbose: bool = False) -> List[POI]:
        """Add elevation data using online elevation service"""
        if verbose:
            print("Looking up elevation data...")

        updated_pois = []
        batch_size = 10  # Process in batches to be respectful to the API

        for i in range(0, len(pois), batch_size):
            batch = pois[i:i+batch_size]
            batch_updated = self._lookup_elevation_batch(batch, verbose)
            updated_pois.extend(batch_updated)

            # Add delay between batches
            if i + batch_size < len(pois):
                time.sleep(1)

        return updated_pois

    def _lookup_elevation_batch(self, pois: List[POI], verbose: bool = False) -> List[POI]:
        """Lookup elevation for a batch of POIs"""
        updated_pois = []

        for poi in pois:
            if poi.ele is not None:
                # POI already has elevation data
                updated_pois.append(poi)
                continue

            try:
                elevation = self._fetch_elevation(poi.lat, poi.lon)
                if elevation is not None:
                    updated_poi = POI(
                        lat=poi.lat,
                        lon=poi.lon,
                        name=poi.name,
                        desc=poi.desc,
                        ele=elevation,
                        link=poi.link
                    )
                    updated_pois.append(updated_poi)
                    if verbose:
                        print(f"Added elevation {elevation}m for {poi.name}")
                else:
                    updated_pois.append(poi)
                    if verbose:
                        print(f"Could not fetch elevation for {poi.name}")
            except Exception as e:
                if verbose:
                    print(f"Error fetching elevation for {poi.name}: {e}")
                updated_pois.append(poi)

        return updated_pois

    def _fetch_elevation(self, lat: float, lon: float) -> Optional[float]:
        """Fetch elevation for coordinates using open elevation API"""
        try:
            # Using open-elevation.com API (free service)
            url = "https://api.open-elevation.com/api/v1/lookup"
            data = {
                "locations": [{"latitude": lat, "longitude": lon}]
            }

            response = requests.post(url, json=data, timeout=10)
            if response.status_code == 200:
                result = response.json()
                if result.get('results') and len(result['results']) > 0:
                    elevation = result['results'][0].get('elevation')
                    return float(elevation) if elevation is not None else None

            return None

        except Exception:
            return None

    def export_garmin_poi_csv(self, pois: List[POI], output_path: Path, verbose: bool = False):
        """Export POIs to Garmin-compatible CSV format for BaseCamp"""
        if verbose:
            print(f"Exporting {len(pois)} POIs to Garmin CSV format: {output_path}")

        with open(output_path, 'w', newline='', encoding='utf-8') as csvfile:
            # Garmin BaseCamp CSV format
            fieldnames = ['Name', 'Description', 'Symbol', 'Latitude', 'Longitude', 'Elevation']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

            writer.writeheader()

            for poi in pois:
                # Extract symbol from description if available
                symbol = "Waypoint"
                desc = poi.desc or ""

                symbol_match = re.search(r'\[Symbol: ([^\]]+)\]', desc)
                if symbol_match:
                    symbol = symbol_match.group(1)
                    # Remove symbol notation from description
                    desc = re.sub(r'\s*\[Symbol: [^\]]+\]', '', desc).strip()

                writer.writerow({
                    'Name': poi.name,
                    'Description': desc,
                    'Symbol': symbol,
                    'Latitude': poi.lat,
                    'Longitude': poi.lon,
                    'Elevation': poi.ele if poi.ele is not None else ''
                })

        if verbose:
            print(f"Successfully exported to {output_path}")

    def write_garmin_optimized_gpx(self, file_path: Path, pois: List[POI]):
        """Write GPX file optimized specifically for Garmin devices"""
        # Create root GPX element with Garmin-specific namespaces
        root = ET.Element('gpx')
        root.set('xmlns', 'http://www.topografix.com/GPX/1/1')
        root.set('xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance')
        root.set('xmlns:gpxx', 'http://www.garmin.com/xmlschemas/GpxExtensions/v3')
        root.set('xsi:schemaLocation', 'http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www.garmin.com/xmlschemas/GpxExtensionsv3.xsd')
        root.set('version', '1.1')
        root.set('creator', 'poi-tool-garmin-optimized')

        # Add metadata optimized for Garmin
        metadata = ET.SubElement(root, 'metadata')
        name_elem = ET.SubElement(metadata, 'name')
        name_elem.text = 'POI Collection'
        desc_elem = ET.SubElement(metadata, 'desc')
        desc_elem.text = f'Garmin-optimized POI collection with {len(pois)} waypoints'

        # Add POIs as waypoints with Garmin extensions
        for poi in pois:
            wpt = ET.SubElement(root, 'wpt')
            wpt.set('lat', f"{poi.lat:.8f}")  # Higher precision for Garmin
            wpt.set('lon', f"{poi.lon:.8f}")

            # Add name
            name_elem = ET.SubElement(wpt, 'name')
            name_elem.text = poi.name

            # Add description without symbol notation
            desc = poi.desc or ""
            desc = re.sub(r'\s*\[Symbol: [^\]]+\]', '', desc).strip()
            desc_elem = ET.SubElement(wpt, 'desc')
            desc_elem.text = desc

            # Add elevation if available
            if poi.ele is not None:
                ele_elem = ET.SubElement(wpt, 'ele')
                ele_elem.text = f"{poi.ele:.1f}"

            # Add link if available
            if poi.link:
                link_elem = ET.SubElement(wpt, 'link')
                link_elem.set('href', poi.link)

            # Add Garmin extensions for symbols
            extensions = ET.SubElement(wpt, 'extensions')
            gpxx_wpt = ET.SubElement(extensions, 'gpxx:WaypointExtension')

            # Extract and add symbol
            symbol = "Waypoint"
            if poi.desc:
                symbol_match = re.search(r'\[Symbol: ([^\]]+)\]', poi.desc)
                if symbol_match:
                    symbol = symbol_match.group(1)

            gpxx_symbol = ET.SubElement(gpxx_wpt, 'gpxx:DisplayMode')
            gpxx_symbol.text = "SymbolAndName"

        # Write to file with proper formatting
        self._write_formatted_xml(root, file_path)

    def export_to_kml(self, pois: List[POI], output_path: Path, verbose: bool = False):
        """Export POIs to KML format for Google Earth"""
        if verbose:
            print(f"Exporting {len(pois)} POIs to KML format: {output_path}")

        # Create KML root element
        kml = ET.Element('kml')
        kml.set('xmlns', 'http://www.opengis.net/kml/2.2')

        # Create Document element
        document = ET.SubElement(kml, 'Document')

        # Add document metadata
        name_elem = ET.SubElement(document, 'name')
        name_elem.text = 'GPX POI Collection'

        desc_elem = ET.SubElement(document, 'description')
        desc_elem.text = f'Converted from GPX format. Contains {len(pois)} Points of Interest.'

        # Add styles for different POI types
        self._add_kml_styles(document)

        # Group POIs by type for better organization
        poi_groups = self._group_pois_by_type(pois)

        for group_name, group_pois in poi_groups.items():
            # Create folder for each POI type
            folder = ET.SubElement(document, 'Folder')
            folder_name = ET.SubElement(folder, 'name')
            folder_name.text = group_name

            folder_desc = ET.SubElement(folder, 'description')
            folder_desc.text = f'{len(group_pois)} {group_name.lower()}'

            # Add POIs to the folder
            for poi in group_pois:
                placemark = ET.SubElement(folder, 'Placemark')

                # POI name
                poi_name = ET.SubElement(placemark, 'name')
                poi_name.text = poi.name

                # POI description with rich content
                poi_desc = ET.SubElement(placemark, 'description')
                poi_desc.text = self._create_kml_description(poi)

                # Style reference
                style_url = ET.SubElement(placemark, 'styleUrl')
                style_url.text = f"#{self._get_kml_style_id(poi)}"

                # Point coordinates
                point = ET.SubElement(placemark, 'Point')

                # Add altitude mode for better 3D display
                altitude_mode = ET.SubElement(point, 'altitudeMode')
                altitude_mode.text = 'clampToGround'

                # Coordinates (longitude, latitude, altitude)
                coordinates = ET.SubElement(point, 'coordinates')
                if poi.ele is not None:
                    coordinates.text = f"{poi.lon},{poi.lat},{poi.ele}"
                else:
                    coordinates.text = f"{poi.lon},{poi.lat},0"

        # Write KML file
        self._write_kml_file(kml, output_path)

        if verbose:
            print(f"Successfully exported to {output_path}")
            print(f"Organized into {len(poi_groups)} categories:")
            for group_name, group_pois in poi_groups.items():
                print(f"  - {group_name}: {len(group_pois)} POIs")

    def _add_kml_styles(self, document: ET.Element):
        """Add KML styles for different POI types"""
        styles = {
            'lodge_style': {
                'color': 'ff0000ff',  # Red
                'icon': 'http://maps.google.com/mapfiles/kml/shapes/lodging.png',
                'scale': '1.0'
            },
            'summit_style': {
                'color': 'ff00ff00',  # Green
                'icon': 'http://maps.google.com/mapfiles/kml/shapes/triangle.png',
                'scale': '1.2'
            },
            'fishing_style': {
                'color': 'ffff0000',  # Blue
                'icon': 'http://maps.google.com/mapfiles/kml/shapes/fishing.png',
                'scale': '1.0'
            },
            'beach_style': {
                'color': 'ff00ffff',  # Yellow
                'icon': 'http://maps.google.com/mapfiles/kml/shapes/beach.png',
                'scale': '1.0'
            },
            'scenic_style': {
                'color': 'ffff00ff',  # Magenta
                'icon': 'http://maps.google.com/mapfiles/kml/shapes/camera.png',
                'scale': '1.0'
            },
            'default_style': {
                'color': 'ffffffff',  # White
                'icon': 'http://maps.google.com/mapfiles/kml/pushpin/wht-pushpin.png',
                'scale': '1.0'
            }
        }

        for style_id, style_props in styles.items():
            style = ET.SubElement(document, 'Style')
            style.set('id', style_id)

            icon_style = ET.SubElement(style, 'IconStyle')

            color_elem = ET.SubElement(icon_style, 'color')
            color_elem.text = style_props['color']

            scale_elem = ET.SubElement(icon_style, 'scale')
            scale_elem.text = style_props['scale']

            icon_elem = ET.SubElement(icon_style, 'Icon')
            href_elem = ET.SubElement(icon_elem, 'href')
            href_elem.text = style_props['icon']

    def _group_pois_by_type(self, pois: List[POI]) -> Dict[str, List[POI]]:
        """Group POIs by type for better organization in KML"""
        groups = {
            'DNT Cabins & Lodges': [],
            'Mountain Peaks': [],
            'Fishing Spots': [],
            'Beaches': [],
            'Scenic Areas': [],
            'Other POIs': []
        }

        for poi in pois:
            name_lower = poi.name.lower()
            desc_lower = (poi.desc or "").lower()

            if any(word in name_lower for word in ['hytta', 'bu', 'heim', 'stul', 'lodge', 'cabin']):
                groups['DNT Cabins & Lodges'].append(poi)
            elif any(word in name_lower for word in ['peak', 'topp', 'tind', 'horn', 'nuten']):
                groups['Mountain Peaks'].append(poi)
            elif any(word in desc_lower for word in ['fishing', 'fisk']):
                groups['Fishing Spots'].append(poi)
            elif any(word in name_lower for word in ['beach', 'strand']):
                groups['Beaches'].append(poi)
            elif any(word in desc_lower for word in ['view', 'utsikt', 'panoramic', 'scenic']):
                groups['Scenic Areas'].append(poi)
            else:
                groups['Other POIs'].append(poi)

        # Remove empty groups
        return {name: pois for name, pois in groups.items() if pois}

    def _create_kml_description(self, poi: POI) -> str:
        """Create rich HTML description for KML placemark"""
        html_parts = []

        # Basic description
        if poi.desc:
            html_parts.append(f"<p><strong>Description:</strong><br/>{poi.desc}</p>")

        # Coordinates
        html_parts.append(f"<p><strong>Coordinates:</strong><br/>Lat: {poi.lat:.6f}, Lon: {poi.lon:.6f}</p>")

        # Elevation
        if poi.ele is not None:
            html_parts.append(f"<p><strong>Elevation:</strong> {poi.ele:.1f} meters</p>")

        # Link
        if poi.link:
            html_parts.append(f'<p><strong>More Info:</strong><br/><a href="{poi.link}" target="_blank">{poi.link}</a></p>')

        return "<div>" + "".join(html_parts) + "</div>"

    def _get_kml_style_id(self, poi: POI) -> str:
        """Get appropriate KML style ID for a POI"""
        name_lower = poi.name.lower()
        desc_lower = (poi.desc or "").lower()

        if any(word in name_lower for word in ['hytta', 'bu', 'heim', 'stul', 'lodge']):
            return 'lodge_style'
        elif any(word in name_lower for word in ['peak', 'topp', 'tind', 'horn', 'nuten']):
            return 'summit_style'
        elif any(word in desc_lower for word in ['fishing', 'fisk']):
            return 'fishing_style'
        elif any(word in name_lower for word in ['beach', 'strand']):
            return 'beach_style'
        elif any(word in desc_lower for word in ['view', 'utsikt', 'panoramic']):
            return 'scenic_style'
        else:
            return 'default_style'

    def _write_kml_file(self, kml_root: ET.Element, file_path: Path):
        """Write KML file with proper formatting"""
        # Add proper indentation
        self._indent_xml(kml_root)

        # Create tree and write to file
        tree = ET.ElementTree(kml_root)

        with open(file_path, 'wb') as f:
            f.write(b'<?xml version="1.0" encoding="UTF-8"?>\n')
            tree.write(f, encoding='UTF-8', xml_declaration=False)


def main():
    parser = argparse.ArgumentParser(
        description='GPX POI Management Tool for Garmin GPS devices',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Basic operations
  poi-tool -t master-poi-collection.gpx -a new-poi.gpx
  poi-tool -t master-poi-collection.gpx -a "*.gpx"
  poi-tool -t master-poi-collection.gpx --dedupe

  # Enhanced features
  poi-tool -t master-poi-collection.gpx --elevation-lookup
  poi-tool -t master-poi-collection.gpx --add-waypoint-symbols
  poi-tool -t master-poi-collection.gpx --garmin-optimize
  poi-tool -t master-poi-collection.gpx --export-garmin-poi output.csv
  poi-tool -t master-poi-collection.gpx --export-kml output.kml

  # Combined operations
  poi-tool -t master-poi-collection.gpx --elevation-lookup --add-waypoint-symbols --garmin-optimize
  poi-tool -t master-poi-collection.gpx --export-kml google-earth.kml --export-garmin-poi garmin.csv
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
        help='GPX or FIT file(s) or pattern to add POIs from (e.g., "file.gpx", "route.fit", or "*.gpx")'
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



    parser.add_argument(
        '--garmin-optimize',
        action='store_true',
        help='Optimize GPX file structure for Garmin devices'
    )

    parser.add_argument(
        '--add-waypoint-symbols',
        action='store_true',
        help='Add Garmin-compatible symbols/icons to waypoints'
    )

    parser.add_argument(
        '--elevation-lookup',
        action='store_true',
        help='Automatically add elevation data using online services'
    )

    parser.add_argument(
        '--export-garmin-poi',
        type=Path,
        help='Export collection to Garmin POI CSV format'
    )

    parser.add_argument(
        '--export-kml',
        type=Path,
        help='Export collection to KML format for Google Earth'
    )

    args = parser.parse_args()

    # Validate arguments
    if not any([args.add, args.dedupe, args.garmin_optimize,
                args.add_waypoint_symbols, args.elevation_lookup, args.export_garmin_poi, args.export_kml]):
        parser.error("At least one operation must be specified (--add, --dedupe, --garmin-optimize, --add-waypoint-symbols, --elevation-lookup, --export-garmin-poi, or --export-kml)")

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
                    if str(path_obj.resolve()) != target_path_str and path_obj.suffix.lower() in ['.gpx', '.fit']:
                        source_files.append(path_obj)
            else:
                # Direct file path
                path_obj = Path(pattern)
                # Don't add the target file to itself
                if str(path_obj.resolve()) != target_path_str:
                    source_files.append(path_obj)

        if not source_files:
            print("Error: No valid GPX or FIT source files found")
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

    # Apply additional processing operations
    current_pois = target_pois if not (args.add or args.dedupe) else (merged_pois if args.add else deduplicated_pois)

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

    # Handle --export-garmin-poi command
    if args.export_garmin_poi:
        print(f"Exporting to Garmin POI CSV format...")
        gpx_manager.export_garmin_poi_csv(current_pois, args.export_garmin_poi, args.verbose)
        print(f"Exported to {args.export_garmin_poi}")

    # Handle --export-kml command
    if args.export_kml:
        print(f"Exporting to KML format for Google Earth...")
        gpx_manager.export_to_kml(current_pois, args.export_kml, args.verbose)
        print(f"Exported to {args.export_kml}")

    # Save changes if any processing operations were performed
    if any([args.elevation_lookup, args.add_waypoint_symbols]) and not args.garmin_optimize:
        gpx_manager.write_gpx_file(args.target, current_pois)
        print(f"Updated {args.target} with processed data")


if __name__ == '__main__':
    main()
