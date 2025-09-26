//
//  POIListView.swift
//  GPX POI Tool
//
//  Created on 26.09.2025
//

import SwiftUI

struct POIListView: View {
    let pois: [POI]
    @Binding var selectedPOI: POI?
    @State private var sortOrder: SortOrder = .name

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case elevation = "Elevation"
        case latitude = "Latitude"
        case longitude = "Longitude"

        var systemImage: String {
            switch self {
            case .name: return "textformat"
            case .elevation: return "mountain.2"
            case .latitude: return "globe.americas"
            case .longitude: return "globe.europe.africa"
            }
        }
    }

    private var sortedPOIs: [POI] {
        switch sortOrder {
        case .name:
            return pois.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .elevation:
            return pois.sorted { ($0.elevation ?? 0) > ($1.elevation ?? 0) }
        case .latitude:
            return pois.sorted { $0.latitude > $1.latitude }
        case .longitude:
            return pois.sorted { $0.longitude < $1.longitude }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sort controls
            HStack {
                Text("Sort by:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Sort Order", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Label(order.rawValue, systemImage: order.systemImage)
                            .tag(order)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            // POI List
            if sortedPOIs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 30))
                        .foregroundStyle(.tertiary)

                    Text("No POIs to display")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(sortedPOIs, id: \.id, selection: $selectedPOI) { poi in
                    POIRow(poi: poi, isSelected: selectedPOI?.id == poi.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPOI = poi
                        }
                }
                .listStyle(.sidebar)
            }
        }
    }
}

// MARK: - POI Row

struct POIRow: View {
    let poi: POI
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // POI Type Icon
                Image(systemName: poi.mapSymbol)
                    .foregroundStyle(poiColor)
                    .frame(width: 16)

                // POI Name
                Text(poi.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                // Elevation badge
                if let elevation = poi.elevation, elevation > 0 {
                    Text("\(Int(elevation))m")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                }
            }

            // Description (if available)
            if !poi.description.isEmpty {
                Text(poi.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Coordinates
            HStack {
                Text("\(String(format: "%.4f", poi.latitude)), \(String(format: "%.4f", poi.longitude))")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)

                Spacer()

                // Extensions indicator
                if poi.extensions != nil {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }

    private var poiColor: Color {
        switch poi.mapColor {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        default: return .purple
        }
    }
}

// MARK: - POI Statistics View

struct POIStatisticsView: View {
    let pois: [POI]

    private var statistics: (total: Int, withElevation: Int, categories: [String: Int]) {
        let total = pois.count
        let withElevation = pois.count { poi in
            poi.elevation != nil && poi.elevation! > 0
        }

        var categories: [String: Int] = [:]
        for poi in pois {
            let category = categorize(poi)
            categories[category, default: 0] += 1
        }

        return (total, withElevation, categories)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Collection Statistics")
                .font(.headline)
                .fontWeight(.semibold)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Total POIs:")
                        .fontWeight(.medium)
                    Text("\(statistics.total)")
                        .foregroundStyle(.secondary)
                }

                GridRow {
                    Text("With Elevation:")
                        .fontWeight(.medium)
                    Text("\(statistics.withElevation)")
                        .foregroundStyle(.secondary)
                }

                if !statistics.categories.isEmpty {
                    Divider()
                        .gridCellColumns(2)

                    ForEach(Array(statistics.categories.sorted(by: { $0.value > $1.value })), id: \.key) { category, count in
                        GridRow {
                            Text("\(category):")
                                .fontWeight(.medium)
                            Text("\(count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .font(.caption)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func categorize(_ poi: POI) -> String {
        let name = poi.name.lowercased()

        if name.contains("hytte") || name.contains("hut") || name.contains("cabin") {
            return "Cabins"
        } else if name.contains("peak") || name.contains("topp") || name.contains("fjell") {
            return "Peaks"
        } else if name.contains("lake") || name.contains("tjern") || name.contains("vatn") {
            return "Lakes"
        } else if name.contains("beach") || name.contains("strand") {
            return "Beaches"
        } else {
            return "Other"
        }
    }
}

// MARK: - Collection Extension

extension Collection {
    func count(where predicate: (Element) throws -> Bool) rethrows -> Int {
        return try self.filter(predicate).count
    }
}

#Preview {
    POIListView(
        pois: [
            POI(name: "Slivasshytta", description: "DNT cabin in the mountains", latitude: 61.29735, longitude: 9.62850, elevation: 1200),
            POI(name: "Galdhøpiggen", description: "Highest peak in Norway", latitude: 61.63639, longitude: 8.31278, elevation: 2469),
            POI(name: "Bessvatnet", description: "Mountain lake", latitude: 61.53000, longitude: 8.17000)
        ],
        selectedPOI: .constant(nil)
    )
}
