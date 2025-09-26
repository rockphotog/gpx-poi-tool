//
//  MapView.swift
//  GPX POI Tool
//
//  Created on 26.09.2025
//

import SwiftUI
import MapKit

struct MapView: View {
    let pois: [POI]
    @Binding var selectedPOI: POI?
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 61.0, longitude: 9.0), // Center of Norway
            span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
        )
    )

    var body: some View {
        Map(position: $position) {
            ForEach(pois) { poi in
                Annotation(poi.name, coordinate: poi.coordinate) {
                    POIMapPin(
                        poi: poi,
                        isSelected: selectedPOI?.id == poi.id
                    )
                    .onTapGesture {
                        selectedPOI = poi
                        withAnimation(.easeInOut(duration: 0.3)) {
                            position = .region(MKCoordinateRegion(
                                center: poi.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                            ))
                        }
                    }
                }
            }
        }
        .onAppear {
            updateRegionForPOIs()
        }
        .onChange(of: pois) {
            updateRegionForPOIs()
        }
        .onChange(of: selectedPOI) { _, poi in
            if let poi = poi {
                withAnimation(.easeInOut(duration: 0.5)) {
                    position = .region(MKCoordinateRegion(
                        center: poi.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    ))
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 8) {
                Button("Fit All") {
                    updateRegionForPOIs()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                if let selectedPOI = selectedPOI {
                    POIInfoPanel(poi: selectedPOI) {
                        self.selectedPOI = nil
                    }
                    .frame(maxWidth: 300)
                }
            }
            .padding()
        }
    }

    private func updateRegionForPOIs() {
        guard !pois.isEmpty else { return }

        let coordinates = pois.map { $0.coordinate }
        let mapRect = coordinates.reduce(MKMapRect.null) { rect, coord in
            let point = MKMapPoint(coord)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
            return rect.union(pointRect)
        }

        if !mapRect.isNull {
            let padding = 0.1 // Add 10% padding
            withAnimation(.easeInOut(duration: 0.8)) {
                position = .region(MKCoordinateRegion(mapRect.insetBy(dx: -mapRect.size.width * padding, dy: -mapRect.size.height * padding)))
            }
        }
    }
}

// MARK: - POI Map Pin

struct POIMapPin: View {
    let poi: POI
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(pinColor)
                    .frame(width: isSelected ? 24 : 18, height: isSelected ? 24 : 18)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

                Image(systemName: poi.mapSymbol)
                    .font(.system(size: isSelected ? 12 : 10, weight: .semibold))
                    .foregroundColor(.white)
            }

            if isSelected {
                Text(poi.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
            }
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }

    private var pinColor: Color {
        switch poi.mapColor {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        default: return .purple
        }
    }
}

// MARK: - POI Info Panel

struct POIInfoPanel: View {
    let poi: POI
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(poi.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if !poi.description.isEmpty {
                Text(poi.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                InfoRow(label: "Latitude", value: String(format: "%.6f", poi.latitude))
                InfoRow(label: "Longitude", value: String(format: "%.6f", poi.longitude))

                if let elevation = poi.elevation, elevation > 0 {
                    InfoRow(label: "Elevation", value: "\(Int(elevation))m")
                }

                if let symbol = poi.symbol {
                    InfoRow(label: "Symbol", value: symbol)
                }
            }
            .font(.caption)

            HStack {
                Button("Copy Coordinates") {
                    let coords = "\(poi.latitude),\(poi.longitude)"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(coords, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Open in Maps") {
                    openInMaps()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    private func openInMaps() {
        let placemark = MKPlacemark(coordinate: poi.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = poi.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue
        ])
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text("\(label):")
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    MapView(
        pois: [
            POI(name: "Test Cabin", description: "A test cabin in the mountains", latitude: 61.0, longitude: 9.0, elevation: 1200),
            POI(name: "Mountain Peak", description: "Highest peak in the area", latitude: 61.1, longitude: 9.1, elevation: 2000)
        ],
        selectedPOI: .constant(nil)
    )
}
