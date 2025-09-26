#!/usr/bin/env python3
"""
POI (Point of Interest) data structures and core algorithms.

This module contains the POI class and spatial indexing utilities
for high-performance POI operations.
"""

import math
from collections import defaultdict
from dataclasses import dataclass
from typing import Dict, List, Optional, Set, Tuple


@dataclass
class POI:
    """Represents a Point of Interest from a GPX file"""
    lat: float
    lon: float
    name: str
    desc: str = ""
    ele: Optional[float] = None
    link: Optional[str] = None
    extensions: Optional[str] = None  # Raw XML string of extensions element

    def distance_to(self, other: 'POI') -> float:
        """Calculate distance between two POIs using Haversine formula (in meters)"""
        R = 6371000  # Earth's radius in meters

        lat1_rad = math.radians(self.lat)
        lon1_rad = math.radians(self.lon)
        lat2_rad = math.radians(other.lat)
        lon2_rad = math.radians(other.lon)

        dlat = lat2_rad - lat1_rad
        dlon = lon2_rad - lon1_rad

        a = math.sin(dlat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon/2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

        return R * c

    def is_duplicate(self, other: 'POI', distance_threshold: float = 100.0) -> bool:
        """Check if two POIs are duplicates based on distance threshold"""
        if self.distance_to(other) <= distance_threshold:
            return True
        return False

    def merge_with(self, other: 'POI') -> 'POI':
        """Merge this POI with another, preferring more complete data"""
        # Choose the better name (longer or non-generic)
        name = self.name
        if len(other.name) > len(self.name) or 'waypoint' in self.name.lower():
            name = other.name

        # Choose the better description (longer)
        desc = self.desc if len(self.desc) > len(other.desc) else other.desc

        # Choose elevation data if available
        ele = self.ele if self.ele is not None else other.ele

        # Choose link if available
        link = self.link if self.link else other.link

        # Choose extensions if available (prefer the one with more data)
        extensions = self.extensions
        if not extensions and other.extensions:
            extensions = other.extensions
        elif extensions and other.extensions and len(other.extensions) > len(extensions):
            extensions = other.extensions

        # Choose coordinates from the POI with elevation data
        if self.ele is not None and other.ele is None:
            lat, lon = self.lat, self.lon
        elif other.ele is not None and self.ele is None:
            lat, lon = other.lat, other.lon
        else:
            # Average the coordinates
            lat = (self.lat + other.lat) / 2
            lon = (self.lon + other.lon) / 2

        return POI(lat=lat, lon=lon, name=name, desc=desc, ele=ele, link=link, extensions=extensions)


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


class DistanceCache:
    """LRU cache for expensive distance calculations."""

    def __init__(self, max_size: int = 10000):
        self.cache: Dict[Tuple[float, float, float, float], float] = {}
        self.access_order: List[Tuple[float, float, float, float]] = []
        self.max_size = max_size

    def get_distance(self, poi1: POI, poi2: POI) -> float:
        """Get cached distance or calculate and cache it."""
        # Create cache key (normalize to ensure consistent ordering)
        if poi1.lat < poi2.lat or (poi1.lat == poi2.lat and poi1.lon < poi2.lon):
            key = (poi1.lat, poi1.lon, poi2.lat, poi2.lon)
        else:
            key = (poi2.lat, poi2.lon, poi1.lat, poi1.lon)

        if key in self.cache:
            # Move to end (most recently used)
            self.access_order.remove(key)
            self.access_order.append(key)
            return self.cache[key]

        # Calculate distance
        distance = poi1.distance_to(poi2)

        # Add to cache
        self.cache[key] = distance
        self.access_order.append(key)

        # Maintain cache size
        if len(self.cache) > self.max_size:
            oldest = self.access_order.pop(0)
            del self.cache[oldest]

        return distance
