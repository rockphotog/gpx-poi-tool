#!/usr/bin/env python3
"""
POI processing operations with performance optimizations.

This module contains the GPXManager class with optimized algorithms
for POI deduplication, merging, and enhancement operations.
"""

import json
import re
import time
from pathlib import Path
from typing import Dict, List, Optional, Set
from urllib.parse import urljoin, urlparse

import requests

from poi_core import POI, SpatialGrid
from poi_formats import FITFileHandler, GPXFileHandler


class GPXManager:
    """Manages GPX files and POI operations with optimized algorithms"""

    def __init__(self):
        self.gpx_handler = GPXFileHandler()
        self.fit_handler = FITFileHandler()
        self.duplicate_threshold = 100.0  # meters

    def read_gpx_file(self, file_path: Path) -> List[POI]:
        """Read POIs from a GPX or FIT file"""
        if not file_path.exists():
            print(f"File not found: {file_path}")
            return []

        # Determine file type and use appropriate handler
        if file_path.suffix.lower() == '.fit':
            return self.fit_handler.read_fit_file(file_path)
        else:
            return self.gpx_handler.read_gpx_file(file_path)

    def write_gpx_file(self, file_path: Path, pois: List[POI]):
        """Write POIs to a GPX file"""
        self.gpx_handler.write_gpx_file(file_path, pois)

    def write_garmin_optimized_gpx(self, file_path: Path, pois: List[POI]):
        """Write GPX file optimized for Garmin devices"""
        self.gpx_handler.write_garmin_optimized_gpx(file_path, pois)

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
            optimized_name = poi.name

            # Garmin device limitations
            if len(optimized_name) > 20:
                optimized_name = optimized_name[:20]

            # Clean up name for better display
            optimized_name = re.sub(r'[^\w\s-]', '', optimized_name)
            optimized_name = optimized_name.strip()

            optimized_poi = POI(
                lat=poi.lat,
                lon=poi.lon,
                name=optimized_name,
                desc=poi.desc,
                ele=poi.ele,
                link=poi.link
            )

            optimized_pois.append(optimized_poi)

        return optimized_pois

    def add_waypoint_symbols(self, pois: List[POI]) -> List[POI]:
        """Add Garmin waypoint symbols based on POI names"""
        result_pois = []

        for poi in pois:
            # Copy POI (no actual symbol field in POI class, this is for GPX export)
            result_pois.append(poi)

        return result_pois

    def lookup_elevations(self, pois: List[POI], verbose: bool = False) -> List[POI]:
        """Look up elevation data for POIs using online service"""
        if verbose:
            print(f"Looking up elevations for {len(pois)} POIs...")

        # First, clean any existing POIs with zero elevation (invalid data)
        cleaned_pois = self._remove_zero_elevations(pois, verbose)
        
        # Filter POIs that need elevation data (None or removed zeros)
        pois_needing_elevation = [poi for poi in cleaned_pois if poi.ele is None]

        if not pois_needing_elevation:
            if verbose:
                print("All POIs already have elevation data")
            return cleaned_pois

        if verbose:
            print(f"Found {len(pois_needing_elevation)} POIs without elevation data")

        # Process in batches to avoid overwhelming the API
        batch_size = 50
        updated_pois = cleaned_pois.copy()

        for i in range(0, len(pois_needing_elevation), batch_size):
            batch = pois_needing_elevation[i:i+batch_size]

            if verbose:
                print(f"Processing batch {i//batch_size + 1} ({len(batch)} POIs)...")

            # Update elevations for this batch
            batch_updated = self._lookup_elevation_batch(batch, verbose)

            # Replace POIs in the main list
            for updated_poi in batch_updated:
                for j, original_poi in enumerate(updated_pois):
                    if (updated_poi.lat == original_poi.lat and
                        updated_poi.lon == original_poi.lon and
                        updated_poi.name == original_poi.name):
                        updated_pois[j] = updated_poi
                        break

            # Rate limiting
            time.sleep(0.1)

        return updated_pois

    def _lookup_elevation_batch(self, pois: List[POI], verbose: bool = False) -> List[POI]:
        """Look up elevation for a batch of POIs"""
        try:
            # Use Open-Elevation API (free service)
            locations = [{"latitude": poi.lat, "longitude": poi.lon} for poi in pois]

            response = requests.post(
                "https://api.open-elevation.com/api/v1/lookup",
                json={"locations": locations},
                timeout=30
            )

            if response.status_code == 200:
                elevation_data = response.json()
                results = elevation_data.get('results', [])

                updated_pois = []
                for i, poi in enumerate(pois):
                    if i < len(results):
                        elevation = results[i].get('elevation')
                        if elevation is not None and elevation > 0:
                            # Only add elevation if it's greater than 0 (valid data)
                            updated_poi = POI(
                                lat=poi.lat,
                                lon=poi.lon,
                                name=poi.name,
                                desc=poi.desc,
                                ele=float(elevation),
                                link=poi.link
                            )
                            updated_pois.append(updated_poi)

                            if verbose:
                                print(f"  {poi.name}: {elevation}m")
                        else:
                            # Keep original POI without elevation (don't add invalid 0.0)
                            updated_pois.append(poi)
                            if verbose and elevation == 0:
                                print(f"  {poi.name}: Skipped (elevation=0, likely invalid)")
                    else:
                        updated_pois.append(poi)

                return updated_pois
            else:
                if verbose:
                    print(f"  Elevation API error: {response.status_code}")
                return pois

        except Exception as e:
            if verbose:
                print(f"  Elevation lookup failed: {e}")
            return pois

    def _remove_zero_elevations(self, pois: List[POI], verbose: bool = False) -> List[POI]:
        """Remove POIs with zero elevation (typically invalid data)"""
        cleaned_pois = []
        removed_count = 0
        
        for poi in pois:
            if poi.ele is not None and poi.ele == 0.0:
                removed_count += 1
                # Create new POI without the invalid elevation
                cleaned_poi = POI(
                    lat=poi.lat,
                    lon=poi.lon,
                    name=poi.name,
                    desc=poi.desc,
                    ele=None,  # Remove the zero elevation
                    link=poi.link
                )
                cleaned_pois.append(cleaned_poi)
                if verbose:
                    print(f"  Removed zero elevation from: {poi.name}")
            else:
                cleaned_pois.append(poi)
        
        if verbose and removed_count > 0:
            print(f"Cleaned {removed_count} POIs with invalid zero elevation")
            
        return cleaned_pois

    # Export methods (delegated to format handlers)
    def export_garmin_poi_csv(self, pois: List[POI], output_path: Path, verbose: bool = False):
        """Export POIs to Garmin POI CSV format"""
        from poi_formats import ExportHandler
        ExportHandler.export_to_csv(pois, output_path, 'garmin', verbose)

    def export_to_kml(self, pois: List[POI], output_path: Path, verbose: bool = False):
        """Export POIs to KML format"""
        from poi_formats import ExportHandler
        ExportHandler.export_to_kml(pois, output_path, verbose)
