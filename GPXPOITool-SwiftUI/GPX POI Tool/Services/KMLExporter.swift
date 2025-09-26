//
//  KMLExporter.swift
//  GPX POI Tool
//
//  Created on 26.09.2025
//

import Foundation

/// Service for exporting POI data to KML format
struct KMLExporter {

    /// Export POIs to KML file
    static func exportPOIs(_ pois: [POI], to url: URL) throws {
        let kmlContent = generateKMLContent(from: pois)
        try kmlContent.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Generate KML content from POIs
    private static func generateKMLContent(from pois: [POI]) -> String {
        var kml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <kml xmlns="http://www.opengis.net/kml/2.2">
          <Document>
            <name>GPX POI Collection</name>
            <description>Exported from GPX POI Tool - \(pois.count) Points of Interest</description>
        """

        // Group POIs by type for better organization
        let groupedPOIs = Dictionary(grouping: pois) { poi in
            classifyPOI(poi)
        }

        // Add styles for different POI types
        kml += """

            <!-- Styles for different POI categories -->
            <Style id="cabin-style">
              <IconStyle>
                <color>ff0000ff</color>
                <scale>1.2</scale>
                <Icon>
                  <href>http://maps.google.com/mapfiles/kml/shapes/lodging.png</href>
                </Icon>
              </IconStyle>
              <LabelStyle>
                <color>ff0000ff</color>
                <scale>0.8</scale>
              </LabelStyle>
            </Style>
            <Style id="peak-style">
              <IconStyle>
                <color>ff00aa00</color>
                <scale>1.2</scale>
                <Icon>
                  <href>http://maps.google.com/mapfiles/kml/shapes/triangle.png</href>
                </Icon>
              </IconStyle>
              <LabelStyle>
                <color>ff00aa00</color>
                <scale>0.8</scale>
              </LabelStyle>
            </Style>
            <Style id="lake-style">
              <IconStyle>
                <color>ffff6600</color>
                <scale>1.1</scale>
                <Icon>
                  <href>http://maps.google.com/mapfiles/kml/shapes/water.png</href>
                </Icon>
              </IconStyle>
              <LabelStyle>
                <color>ffff6600</color>
                <scale>0.8</scale>
              </LabelStyle>
            </Style>
            <Style id="beach-style">
              <IconStyle>
                <color>ff00ffff</color>
                <scale>1.1</scale>
                <Icon>
                  <href>http://maps.google.com/mapfiles/kml/shapes/beach.png</href>
                </Icon>
              </IconStyle>
              <LabelStyle>
                <color>ff00ffff</color>
                <scale>0.8</scale>
              </LabelStyle>
            </Style>
            <Style id="default-style">
              <IconStyle>
                <color>ffaa00ff</color>
                <scale>1.0</scale>
                <Icon>
                  <href>http://maps.google.com/mapfiles/kml/pushpin/purple-pushpin.png</href>
                </Icon>
              </IconStyle>
              <LabelStyle>
                <color>ffaa00ff</color>
                <scale>0.8</scale>
              </LabelStyle>
            </Style>
        """

        // Add folders for each POI category
        for (category, categoryPOIs) in groupedPOIs.sorted(by: { $0.key < $1.key }) {
            kml += "\n    <Folder>"
            kml += "\n      <name>\(xmlEscape(category)) (\(categoryPOIs.count))</name>"
            kml += "\n      <description>Collection of \(categoryPOIs.count) \(category.lowercased())</description>"

            // Sort POIs within category by name
            let sortedPOIs = categoryPOIs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            for poi in sortedPOIs {
                let styleId = getStyleId(for: category)

                kml += """

                      <Placemark>
                        <name>\(xmlEscape(poi.name))</name>
                        <description><![CDATA[
                """

                // Add description if available
                if !poi.description.isEmpty {
                    kml += "\n          <h3>Description</h3>\n          <p>\(poi.description)</p>"
                }

                // Add coordinate information
                kml += """

                          <h3>Location</h3>
                          <p><strong>Latitude:</strong> \(String(format: "%.6f", poi.latitude))°</p>
                          <p><strong>Longitude:</strong> \(String(format: "%.6f", poi.longitude))°</p>
                """

                // Add elevation if available
                if let elevation = poi.elevation, elevation > 0 {
                    kml += "\n          <p><strong>Elevation:</strong> \(Int(elevation)) meters</p>"
                }

                // Add symbol information if available
                if let symbol = poi.symbol {
                    kml += "\n          <p><strong>Symbol:</strong> \(symbol)</p>"
                }

                // Add coordinates link for easy copying
                kml += "\n          <p><a href=\"https://maps.google.com/?q=\(poi.latitude),\(poi.longitude)\" target=\"_blank\">View on Google Maps</a></p>"

                kml += """
                        ]]></description>
                        <styleUrl>#\(styleId)</styleUrl>
                        <Point>
                          <coordinates>\(poi.longitude),\(poi.latitude)\(poi.elevation.map { ",\($0)" } ?? "")</coordinates>
                        </Point>
                      </Placemark>
                """
            }

            kml += "\n    </Folder>"
        }

        kml += "\n  </Document>\n</kml>"
        return kml
    }

    /// Classify POI into category based on name and properties
    private static func classifyPOI(_ poi: POI) -> String {
        let name = poi.name.lowercased()
        let description = poi.description.lowercased()

        // Check for cabins and lodges
        if name.contains("hytte") || name.contains("hut") || name.contains("cabin") ||
           name.contains("lodge") || name.contains("shelter") ||
           description.contains("cabin") || description.contains("hut") {
            return "Cabins & Lodges"
        }

        // Check for mountain peaks
        if name.contains("peak") || name.contains("topp") || name.contains("fjell") ||
           name.contains("berg") || name.contains("summit") || name.contains("mountain") ||
           description.contains("peak") || description.contains("summit") {
            return "Mountain Peaks"
        }

        // Check for lakes and water bodies
        if name.contains("lake") || name.contains("tjern") || name.contains("vatn") ||
           name.contains("sjø") || name.contains("pond") || name.contains("reservoir") ||
           description.contains("lake") || description.contains("water") {
            return "Lakes & Water Bodies"
        }

        // Check for beaches and coastal areas
        if name.contains("beach") || name.contains("strand") || name.contains("bay") ||
           name.contains("coast") || name.contains("shore") ||
           description.contains("beach") || description.contains("coastal") {
            return "Beaches & Coast"
        }

        // Check for trails and paths
        if name.contains("trail") || name.contains("path") || name.contains("sti") ||
           name.contains("route") || name.contains("track") ||
           description.contains("trail") || description.contains("path") {
            return "Trails & Paths"
        }

        // Check for viewpoints and scenic spots
        if name.contains("view") || name.contains("utsikt") || name.contains("scenic") ||
           name.contains("overlook") || name.contains("lookout") ||
           description.contains("view") || description.contains("scenic") {
            return "Viewpoints"
        }

        return "Other Points of Interest"
    }

    /// Get appropriate style ID for POI category
    private static func getStyleId(for category: String) -> String {
        switch category {
        case "Cabins & Lodges":
            return "cabin-style"
        case "Mountain Peaks":
            return "peak-style"
        case "Lakes & Water Bodies":
            return "lake-style"
        case "Beaches & Coast":
            return "beach-style"
        default:
            return "default-style"
        }
    }

    /// Escape XML special characters
    private static func xmlEscape(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
