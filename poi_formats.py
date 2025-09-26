#!/usr/bin/env python3
"""
File format handlers for POI operations.

This module contains classes for reading and writing different POI file formats:
- GPX files
- FIT files
- CSV/KML export formats
"""

import csv
import glob
import json
import re
import time
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict, List, Optional
from urllib.parse import urljoin, urlparse

import requests

from poi_core import POI

# Optional FIT file support
try:
    from fitparse import FitFile
    FIT_SUPPORT = True
except ImportError:
    FIT_SUPPORT = False


class GPXFileHandler:
    """Handles reading and writing GPX files."""

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

            # Find all waypoints with proper namespace handling
            waypoints = root.findall('.//{http://www.topografix.com/GPX/1/1}wpt')
            if not waypoints:
                # Fallback: try without namespace for non-standard files
                waypoints = root.findall('.//wpt')

            for wpt in waypoints:
                lat = float(wpt.get('lat') or '0')
                lon = float(wpt.get('lon') or '0')

                # Extract name - try with and without namespace
                name_elem = wpt.find('name')
                if name_elem is None:
                    name_elem = wpt.find('.//{http://www.topografix.com/GPX/1/1}name')
                name = name_elem.text.strip() if name_elem is not None and name_elem.text else ""

                # Extract description - try with and without namespace
                desc_elem = wpt.find('desc')
                if desc_elem is None:
                    desc_elem = wpt.find('.//{http://www.topografix.com/GPX/1/1}desc')
                desc = desc_elem.text.strip() if desc_elem is not None and desc_elem.text else ""

                # Extract elevation - try with and without namespace
                ele_elem = wpt.find('ele')
                if ele_elem is None:
                    ele_elem = wpt.find('.//{http://www.topografix.com/GPX/1/1}ele')
                ele = float(ele_elem.text) if ele_elem is not None and ele_elem.text else None

                # Extract link - try with and without namespace
                link_elem = wpt.find('link')
                if link_elem is None:
                    link_elem = wpt.find('.//{http://www.topografix.com/GPX/1/1}link')
                link = link_elem.get('href') if link_elem is not None else None

                # Extract extensions - preserve original XML structure
                extensions_elem = wpt.find('extensions')
                if extensions_elem is None:
                    extensions_elem = wpt.find('.//{http://www.topografix.com/GPX/1/1}extensions')

                extensions = None
                if extensions_elem is not None:
                    # Convert extensions element to string to preserve exact structure
                    extensions = ET.tostring(extensions_elem, encoding='unicode', method='xml')

                poi = POI(lat=lat, lon=lon, name=name or "", desc=desc or "", ele=ele, link=link, extensions=extensions)
                pois.append(poi)

            return pois

        except ET.ParseError as e:
            print(f"Error parsing GPX file {file_path}: {e}")
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

            # Add original extensions if available
            if poi.extensions:
                try:
                    # Parse the extensions XML string and add it to the waypoint
                    extensions_element = ET.fromstring(poi.extensions)
                    wpt.append(extensions_element)
                except ET.ParseError:
                    # If parsing fails, skip the extensions to avoid corrupting the file
                    pass

        # Create tree and write to file
        tree = ET.ElementTree(root)
        ET.indent(tree, space="  ", level=0)  # Pretty formatting
        tree.write(file_path, encoding='utf-8', xml_declaration=True)

    def write_garmin_optimized_gpx(self, file_path: Path, pois: List[POI]):
        """Write GPX file optimized for Garmin devices"""
        # Create root GPX element with Garmin extensions
        root = ET.Element('gpx')
        root.set('xmlns', 'http://www.topografix.com/GPX/1/1')
        root.set('xmlns:gpxx', 'http://www.garmin.com/xmlschemas/GpxExtensions/v3')
        root.set('xmlns:wptx1', 'http://www.garmin.com/xmlschemas/WaypointExtension/v1')
        root.set('xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance')
        root.set('xsi:schemaLocation',
                 'http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd '
                 'http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www8.garmin.com/xmlschemas/GpxExtensionsv3.xsd')
        root.set('version', '1.1')
        root.set('creator', 'poi-tool-garmin')

        # Add metadata with Garmin-specific info
        metadata = ET.SubElement(root, 'metadata')
        name_elem = ET.SubElement(metadata, 'name')
        name_elem.text = 'Garmin POI Collection'

        # Add POIs with Garmin optimizations
        for poi in pois:
            wpt = ET.SubElement(root, 'wpt')
            wpt.set('lat', str(poi.lat))
            wpt.set('lon', str(poi.lon))

            # Garmin name optimization (20 char limit)
            garmin_name = poi.name[:20] if len(poi.name) > 20 else poi.name
            name_elem = ET.SubElement(wpt, 'name')
            name_elem.text = garmin_name

            # Add description
            desc_elem = ET.SubElement(wpt, 'desc')
            desc_elem.text = poi.desc or ""

            # Add elevation if available
            if poi.ele is not None:
                ele_elem = ET.SubElement(wpt, 'ele')
                ele_elem.text = str(poi.ele)

            # Add Garmin waypoint symbol
            sym_elem = ET.SubElement(wpt, 'sym')
            sym_elem.text = 'Flag, Blue'

            # Handle extensions - merge original with Garmin extensions
            extensions = ET.SubElement(wpt, 'extensions')

            # Add original extensions first if they exist
            if poi.extensions:
                try:
                    original_extensions = ET.fromstring(poi.extensions)
                    # Copy all child elements from original extensions
                    for child in original_extensions:
                        extensions.append(child)
                except ET.ParseError:
                    # If parsing fails, continue with just Garmin extensions
                    pass

            # Add Garmin extensions
            wptx1_ext = ET.SubElement(extensions, 'wptx1:WaypointExtension')

            # Add proximity alarm (100 meters)
            proximity = ET.SubElement(wptx1_ext, 'wptx1:Proximity')
            proximity.text = '100'

            # Add display mode
            display_mode = ET.SubElement(wptx1_ext, 'wptx1:DisplayMode')
            display_mode.text = 'SymbolAndName'

        # Write to file
        tree = ET.ElementTree(root)
        ET.indent(tree, space="  ", level=0)
        tree.write(file_path, encoding='utf-8', xml_declaration=True)


class FITFileHandler:
    """Handles reading FIT files (requires fitparse library)."""

    def __init__(self):
        self.fit_support = FIT_SUPPORT

    def read_fit_file(self, file_path: Path) -> List[POI]:
        """Read POIs from a FIT file"""
        if not self.fit_support:
            print(f"FIT file support not available. Install fitparse: pip install fitparse")
            return []

        try:
            fitfile = FitFile(str(file_path))
            pois = []

            # Parse course points from FIT file
            for record in fitfile.get_messages('course_point'):
                name = None
                lat = None
                lon = None

                for field in record.fields:
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


class ExportHandler:
    """Handles exporting POIs to various formats."""

    @staticmethod
    def export_to_csv(pois: List[POI], output_path: Path, format_type: str = 'garmin', verbose: bool = False):
        """Export POIs to CSV format"""
        if format_type == 'garmin':
            ExportHandler._export_garmin_poi_csv(pois, output_path, verbose)
        else:
            ExportHandler._export_standard_csv(pois, output_path, verbose)

    @staticmethod
    def _export_garmin_poi_csv(pois: List[POI], output_path: Path, verbose: bool = False):
        """Export POIs to Garmin POI CSV format"""
        with open(output_path, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.writer(csvfile)

            # Garmin POI CSV format: longitude,latitude,name
            for poi in pois:
                # Garmin expects longitude first, then latitude
                writer.writerow([poi.lon, poi.lat, poi.name])

                if verbose:
                    print(f"Exported: {poi.name} ({poi.lat:.6f}, {poi.lon:.6f})")

    @staticmethod
    def _export_standard_csv(pois: List[POI], output_path: Path, verbose: bool = False):
        """Export POIs to standard CSV format"""
        with open(output_path, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.writer(csvfile)

            # Write header
            writer.writerow(['name', 'latitude', 'longitude', 'elevation', 'description', 'link'])

            # Write POI data
            for poi in pois:
                writer.writerow([
                    poi.name,
                    poi.lat,
                    poi.lon,
                    poi.ele or '',
                    poi.desc,
                    poi.link or ''
                ])

                if verbose:
                    print(f"Exported: {poi.name} ({poi.lat:.6f}, {poi.lon:.6f})")

    @staticmethod
    def export_to_kml(pois: List[POI], output_path: Path, verbose: bool = False):
        """Export POIs to KML format for Google Earth"""
        # Create KML root
        kml = ET.Element('kml')
        kml.set('xmlns', 'http://www.opengis.net/kml/2.2')

        # Create document
        document = ET.SubElement(kml, 'Document')
        name_elem = ET.SubElement(document, 'name')
        name_elem.text = 'POI Collection'

        # Add styles for different POI types
        ExportHandler._add_kml_styles(document)

        # Group POIs by type for better organization
        poi_groups = ExportHandler._group_pois_by_type(pois)

        for group_name, group_pois in poi_groups.items():
            # Create folder for this group
            folder = ET.SubElement(document, 'Folder')
            folder_name = ET.SubElement(folder, 'name')
            folder_name.text = group_name

            for poi in group_pois:
                placemark = ET.SubElement(folder, 'Placemark')

                # Name
                name_elem = ET.SubElement(placemark, 'name')
                name_elem.text = poi.name

                # Description
                if poi.desc:
                    desc_elem = ET.SubElement(placemark, 'description')
                    desc_elem.text = poi.desc

                # Style
                style_url = ET.SubElement(placemark, 'styleUrl')
                poi_type = ExportHandler._determine_poi_type(poi.name.lower())
                style_url.text = f"#{poi_type}-style"

                # Point
                point = ET.SubElement(placemark, 'Point')
                coordinates = ET.SubElement(point, 'coordinates')
                ele_str = f",{poi.ele}" if poi.ele is not None else ""
                coordinates.text = f"{poi.lon},{poi.lat}{ele_str}"

                if verbose:
                    print(f"Added to KML: {poi.name} ({group_name})")

        # Write KML file
        tree = ET.ElementTree(kml)
        ET.indent(tree, space="  ", level=0)
        tree.write(output_path, encoding='utf-8', xml_declaration=True)

    @staticmethod
    def _add_kml_styles(document: ET.Element):
        """Add KML styles for different POI types"""
        styles = {
            'cabin': {'color': 'ff0000ff', 'icon': 'http://maps.google.com/mapfiles/kml/shapes/lodging.png'},
            'peak': {'color': 'ff00ff00', 'icon': 'http://maps.google.com/mapfiles/kml/shapes/triangle.png'},
            'lake': {'color': 'ffff0000', 'icon': 'http://maps.google.com/mapfiles/kml/shapes/water.png'},
            'default': {'color': 'ffffff00', 'icon': 'http://maps.google.com/mapfiles/kml/pushpin/ylw-pushpin.png'}
        }

        for style_name, style_info in styles.items():
            style = ET.SubElement(document, 'Style')
            style.set('id', f'{style_name}-style')

            icon_style = ET.SubElement(style, 'IconStyle')
            color = ET.SubElement(icon_style, 'color')
            color.text = style_info['color']

            icon = ET.SubElement(icon_style, 'Icon')
            href = ET.SubElement(icon, 'href')
            href.text = style_info['icon']

    @staticmethod
    def _group_pois_by_type(pois: List[POI]) -> Dict[str, List[POI]]:
        """Group POIs by type based on name analysis"""
        groups = {
            'Mountain Huts & Cabins': [],
            'Peaks & Summits': [],
            'Lakes & Water': [],
            'Other Locations': []
        }

        for poi in pois:
            name_lower = poi.name.lower()

            if any(word in name_lower for word in ['hytte', 'cabin', 'hut', 'turisthytte', 'koie']):
                groups['Mountain Huts & Cabins'].append(poi)
            elif any(word in name_lower for word in ['topp', 'peak', 'summit', 'fjell', 'berg']):
                groups['Peaks & Summits'].append(poi)
            elif any(word in name_lower for word in ['vatn', 'lake', 'tjern', 'sjø']):
                groups['Lakes & Water'].append(poi)
            else:
                groups['Other Locations'].append(poi)

        # Remove empty groups
        return {name: pois for name, pois in groups.items() if pois}

    @staticmethod
    def _determine_poi_type(name_lower: str) -> str:
        """Determine POI type from name for styling"""
        if any(word in name_lower for word in ['hytte', 'cabin', 'hut', 'turisthytte', 'koie']):
            return 'cabin'
        elif any(word in name_lower for word in ['topp', 'peak', 'summit', 'fjell', 'berg']):
            return 'peak'
        elif any(word in name_lower for word in ['vatn', 'lake', 'tjern', 'sjø']):
            return 'lake'
        else:
            return 'default'
