//
//  ContentView.swift
//  GPX POI Tool
//
//  Created on 26.09.2025
//

import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var gpxProcessor = GPXProcessor()
    @State private var selectedPOI: POI?
    @State private var isFileImporterPresented = false
    @State private var searchText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isProcessing = false

    var filteredPOIs: [POI] {
        if searchText.isEmpty {
            return gpxProcessor.pois
        }
        return gpxProcessor.pois.filter { poi in
            poi.name.localizedCaseInsensitiveContains(searchText) ||
            poi.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar with POI list
            VStack(alignment: .leading, spacing: 0) {
                // Header with search and import
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("GPX POI Tool")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Spacer()

                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    HStack(spacing: 8) {
                        Button("Import GPX") {
                            isFileImporterPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isProcessing)

                        Button("Export KML") {
                            exportKML()
                        }
                        .buttonStyle(.bordered)
                        .disabled(gpxProcessor.pois.isEmpty || isProcessing)

                        Button("Dedupe") {
                            deduplicatePOIs()
                        }
                        .buttonStyle(.bordered)
                        .disabled(gpxProcessor.pois.isEmpty || isProcessing)
                    }

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search POIs...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("\(filteredPOIs.count) of \(gpxProcessor.pois.count) POIs")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if !gpxProcessor.lastProcessingResult.isEmpty {
                            Text(gpxProcessor.lastProcessingResult)
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding()

                Divider()

                // POI List
                POIListView(
                    pois: filteredPOIs,
                    selectedPOI: $selectedPOI
                )
            }
            .frame(minWidth: 350, maxWidth: 450)
        } detail: {
            // Main map view
            Group {
                if gpxProcessor.pois.isEmpty {
                    EmptyStateView {
                        isFileImporterPresented = true
                    }
                } else {
                    MapView(
                        pois: filteredPOIs,
                        selectedPOI: $selectedPOI
                    )
                }
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.init(filenameExtension: "gpx")!],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .alert("Processing Result", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDroppedFiles(providers)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !gpxProcessor.pois.isEmpty {
                    Button("Add Elevation") {
                        addElevationData()
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }

    // MARK: - Actions

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            processGPXFiles(urls)
        case .failure(let error):
            showAlert("Import failed: \(error.localizedDescription)")
        }
    }

    private func handleDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url, url.pathExtension.lowercased() == "gpx" {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                processGPXFiles(urls)
            }
        }

        return !providers.isEmpty
    }

    private func processGPXFiles(_ urls: [URL]) {
        isProcessing = true

        Task {
            do {
                let result = try await gpxProcessor.importGPXFiles(urls)
                await MainActor.run {
                    showAlert("Imported \(result.added) POIs, merged \(result.merged) duplicates")
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    showAlert("Import failed: \(error.localizedDescription)")
                    isProcessing = false
                }
            }
        }
    }

    private func exportKML() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "kml")!]
        panel.nameFieldStringValue = "POI Collection.kml"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                do {
                    try await gpxProcessor.exportKML(to: url)
                    await MainActor.run {
                        showAlert("KML exported successfully to \(url.lastPathComponent)")
                    }
                } catch {
                    await MainActor.run {
                        showAlert("Export failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func deduplicatePOIs() {
        let removed = gpxProcessor.deduplicate()
        showAlert("Removed \(removed) duplicate POIs")
    }

    private func addElevationData() {
        isProcessing = true

        Task {
            do {
                let count = try await gpxProcessor.addElevationData()
                await MainActor.run {
                    showAlert("Added elevation data to \(count) POIs")
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    showAlert("Elevation lookup failed: \(error.localizedDescription)")
                    isProcessing = false
                }
            }
        }
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "map")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Import GPX Files to Get Started")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("Drag and drop GPX files here or use the Import button")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Import GPX Files") {
                onImport()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background.secondary.opacity(0.3))
    }
}

#Preview {
    ContentView()
}
