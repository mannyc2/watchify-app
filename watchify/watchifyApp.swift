//
//  watchifyApp.swift
//  watchify
//
//  Created by cjpher on 1/19/26.
//

import SwiftData
import SwiftUI

// MARK: - Unread Count Observer

@MainActor
@Observable
final class UnreadCountObserver {
    private var container: ModelContainer?
    private(set) var count: Int = 0

    func configure(with container: ModelContainer) {
        self.container = container
        updateCount()

        // Observe changes via NotificationCenter
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let observer = self
            Task { @MainActor in
                observer?.updateCount()
            }
        }
    }

    private func updateCount() {
        guard let container else { return }
        let context = ModelContext(container)
        let predicate = #Predicate<ChangeEvent> { !$0.isRead }
        let descriptor = FetchDescriptor(predicate: predicate)
        count = (try? context.fetchCount(descriptor)) ?? 0
    }
}

// MARK: - App

@main
struct WatchifyApp: App {
    let container: ModelContainer
    @State private var unreadObserver = UnreadCountObserver()

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
        WindowGroup(id: "main") {
            ContentView()
                .environment(SyncScheduler.shared)
                .task {
                    // Starts sync loop - auto-cancelled when scene disappears
                    await SyncScheduler.shared.startBackgroundSync()
                }
                .onAppear {
                    unreadObserver.configure(with: container)
                }
        }
        .modelContainer(container)

        #if os(macOS)
        Settings {
            SettingsView()
                .modelContainer(container)
        }

        MenuBarExtra {
            MenuBarView()
                .modelContainer(container)
        } label: {
            Image(systemName: unreadObserver.count > 0 ? "bell.badge.fill" : "bell.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(unreadObserver.count > 0 ? .red : .primary, .primary)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
