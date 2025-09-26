//
//  ElevationService.swift
//  GPX POI Tool
//
//  Created on 26.09.2025
//

import Foundation

/// Service for fetching elevation data from various elevation APIs
class ElevationService {
    
    // MARK: - Types
    
    struct ElevationPoint {
        let latitude: Double
        let longitude: Double
        let elevation: Double?
    }
    
    // MARK: - API Endpoints
    
    /// Open-Elevation API (Free, global coverage but limited in northern regions)
    private let openElevationURL = "https://api.open-elevation.com/api/v1/lookup"
    
    /// USGS Elevation Point Query Service (US only, high accuracy)
    private let usgsElevationURL = "https://epqs.nationalmap.gov/v1/json"
    
    // MARK: - Public Methods
    
    /// Fetch elevation data for multiple coordinates
    /// - Parameter coordinates: Array of (latitude, longitude) tuples
    /// - Returns: Array of ElevationPoint objects with elevation data
    func fetchElevations(for coordinates: [(Double, Double)]) async throws -> [ElevationPoint] {
        guard !coordinates.isEmpty else { return [] }
        
        // Batch coordinates into smaller groups to avoid API limits
        let batchSize = 100
        var results: [ElevationPoint] = []
        
        for batch in coordinates.chunked(into: batchSize) {
            let batchResults = try await fetchElevationBatch(batch)
            results.append(contentsOf: batchResults)
            
            // Small delay to be respectful to the API
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        return results
    }
    
    /// Fetch elevation for a single coordinate
    /// - Parameters:
    ///   - latitude: Latitude coordinate
    ///   - longitude: Longitude coordinate
    /// - Returns: Elevation in meters, or nil if not found
    func fetchElevation(latitude: Double, longitude: Double) async throws -> Double? {
        let results = try await fetchElevations(for: [(latitude, longitude)])
        return results.first?.elevation
    }
    
    // MARK: - Private Methods
    
    /// Fetch elevation data for a batch of coordinates
    private func fetchElevationBatch(_ coordinates: [(Double, Double)]) async throws -> [ElevationPoint] {
        // Try Open-Elevation first (supports batch requests)
        do {
            return try await fetchFromOpenElevation(coordinates)
        } catch {
            print("Open-Elevation API failed: \(error). Falling back to individual USGS requests...")
            
            // Fallback to USGS for individual requests (US coordinates only)
            var results: [ElevationPoint] = []
            for (lat, lon) in coordinates {
                do {
                    let elevation = try await fetchFromUSGS(latitude: lat, longitude: lon)
                    results.append(ElevationPoint(latitude: lat, longitude: lon, elevation: elevation))
                } catch {
                    // If USGS fails, add point with nil elevation
                    results.append(ElevationPoint(latitude: lat, longitude: lon, elevation: nil))
                }
            }
            return results
        }
    }
    
    /// Fetch elevation from Open-Elevation API
    private func fetchFromOpenElevation(_ coordinates: [(Double, Double)]) async throws -> [ElevationPoint] {
        var request = URLRequest(url: URL(string: openElevationURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the request body
        let locations = coordinates.map { ["latitude": $0.0, "longitude": $0.1] }
        let requestBody = ["locations": locations]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevationError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ElevationError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        // Parse the response
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let results = jsonResponse?["results"] as? [[String: Any]] else {
            throw ElevationError.invalidData
        }
        
        return try results.map { result in
            guard let latitude = result["latitude"] as? Double,
                  let longitude = result["longitude"] as? Double else {
                throw ElevationError.invalidData
            }
            
            let elevation = result["elevation"] as? Double
            return ElevationPoint(latitude: latitude, longitude: longitude, elevation: elevation)
        }
    }
    
    /// Fetch elevation from USGS API (US only)
    private func fetchFromUSGS(latitude: Double, longitude: Double) async throws -> Double? {
        var components = URLComponents(string: usgsElevationURL)!
        components.queryItems = [
            URLQueryItem(name: "x", value: String(longitude)),
            URLQueryItem(name: "y", value: String(latitude)),
            URLQueryItem(name: "units", value: "Meters"),
            URLQueryItem(name: "output", value: "json")
        ]
        
        guard let url = components.url else {
            throw ElevationError.invalidRequest
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevationError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ElevationError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        // Parse USGS response
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let elevationService = jsonResponse?["USGS_Elevation_Point_Query_Service"] as? [String: Any],
              let elevationQuery = elevationService["Elevation_Query"] as? [String: Any] else {
            throw ElevationError.invalidData
        }
        
        // USGS returns -1000000 for invalid/no data points
        if let elevation = elevationQuery["Elevation"] as? Double, elevation > -999999 {
            return elevation
        }
        
        return nil
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Errors

enum ElevationError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case invalidData
    case apiError(String)
    case noDataAvailable
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid elevation request"
        case .invalidResponse:
            return "Invalid response from elevation service"
        case .invalidData:
            return "Invalid elevation data received"
        case .apiError(let message):
            return "Elevation API error: \(message)"
        case .noDataAvailable:
            return "No elevation data available for this location"
        }
    }
}