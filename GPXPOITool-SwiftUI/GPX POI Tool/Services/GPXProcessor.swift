//
//  GPXProcessor.swift
//  GPX POI Tool
//
//  Created on 26.09.2025
//

import Foundation
import Combine

/// Main service class that handles GPX processing and integrates with the Python tool
@MainActor
class GPXProcessor: ObservableObject {
    @Published var pois: [POI] = []
    @Published var isLoading = false
    @Published var lastProcessingResult = ""

    private var poiCollection = POICollection()
    private let pythonToolPath: URL

    init() {
        // Find the Python tool relative to the app bundle or in the project directory
        if let bundlePath = Bundle.main.resourceURL {
            pythonToolPath = bundlePath.appendingPathComponent("poi-tool.py")
        } else {
            // Development fallback - look for the tool in the project directory
            pythonToolPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("poi-tool.py")
        }
    }

    // MARK: - Public Methods

    /// Import GPX files and add POIs to the collection
    func importGPXFiles(_ urls: [URL]) async throws -> (added: Int, merged: Int) {
        isLoading = true
        defer { isLoading = false }

        var allNewPOIs: [POI] = []

        for url in urls {
            let pois = try await loadGPXFile(url)
            allNewPOIs.append(contentsOf: pois)
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

    /// Add elevation data to POIs using the Python tool
    func addElevationData() async throws -> Int {
        guard !pois.isEmpty else { return 0 }

        isLoading = true
        defer { isLoading = false }

        // Create temporary GPX file
        let tempDir = FileManager.default.temporaryDirectory
        let tempGPXFile = tempDir.appendingPathComponent("temp_\(UUID().uuidString).gpx")
        let tempOutputFile = tempDir.appendingPathComponent("temp_output_\(UUID().uuidString).gpx")

        defer {
            try? FileManager.default.removeItem(at: tempGPXFile)
            try? FileManager.default.removeItem(at: tempOutputFile)
        }

        // Write current POIs to temp file
        try writeGPXFile(pois, to: tempGPXFile)

        // Call Python tool to add elevation
        try await runPythonTool(arguments: [
            "-t", tempOutputFile.path,
            "-a", tempGPXFile.path,
            "--elevation-lookup"
        ])

        // Read back the enhanced POIs
        let enhancedPOIs = try await loadGPXFile(tempOutputFile)

        // Update collection
        poiCollection = POICollection(pois: enhancedPOIs)
        pois = poiCollection.pois

        return enhancedPOIs.count { $0.elevation != nil && $0.elevation! > 0 }
    }

    /// Export POIs to KML format
    func exportKML(to url: URL) async throws {
        guard !pois.isEmpty else { return }

        // Create temporary GPX file
        let tempDir = FileManager.default.temporaryDirectory
        let tempGPXFile = tempDir.appendingPathComponent("export_\(UUID().uuidString).gpx")

        defer {
            try? FileManager.default.removeItem(at: tempGPXFile)
        }

        // Write current POIs to temp file
        try writeGPXFile(pois, to: tempGPXFile)

        // Call Python tool to export KML
        try await runPythonTool(arguments: [
            "-t", tempGPXFile.path,
            "--export-kml", url.path
        ])
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

    /// Run the Python tool with given arguments
    private func runPythonTool(arguments: [String]) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [pythonToolPath.path] + arguments

            // Capture output for error handling
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: GPXError.pythonToolFailed(output))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
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
    case pythonToolFailed(String)
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "Invalid file encoding"
        case .pythonToolFailed(let message):
            return "Python tool failed: \(message)"
        case .fileNotFound:
            return "File not found"
        }
    }
}
