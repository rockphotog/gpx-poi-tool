//
//  GPXProcessor.swift
//  GPX POI Tool
//
//  Created on 26.09.2025
//

import Foundation
import Combine

/// Main service class that handles GPX processing with native Swift elevation lookup
@MainActor
class GPXProcessor: ObservableObject {
    @Published var pois: [POI] = []
    @Published var isLoading = false
    @Published var lastProcessingResult = ""

    private var poiCollection = POICollection()
    private let elevationService = ElevationService()

    init() {
        // No longer need Python tool initialization
    }

    // MARK: - Public Methods

    /// Import GPX files and add POIs to the collection
    func importGPXFiles(_ urls: [URL]) async throws -> (added: Int, merged: Int) {
        isLoading = true
        defer { isLoading = false }

        var allNewPOIs: [POI] = []

        for url in urls {
            // Each URL needs its own security-scoped access
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let pois = try await loadGPXFile(url)
                allNewPOIs.append(contentsOf: pois)
                print("Successfully loaded \(pois.count) POIs from \(url.lastPathComponent)")
            } catch {
                print("Failed to load file \(url.lastPathComponent): \(error)")
                throw GPXError.fileAccessDenied(url.lastPathComponent)
            }
        }

        let result = poiCollection.add(allNewPOIs)
        pois = poiCollection.pois

        lastProcessingResult = "Added \(result.added), merged \(result.merged)"

        return result
    }

    /// Remove duplicate POIs from the collection
    func deduplicate(threshold: Double = 50.0) -> Int {
        let removed = poiCollection.deduplicate(threshold: threshold)
        pois = poiCollection.pois
        return removed
    }

    /// Add elevation data to POIs using native Swift elevation service
    func addElevationData() async throws -> Int {
        guard !pois.isEmpty else { return 0 }

        isLoading = true
        defer { isLoading = false }

        // Extract coordinates from POIs that don't have elevation data
        let coordinatesNeedingElevation = pois.enumerated().compactMap { index, poi in
            if poi.elevation == nil || poi.elevation == 0 {
                return (index, poi.latitude, poi.longitude)
            }
            return nil
        }

        guard !coordinatesNeedingElevation.isEmpty else {
            lastProcessingResult = "All POIs already have elevation data"
            return 0
        }

        print("Fetching elevation data for \(coordinatesNeedingElevation.count) POIs...")

        // Fetch elevation data
        let coordinates = coordinatesNeedingElevation.map { $0.1 }
        let elevationResults: [ElevationService.ElevationPoint]
        
        do {
            elevationResults = try await elevationService.fetchElevations(for: coordinates)
        } catch {
            throw GPXError.elevationLookupFailed(error.localizedDescription)
        }

        // Update POIs with elevation data
        var updatedPOIs = pois
        var enhancedCount = 0

        for (arrayIndex, (poiIndex, _, _)) in coordinatesNeedingElevation.enumerated() {
            if let elevation = elevationResults[arrayIndex].elevation, elevation > 0 {
                let originalPOI = updatedPOIs[poiIndex]
                updatedPOIs[poiIndex] = POI(
                    name: originalPOI.name,
                    description: originalPOI.description,
                    latitude: originalPOI.latitude,
                    longitude: originalPOI.longitude,
                    elevation: elevation,
                    symbol: originalPOI.symbol,
                    extensions: originalPOI.extensions
                )
                enhancedCount += 1
            }
        }

        // Update the collection
        poiCollection = POICollection(pois: updatedPOIs)
        pois = poiCollection.pois

        lastProcessingResult = "Added elevation data to \(enhancedCount) of \(coordinatesNeedingElevation.count) POIs"
        print("Successfully added elevation data to \(enhancedCount) POIs")

        return enhancedCount
    }

    /// Export POIs to KML format using native Swift implementation
    func exportKML(to url: URL) async throws {
        guard !pois.isEmpty else { return }

        try KMLExporter.exportPOIs(pois, to: url)
        
        print("Successfully exported \(pois.count) POIs to KML: \(url.lastPathComponent)")
    }

    // MARK: - Private Methods

    /// Load POIs from a GPX file using simple XML parsing
    private func loadGPXFile(_ url: URL) async throws -> [POI] {
        let data = try Data(contentsOf: url)
        return try parseGPXData(data)
    }

    /// Parse GPX data and extract POIs
    private func parseGPXData(_ data: Data) throws -> [POI] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw GPXError.invalidEncoding
        }

        var pois: [POI] = []
        let lines = content.components(separatedBy: .newlines)

        var currentWaypoint: [String: String] = [:]
        var insideWaypoint = false
        var insideExtensions = false
        var extensionsContent = ""

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedLine.contains("<wpt") {
                insideWaypoint = true
                currentWaypoint = [:]
                extensionsContent = ""

                // Extract lat and lon from wpt tag
                if let latMatch = extractAttribute("lat", from: trimmedLine),
                   let lonMatch = extractAttribute("lon", from: trimmedLine) {
                    currentWaypoint["lat"] = latMatch
                    currentWaypoint["lon"] = lonMatch
                }
            } else if trimmedLine.contains("</wpt>") && insideWaypoint {
                // Create POI from collected data
                if let poi = createPOI(from: currentWaypoint, extensions: extensionsContent) {
                    pois.append(poi)
                }
                insideWaypoint = false
                insideExtensions = false
            } else if insideWaypoint {
                if trimmedLine.contains("<extensions>") {
                    insideExtensions = true
                    extensionsContent = trimmedLine
                } else if trimmedLine.contains("</extensions>") {
                    insideExtensions = false
                    extensionsContent += "\n" + trimmedLine
                } else if insideExtensions {
                    extensionsContent += "\n" + trimmedLine
                } else {
                    // Extract other waypoint data
                    if let value = extractTagContent("name", from: trimmedLine) {
                        currentWaypoint["name"] = value
                    } else if let value = extractTagContent("desc", from: trimmedLine) {
                        currentWaypoint["desc"] = value
                    } else if let value = extractTagContent("ele", from: trimmedLine) {
                        currentWaypoint["ele"] = value
                    } else if let value = extractTagContent("sym", from: trimmedLine) {
                        currentWaypoint["sym"] = value
                    }
                }
            }
        }

        return pois
    }

    /// Create a POI from parsed waypoint data
    private func createPOI(from data: [String: String], extensions: String) -> POI? {
        guard let latString = data["lat"],
              let lonString = data["lon"],
              let lat = Double(latString),
              let lon = Double(lonString),
              let name = data["name"] else {
            return nil
        }

        let description = data["desc"] ?? ""
        let elevation = data["ele"].flatMap { Double($0) }
        let symbol = data["sym"]
        let ext = extensions.isEmpty ? nil : extensions

        return POI(
            name: name,
            description: description,
            latitude: lat,
            longitude: lon,
            elevation: elevation,
            symbol: symbol,
            extensions: ext
        )
    }

    /// Write POIs to GPX format
    private func writeGPXFile(_ pois: [POI], to url: URL) throws {
        var gpxContent = """
        <?xml version='1.0' encoding='utf-8'?>
        <gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd" version="1.1" creator="GPX POI Tool SwiftUI">
          <metadata />
        """

        for poi in pois {
            gpxContent += "\n  <wpt lat=\"\(poi.latitude)\" lon=\"\(poi.longitude)\">"
            gpxContent += "\n    <name>\(xmlEscape(poi.name))</name>"

            if !poi.description.isEmpty {
                gpxContent += "\n    <desc>\(xmlEscape(poi.description))</desc>"
            }

            if let elevation = poi.elevation {
                gpxContent += "\n    <ele>\(elevation)</ele>"
            }

            if let symbol = poi.symbol {
                gpxContent += "\n    <sym>\(xmlEscape(symbol))</sym>"
            }

            if let extensions = poi.extensions {
                gpxContent += "\n" + extensions
            }

            gpxContent += "\n  </wpt>"
        }

        gpxContent += "\n</gpx>"

        try gpxContent.write(to: url, atomically: true, encoding: .utf8)
    }



    // MARK: - Helper Methods

    private func extractAttribute(_ attribute: String, from line: String) -> String? {
        let pattern = "\(attribute)=\"([^\"]*)\""
        return extractRegexMatch(pattern: pattern, from: line)
    }

    private func extractTagContent(_ tag: String, from line: String) -> String? {
        let pattern = "<\(tag)>(.*?)</\(tag)>"
        return extractRegexMatch(pattern: pattern, from: line)
    }

    private func extractRegexMatch(pattern: String, from text: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let matchRange = Range(match.range(at: 1), in: text) {
                return String(text[matchRange])
            }
        } catch {
            print("Regex error: \(error)")
        }
        return nil
    }

    private func xmlEscape(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - Errors

enum GPXError: LocalizedError {
    case invalidEncoding
    case fileNotFound
    case fileAccessDenied(String)
    case elevationLookupFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "Invalid file encoding"
        case .fileNotFound:
            return "File not found"
        case .fileAccessDenied(let filename):
            return "Access denied to file: \(filename). Make sure the app has permission to access this file."
        case .elevationLookupFailed(let message):
            return "Elevation lookup failed: \(message)"
        }
    }
}
