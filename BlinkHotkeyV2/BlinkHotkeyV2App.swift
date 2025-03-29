//
//  BlinkHotkeyV2App.swift
//  BlinkHotkeyV2
//
//  Created by Kaushik Manian on 30/3/25.
//

import SwiftUI
import SwiftData

@main
struct BlinkHotkeyV2App: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
