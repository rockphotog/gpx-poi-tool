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
        """Look up elevation data for POIs using online service with robust error handling"""
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
        total_batches = (len(pois_needing_elevation) + batch_size - 1) // batch_size
        updated_pois = cleaned_pois.copy()

        # Track success/failure statistics
        successful_elevations = 0
        failed_batches = 0
        total_processed = 0

        for i in range(0, len(pois_needing_elevation), batch_size):
            batch = pois_needing_elevation[i:i+batch_size]
            batch_num = i // batch_size + 1

            if verbose:
                print(f"Processing batch {batch_num}/{total_batches} ({len(batch)} POIs)...")

            # Count POIs in batch that had elevation before processing
            before_count = sum(1 for poi in batch if poi.ele is not None and poi.ele > 0)

            # Update elevations for this batch
            batch_updated = self._lookup_elevation_batch(batch, verbose)

            # Count successful elevations in this batch
            after_count = sum(1 for poi in batch_updated if poi.ele is not None and poi.ele > 0)
            batch_success = after_count - before_count

            if batch_success == 0 and len(batch) > 0:
                failed_batches += 1
                if verbose:
                    print(f"  Warning: No elevations retrieved for batch {batch_num}")
            elif verbose and batch_success < len(batch):
                print(f"  Partial success: {batch_success}/{len(batch)} elevations retrieved")

            successful_elevations += batch_success
            total_processed += len(batch)

            # Replace POIs in the main list
            for updated_poi in batch_updated:
                for j, original_poi in enumerate(updated_pois):
                    if (updated_poi.lat == original_poi.lat and
                        updated_poi.lon == original_poi.lon and
                        updated_poi.name == original_poi.name):
                        updated_pois[j] = updated_poi
                        break

            # Adaptive rate limiting - slower if we had failures
            if batch_success < len(batch) // 2:  # Less than 50% success rate
                time.sleep(0.5)  # Longer delay
            else:
                time.sleep(0.1)  # Normal delay

        # Final statistics
        if verbose:
            print(f"\nElevation lookup summary:")
            print(f"  Total POIs processed: {total_processed}")
            print(f"  Successful elevations: {successful_elevations}")
            print(f"  Success rate: {(successful_elevations/total_processed*100):.1f}%" if total_processed > 0 else "  Success rate: 0%")

            if failed_batches > 0:
                print(f"  Batches with failures: {failed_batches}/{total_batches}")
                print(f"  Note: Elevation failures may be due to API limitations in remote areas")

        # Warn user if success rate is very low
        if total_processed > 0 and successful_elevations / total_processed < 0.1:  # Less than 10% success
            print(f"Warning: Very low elevation success rate ({successful_elevations}/{total_processed})")
            print("This may indicate API connectivity issues or POIs in unsupported regions")

        return updated_pois

    def _lookup_elevation_batch(self, pois: List[POI], verbose: bool = False, max_retries: int = 3) -> List[POI]:
        """Look up elevation for a batch of POIs with robust error handling and retries"""
        locations = [{"latitude": poi.lat, "longitude": poi.lon} for poi in pois]

        # Calculate dynamic timeout based on batch size (minimum 30 seconds, +1 second per POI)
        timeout = max(30, 30 + len(pois))

        for attempt in range(max_retries):
            try:
                if verbose and attempt > 0:
                    print(f"  Retry attempt {attempt + 1}/{max_retries}...")

                # Use Open-Elevation API (free service)
                response = requests.post(
                    "https://api.open-elevation.com/api/v1/lookup",
                    json={"locations": locations},
                    timeout=timeout,
                    headers={'User-Agent': 'GPX-POI-Tool/1.0'}
                )

                if response.status_code == 200:
                    try:
                        elevation_data = response.json()
                    except ValueError as e:
                        if verbose:
                            print(f"  API returned invalid JSON: {e}")
                        if attempt < max_retries - 1:
                            time.sleep(2 ** attempt)  # Exponential backoff
                            continue
                        return pois

                    results = elevation_data.get('results', [])

                    if len(results) != len(pois):
                        if verbose:
                            print(f"  Warning: API returned {len(results)} results for {len(pois)} POIs")

                    updated_pois = []
                    successful_lookups = 0

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
                                    link=poi.link,
                                    extensions=poi.extensions
                                )
                                updated_pois.append(updated_poi)
                                successful_lookups += 1

                                if verbose:
                                    print(f"  {poi.name}: {elevation}m")
                            else:
                                # Keep original POI without elevation (don't add invalid 0.0)
                                updated_pois.append(poi)
                                if verbose and elevation == 0:
                                    print(f"  {poi.name}: Skipped (elevation=0, likely invalid)")
                        else:
                            # API returned fewer results than expected
                            updated_pois.append(poi)
                            if verbose:
                                print(f"  {poi.name}: No elevation data returned")

                    if verbose and successful_lookups < len(pois):
                        print(f"  Successfully retrieved elevation for {successful_lookups}/{len(pois)} POIs")

                    return updated_pois

                elif response.status_code == 429:  # Rate limited
                    if verbose:
                        print(f"  Rate limited (HTTP 429), waiting before retry...")
                    if attempt < max_retries - 1:
                        time.sleep(5 * (2 ** attempt))  # Longer backoff for rate limiting
                        continue
                    else:
                        if verbose:
                            print(f"  Rate limiting persists after {max_retries} attempts")
                        return pois

                elif response.status_code >= 500:  # Server error
                    if verbose:
                        print(f"  Server error (HTTP {response.status_code}), retrying...")
                    if attempt < max_retries - 1:
                        time.sleep(2 ** attempt)  # Exponential backoff
                        continue
                    else:
                        if verbose:
                            print(f"  Server errors persist after {max_retries} attempts")
                        return pois

                else:  # Other HTTP errors (4xx)
                    if verbose:
                        print(f"  API error (HTTP {response.status_code}): {response.text[:100]}")
                    return pois  # Don't retry for client errors

            except requests.exceptions.Timeout:
                if verbose:
                    print(f"  Request timeout after {timeout} seconds")
                if attempt < max_retries - 1:
                    timeout = min(timeout * 1.5, 120)  # Increase timeout for retry, max 2 minutes
                    if verbose:
                        print(f"  Increasing timeout to {timeout} seconds for retry")
                    continue
                else:
                    if verbose:
                        print(f"  Timeout persists after {max_retries} attempts")
                    return pois

            except requests.exceptions.ConnectionError:
                if verbose:
                    print(f"  Connection error - network unavailable")
                if attempt < max_retries - 1:
                    time.sleep(5 * (2 ** attempt))  # Longer backoff for connection issues
                    continue
                else:
                    if verbose:
                        print(f"  Connection issues persist after {max_retries} attempts")
                    return pois

            except requests.exceptions.RequestException as e:
                if verbose:
                    print(f"  Network error: {e}")
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)  # Exponential backoff
                    continue
                else:
                    if verbose:
                        print(f"  Network errors persist after {max_retries} attempts")
                    return pois

            except Exception as e:
                if verbose:
                    print(f"  Unexpected error: {e}")
                return pois  # Don't retry for unexpected errors

        # Should not reach here, but just in case
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

    def split_to_individual_files(self, gpx_file_path: Path, verbose: bool = False) -> int:
        """
        Split a GPX file into individual GPX files, one POI per file.

        Args:
            gpx_file_path: Path to the source GPX file
            verbose: Enable verbose output

        Returns:
            Number of individual files created
        """
        # Read POIs from the source file
        pois = self.read_gpx_file(gpx_file_path)

        if not pois:
            if verbose:
                print(f"No POIs found in {gpx_file_path}")
            return 0

        # Create output directory name
        base_name = gpx_file_path.stem  # Get filename without .gpx extension
        output_dir = gpx_file_path.parent / f"single-poi-{base_name}"

        # Create output directory
        output_dir.mkdir(exist_ok=True)

        if verbose:
            print(f"Splitting {len(pois)} POIs from {gpx_file_path}")
            print(f"Output directory: {output_dir}")

        created_count = 0
        skipped_count = 0

        for poi in pois:
            # Sanitize POI name for filename
            safe_name = self._sanitize_filename(poi.name)

            if not safe_name:
                skipped_count += 1
                if verbose:
                    print(f"  Skipped POI with empty/invalid name: '{poi.name}'")
                continue

            # Create individual GPX file
            output_file = output_dir / f"{safe_name}.gpx"

            try:
                # Write single POI to new GPX file
                self.write_gpx_file(output_file, [poi])
                created_count += 1

                if verbose:
                    print(f"  Created: {output_file.name}")

            except Exception as e:
                if verbose:
                    print(f"  Error creating {output_file.name}: {e}")
                skipped_count += 1

        if verbose:
            print(f"Split complete: {created_count} files created, {skipped_count} skipped")

        return created_count

    def _sanitize_filename(self, name: str) -> str:
        """
        Sanitize a POI name to be safe for use as a filename.

        Args:
            name: Original POI name

        Returns:
            Sanitized filename (without extension)
        """
        if not name or not name.strip():
            return ""

        # Remove or replace unsafe characters
        import re

        # Replace common problematic characters
        sanitized = name.strip()
        sanitized = re.sub(r'[<>:"/\\|?*]', '_', sanitized)  # Windows forbidden chars
        sanitized = re.sub(r'[^\w\s\-_åæøÅÆØ]', '_', sanitized)  # Keep alphanumeric, spaces, Norwegian chars
        sanitized = re.sub(r'\s+', '_', sanitized)  # Replace spaces with underscores
        sanitized = sanitized.strip('_')  # Remove leading/trailing underscores

        # Limit length (many filesystems have 255 char limits)
        if len(sanitized) > 200:
            sanitized = sanitized[:200]

        return sanitized if sanitized else "unnamed_poi"
