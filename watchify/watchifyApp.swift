//
//  watchifyApp.swift
//  watchify
//
//  Created by cjpher on 1/19/26.
//

import OSLog
import SwiftData
import SwiftUI
import TipKit

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

// MARK: - Background Sync Helper

/// Syncs all stores and tracks errors in BackgroundSyncState.
/// Called from background Task.detached, so must hop to MainActor for state updates.
/// Explicitly nonisolated to be callable from any context.
nonisolated func syncAllStoresWithErrorTracking() async {
    // Fetch store IDs (UUIDs are Sendable, Store objects are not)
    let storeIds = await StoreService.shared.fetchAllStoreIds()

    for storeId in storeIds {
        do {
            _ = try await StoreService.shared.syncStore(storeId: storeId)

            // Record success on main actor
            await MainActor.run {
                BackgroundSyncState.shared.recordSuccess(forStore: storeId)
            }
        } catch let error as SyncError {
            // Skip rate limit errors silently - they're expected during rapid syncs
            if case .rateLimited = error {
                continue
            }

            // Record error on main actor
            await MainActor.run {
                BackgroundSyncState.shared.recordError(error, forStore: storeId)
            }
            Log.sync.error("Background sync failed for store \(storeId): \(error)")
        } catch {
            let syncError = SyncError.from(error)
            await MainActor.run {
                BackgroundSyncState.shared.recordError(syncError, forStore: storeId)
            }
            Log.sync.error("Background sync failed for store \(storeId): \(error)")
        }
    }
}

// MARK: - App

@main
struct WatchifyApp: App {
    let container: ModelContainer
    @State private var unreadObserver = UnreadCountObserver()
    @State private var isReady = false

    /// Whether running in UI test mode (in-memory database)
    static let isUITesting = CommandLine.arguments.contains("-UITesting")

    init() {
        do {
            // Use in-memory store for UI testing to isolate from real data
            if Self.isUITesting {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                container = try ModelContainer(
                    for: Store.self, Product.self, Variant.self, VariantSnapshot.self, ChangeEvent.self,
                    configurations: config
                )
            } else {
                container = try ModelContainer(for: Store.self, Product.self,
                    Variant.self, VariantSnapshot.self, ChangeEvent.self)
            }
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Configure TipKit for contextual tips
        try? Tips.configure([
            .displayFrequency(.daily)
        ])
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
                // Start network monitoring
                NetworkMonitor.shared.start()

                // Initialize StoreService before showing ContentView
                if StoreService.shared == nil {
                    StoreService.shared = await StoreService.makeBackground(container: container)
                }

                // Seed mock data for UI tests if requested
                if Self.isUITesting {
                    await Task.detached {
                        await StoreService.shared.seedTestDataIfNeeded()
                    }.value
                }

                isReady = true

                // Skip background sync loop during UI testing
                guard !Self.isUITesting else { return }

                // Start background sync loop
                Task.detached(priority: .utility) {
                    Log.sync.info("SyncLoop START \(ThreadInfo.current)")
                    let intervalMinutes = UserDefaults.standard.integer(forKey: "syncIntervalMinutes")
                    let interval = max(intervalMinutes, 5) * 60 // minimum 5 minutes

                    while !Task.isCancelled {
                        Log.sync.info("SyncLoop BEFORE_SYNC \(ThreadInfo.current)")
                        await syncAllStoresWithErrorTracking()
                        Log.sync.info("SyncLoop AFTER_SYNC \(ThreadInfo.current)")
                        try? await Task.sleep(for: .seconds(interval))
                    }
                }
            }
            .onAppear {
                unreadObserver.configure()
            }
        }
        .commands {
            AppCommands()
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
