//
//  POI.swift
//  GPX POI Tool
//
//  Created on 26.09.2025
//

import Foundation
import MapKit

/// Point of Interest model that matches the Python POI structure
struct POI: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let latitude: Double
    let longitude: Double
    let elevation: Double?
    let symbol: String?
    let extensions: String? // Raw XML extensions from GPX

    /// Computed property for MapKit coordinate
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Initialize from GPX data (matching Python structure)
    init(
        name: String,
        description: String = "",
        latitude: Double,
        longitude: Double,
        elevation: Double? = nil,
        symbol: String? = nil,
        extensions: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.symbol = symbol
        self.extensions = extensions
    }

    /// Equatable conformance - POIs are equal if they have the same ID
    static func == (lhs: POI, rhs: POI) -> Bool {
        return lhs.id == rhs.id
    }

    /// Hashable conformance - hash based on ID
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Distance to another POI in meters
    func distance(to other: POI) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }

    /// Check if this POI is a duplicate of another (using same logic as Python tool)
    func isDuplicate(of other: POI, threshold: Double = 50.0) -> Bool {
        // Name match (case insensitive)
        if self.name.lowercased() == other.name.lowercased() {
            return true
        }

        // Distance match
        return distance(to: other) < threshold
    }

    /// Map annotation symbol based on POI type
    var mapSymbol: String {
        if let symbol = self.symbol {
            return symbol
        }

        // Intelligent symbol detection based on name
        let lowercaseName = self.name.lowercased()

        if lowercaseName.contains("hytte") || lowercaseName.contains("hut") || lowercaseName.contains("cabin") {
            return "house.fill"
        } else if lowercaseName.contains("peak") || lowercaseName.contains("topp") || lowercaseName.contains("fjell") {
            return "mountain.2.fill"
        } else if lowercaseName.contains("lake") || lowercaseName.contains("tjern") || lowercaseName.contains("vatn") {
            return "drop.fill"
        } else if lowercaseName.contains("beach") || lowercaseName.contains("strand") {
            return "beach.umbrella.fill"
        } else {
            return "mappin"
        }
    }

    /// Color for map annotation
    var mapColor: String {
        let lowercaseName = self.name.lowercased()

        if lowercaseName.contains("hytte") || lowercaseName.contains("hut") || lowercaseName.contains("cabin") {
            return "red"
        } else if lowercaseName.contains("peak") || lowercaseName.contains("topp") || lowercaseName.contains("fjell") {
            return "green"
        } else if lowercaseName.contains("lake") || lowercaseName.contains("tjern") || lowercaseName.contains("vatn") {
            return "blue"
        } else {
            return "orange"
        }
    }
}

/// Collection of POIs with utility methods
struct POICollection {
    var pois: [POI]

    init(pois: [POI] = []) {
        self.pois = pois
    }

    /// Add POIs and automatically deduplicate
    mutating func add(_ newPOIs: [POI], threshold: Double = 50.0) -> (added: Int, merged: Int) {
        var addedCount = 0
        var mergedCount = 0

        for newPOI in newPOIs {
            if let existingIndex = pois.firstIndex(where: { $0.isDuplicate(of: newPOI, threshold: threshold) }) {
                // Merge with existing POI (keep the more detailed one)
                let existing = pois[existingIndex]
                let merged = mergePOIs(existing: existing, new: newPOI)
                pois[existingIndex] = merged
                mergedCount += 1
            } else {
                // Add new POI
                pois.append(newPOI)
                addedCount += 1
            }
        }

        return (added: addedCount, merged: mergedCount)
    }

    /// Remove duplicates within the collection
    mutating func deduplicate(threshold: Double = 50.0) -> Int {
        let originalCount = pois.count
        var uniquePOIs: [POI] = []

        for poi in pois {
            if !uniquePOIs.contains(where: { $0.isDuplicate(of: poi, threshold: threshold) }) {
                uniquePOIs.append(poi)
            }
        }

        pois = uniquePOIs
        return originalCount - pois.count
    }

    /// Merge two POIs, keeping the best information from both
    private func mergePOIs(existing: POI, new: POI) -> POI {
        return POI(
            name: existing.name.count > new.name.count ? existing.name : new.name,
            description: existing.description.count > new.description.count ? existing.description : new.description,
            latitude: existing.latitude,
            longitude: existing.longitude,
            elevation: new.elevation ?? existing.elevation,
            symbol: new.symbol ?? existing.symbol,
            extensions: new.extensions ?? existing.extensions
        )
    }
}
