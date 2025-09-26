//
//  GPXPOIToolApp.swift
//  GPX POI Tool
//
//  Created on 26.09.2025
//

import SwiftUI

@main
struct GPXPOIToolApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // Add custom menu commands
            CommandGroup(after: .newItem) {
                Button("Import GPX Files...") {
                    // This will be handled by the ContentView
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
