//
//  watchifyApp.swift
//  watchify
//
//  Created by cjpher on 1/19/26.
//

import OSLog
import SwiftData
import SwiftUI

// MARK: - Unread Count Observer

@MainActor
@Observable
final class UnreadCountObserver {
    private(set) var count: Int = 0
    private var updateTask: Task<Void, Never>?
    private var observer: NSObjectProtocol?

    func configure() {
        // Initial fetch through StoreService (avoids main-thread context)
        updateCountDebounced()

        // Observe changes via NotificationCenter with debouncing
        // CRITICAL: Use queue: nil to receive on posting thread, then async to main
        // to break the synchronous notification chain and avoid deadlock.
        // If we use queue: .main, the callback runs synchronously during save(),
        // and calling back to StoreService causes a deadlock.
        observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil  // Receive on posting thread
        ) { [weak self] _ in
            // Break out of notification delivery before touching actors
            DispatchQueue.main.async {
                Task { @MainActor [weak self] in
                    self?.updateCountDebounced()
                }
            }
        }
    }

    /// Debounced update to avoid thrashing during bulk sync.
    /// Cancels pending update and schedules a new one after 100ms.
    private func updateCountDebounced() {
        updateTask?.cancel()
        updateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled, let self else { return }

            // CRITICAL: Use detached task to call StoreService.
            // SwiftData's ModelActor executor deadlocks if main thread awaits
            // while the actor is in a blocking save operation.
            let newCount = await Task.detached {
                await StoreService.shared.fetchUnreadCount()
            }.value
            self.count = newCount
        }
    }

    func cleanup() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        updateTask?.cancel()
    }
}

// MARK: - App

@main
struct WatchifyApp: App {
    let container: ModelContainer
    @State private var unreadObserver = UnreadCountObserver()
    @State private var isReady = false

    init() {
        do {
            container = try ModelContainer(for: Store.self, Product.self,
                Variant.self, VariantSnapshot.self, ChangeEvent.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

    }

    var body: some Scene {
        WindowGroup(id: "main") {
            Group {
                if isReady {
                    ContentView(container: container)
                } else {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .task {
                // Initialize StoreService before showing ContentView
                if StoreService.shared == nil {
                    StoreService.shared = await StoreService.makeBackground(container: container)
                }
                isReady = true

                // Start background sync loop
                Task.detached(priority: .utility) {
                    Log.sync.info("SyncLoop START \(ThreadInfo.current)")
                    let intervalMinutes = UserDefaults.standard.integer(forKey: "syncIntervalMinutes")
                    let interval = max(intervalMinutes, 5) * 60 // minimum 5 minutes

                    while !Task.isCancelled {
                        Log.sync.info("SyncLoop BEFORE_SYNC \(ThreadInfo.current)")
                        await StoreService.shared.syncAllStores()
                        Log.sync.info("SyncLoop AFTER_SYNC \(ThreadInfo.current)")
                        try? await Task.sleep(for: .seconds(interval))
                    }
                }
            }
            .onAppear {
                unreadObserver.configure()
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }

        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: unreadObserver.count > 0 ? "bell.badge.fill" : "bell.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(unreadObserver.count > 0 ? .red : .primary, .primary)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
