//
//  watchifyApp.swift
//  watchify
//
//  Created by cjpher on 1/19/26.
//

import SwiftData
import SwiftUI

@main
struct WatchifyApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Store.self, Product.self,
                Variant.self, VariantSnapshot.self, ChangeEvent.self)
            SyncScheduler.shared.configure(with: container)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Starts sync loop - auto-cancelled when scene disappears
                    await SyncScheduler.shared.startBackgroundSync()
                }
        }
        .modelContainer(container)
    }
}
