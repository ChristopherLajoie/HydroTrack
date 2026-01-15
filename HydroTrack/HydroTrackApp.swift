//
//  HydroTrackApp.swift
//  HydroTrack
//
//  Created by Christopher Lajoie on 2026-01-14.
//

import SwiftUI
import SwiftData

@main
struct HydroTrackApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WaterEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()  // Changed from ContentView()
        }
        .modelContainer(for: WaterEntry.self)
    }
}
