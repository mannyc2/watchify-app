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

    // Dependencies
    private var container: ModelContainer?
    @ObservationIgnored private var _storeService: StoreService?
    private var storeService: StoreService {
        if _storeService == nil {
            _storeService = StoreService()
        }
        return _storeService!
    }

    // Config
    var intervalMinutes: Int = 60

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
                do {
                    // syncStore handles notifications internally
                    try await storeService.syncStore(store, context: context)
                } catch {
                    print("[SyncScheduler] Failed to sync \(store.name): \(error)")
                }
            }

            lastSyncAt = Date()
        } catch {
            print("[SyncScheduler] Failed to fetch stores: \(error)")
        }
    }
}
