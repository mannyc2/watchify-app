//
//  SyncScheduler.swift
//  watchify
//

import Foundation
import SwiftData

@MainActor
@Observable
final class SyncScheduler {
    static let shared = SyncScheduler()

    // Observable state
    private(set) var isSyncing = false
    private(set) var lastSyncAt: Date?
    private(set) var syncingStores: Set<UUID> = []

    func isSyncing(_ store: Store) -> Bool {
        syncingStores.contains(store.id)
    }

    // Dependencies
    private var container: ModelContainer?
    @ObservationIgnored private var _storeService: StoreService?
    private var storeService: StoreService {
        if _storeService == nil {
            _storeService = StoreService()
        }
        return _storeService!
    }

    // Config - reads from UserDefaults (matches @AppStorage key in settings)
    var intervalMinutes: Int {
        UserDefaults.standard.integer(forKey: "syncIntervalMinutes").clamped(to: 5...1440, default: 30)
    }

    // Background activity token
    @ObservationIgnored private var activityToken: NSObjectProtocol?

    private init() {}

    func configure(with container: ModelContainer) {
        self.container = container
    }

    /// Start background sync loop using Task.sleep
    /// Call from .task modifier - cancellation is automatic
    func startBackgroundSync() async {
        // Prevent App Nap from throttling our timer
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: .userInitiated,
            reason: "Background sync timer"
        )

        while !Task.isCancelled {
            await syncAllStores()

            do {
                try await Task.sleep(for: .seconds(intervalMinutes * 60))
            } catch {
                // Task cancelled - exit loop
                break
            }
        }

        // Clean up activity token
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }

    func syncAllStores() async {
        guard !isSyncing else { return }
        guard let container else {
            print("[SyncScheduler] Not configured - call configure(with:) first")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let context = ModelContext(container)

        do {
            let stores = try context.fetch(FetchDescriptor<Store>())
            guard !stores.isEmpty else { return }

            for store in stores {
                syncingStores.insert(store.id)
                defer { syncingStores.remove(store.id) }
                do {
                    // syncStore handles notifications internally
                    try await storeService.syncStore(store, context: context)
                } catch {
                    print("[SyncScheduler] Failed to sync \(store.name): \(error)")
                }
            }

            // Auto-delete old events if enabled
            if UserDefaults.standard.bool(forKey: "autoDeleteEvents") {
                let days = UserDefaults.standard.integer(forKey: "eventRetentionDays")
                if days > 0,
                   let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) {
                    let predicate = #Predicate<ChangeEvent> { $0.occurredAt < cutoff }
                    try? context.delete(model: ChangeEvent.self, where: predicate)
                }
            }

            lastSyncAt = Date()
        } catch {
            print("[SyncScheduler] Failed to fetch stores: \(error)")
        }
    }
}

extension Int {
    fileprivate func clamped(to range: ClosedRange<Int>, default defaultValue: Int) -> Int {
        if self == 0 { return defaultValue }  // UserDefaults returns 0 if not set
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
