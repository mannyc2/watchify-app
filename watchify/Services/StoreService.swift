//
//  StoreService.swift
//  watchify
//

import Foundation
import OSLog
import SwiftData

// MARK: - Errors

enum SyncError: Error, LocalizedError {
    case storeNotFound
    case rateLimited(retryAfter: TimeInterval)
    case networkUnavailable
    case networkTimeout
    case serverError(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .storeNotFound:
            return String(localized: "Store not found")
        case .rateLimited:
            return String(localized: "Sync limited")
        case .networkUnavailable:
            return String(localized: "No connection")
        case .networkTimeout:
            return String(localized: "Connection timed out")
        case .serverError:
            return String(localized: "Server error")
        case .invalidResponse:
            return String(localized: "Invalid response")
        }
    }

    var failureReason: String? {
        switch self {
        case .storeNotFound:
            return String(localized: "We couldn't find a store with that address.")
        case .rateLimited(let seconds):
            let rounded = Int(seconds.rounded(.up))
            return String(localized: "Please wait \(rounded) seconds before syncing again.")
        case .networkUnavailable:
            return String(localized: "Your device appears to be offline.")
        case .networkTimeout:
            return String(localized: "The request took too long to complete.")
        case .serverError(let statusCode):
            return String(localized: "The server returned an error (\(statusCode)).")
        case .invalidResponse:
            return String(localized: "The server returned unexpected data.")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .storeNotFound:
            return String(localized: "Check the domain and try again.")
        case .rateLimited:
            return String(localized: "Try again after the countdown completes.")
        case .networkUnavailable:
            return String(localized: "Check your internet connection and try again.")
        case .networkTimeout:
            return String(localized: "Try again when your connection improves.")
        case .serverError:
            return String(localized: "The store may be temporarily unavailable. Try again later.")
        case .invalidResponse:
            return String(localized: "The store may have changed its product feed format.")
        }
    }

    var iconName: String {
        switch self {
        case .storeNotFound:
            return "storefront.circle"
        case .rateLimited:
            return "clock"
        case .networkUnavailable:
            return "wifi.slash"
        case .networkTimeout:
            return "clock.badge.exclamationmark"
        case .serverError:
            return "exclamationmark.icloud"
        case .invalidResponse:
            return "exclamationmark.triangle"
        }
    }

    /// Converts a generic Error to a SyncError.
    static func from(_ error: Error) -> SyncError {
        if let syncError = error as? SyncError {
            return syncError
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .timedOut:
                return .networkTimeout
            default:
                return .invalidResponse
            }
        }

        if let apiError = error as? ShopifyAPIError {
            switch apiError {
            case .invalidResponse:
                return .invalidResponse
            case .httpError(let statusCode):
                if (500...599).contains(statusCode) {
                    return .serverError(statusCode: statusCode)
                }
                return .invalidResponse
            }
        }

        return .invalidResponse
    }
}

// MARK: - StoreService

/// Background actor for all SwiftData operations.
/// Implements ModelActor manually to support dependency injection for testing.
/// Use `StoreService.create(container:)` to ensure background execution.
actor StoreService: ModelActor {
    // MARK: - Shared Instance

    /// Global shared instance. Marked nonisolated to avoid MainActor hop on access
    /// (with -default-isolation=MainActor, static vars are implicitly @MainActor).
    nonisolated(unsafe) static var shared: StoreService!

    // MARK: - ModelActor Protocol

    nonisolated let modelExecutor: any ModelExecutor
    nonisolated let modelContainer: ModelContainer

    // MARK: - Dependencies

    nonisolated let api: ShopifyAPIProtocol

    // MARK: - Initialization

    /// Private init - use `makeBackground(container:api:)` factory method instead.
    private init(container: ModelContainer, api: ShopifyAPIProtocol) {
        let context = ModelContext(container)
        context.autosaveEnabled = false  // Prevent cascading saves during bulk work
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.modelContainer = container
        self.api = api
    }

    /// Creates a StoreService that executes on a background thread.
    /// CRITICAL: The actor init MUST run off-main to get a private-queue ModelContext.
    @concurrent
    static func makeBackground(
        container: ModelContainer,
        api: ShopifyAPIProtocol? = nil
    ) async -> StoreService {
        let resolvedAPI = api ?? ShopifyAPI()
        return StoreService(container: container, api: resolvedAPI)
    }

    // MARK: - Store Management

    /// Adds a new store and fetches its initial products.
    /// Returns the store's UUID (model objects can't cross actor boundaries).
    func addStore(name: String?, domain: String) async throws -> UUID {
        let products = try await api.fetchProducts(domain: domain)

        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalName = trimmed.isEmpty ? deriveName(from: domain) : trimmed

        let store = Store(name: finalName, domain: domain)
        modelContext.insert(store)

        let result = await saveProducts(products, to: store, isInitialImport: true)
        store.lastFetchedAt = Date()
        store.updateListingCache(products: result.activeProducts)

        try modelContext.save()
        return store.id
    }

    /// Syncs a store by its ID, returning DTOs for any changes detected.
    @discardableResult
    func syncStore(storeId: UUID) async throws -> [ChangeEventDTO] {
        let predicate = #Predicate<Store> { $0.id == storeId }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        let store = try modelContext.fetch(descriptor).first
        guard let store else { throw SyncError.storeNotFound }

        // Rate limit check: 60s minimum between syncs
        let minInterval: TimeInterval = 60
        if let lastFetch = store.lastFetchedAt {
            let elapsed = Date().timeIntervalSince(lastFetch)
            if elapsed < minInterval {
                throw SyncError.rateLimited(retryAfter: minInterval - elapsed)
            }
        }

        store.isSyncing = true
        try modelContext.save()

        defer {
            store.isSyncing = false
            try? modelContext.save()
        }

        let shopifyProducts = try await api.fetchProducts(domain: store.domain)
        let result = await saveProducts(shopifyProducts, to: store, isInitialImport: false)

        store.lastFetchedAt = Date()
        store.updateListingCache(products: result.activeProducts)

        try modelContext.save()
        return result.changes.map { ChangeEventDTO(from: $0) }
    }

    /// Syncs all stores. Used by the background sync loop.
    func syncAllStores() async {
        do {
            let stores = try modelContext.fetch(FetchDescriptor<Store>())
            guard !stores.isEmpty else { return }

            for store in stores {
                // Yield between stores to allow other background work to progress
                await Task.yield()

                do {
                    try await syncStore(storeId: store.id)
                } catch {
                    Log.sync.error("Failed to sync \(store.name): \(error)")
                }
            }

            // Auto-delete old events if enabled
            if UserDefaults.standard.bool(forKey: "autoDeleteEvents") {
                let days = UserDefaults.standard.integer(forKey: "eventRetentionDays")
                if days > 0,
                   let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) {
                    let predicate = #Predicate<ChangeEvent> { $0.occurredAt < cutoff }
                    try? modelContext.delete(model: ChangeEvent.self, where: predicate)
                }
            }

            // Auto-delete old snapshots if enabled
            if UserDefaults.standard.bool(forKey: "autoDeleteSnapshots") {
                let days = UserDefaults.standard.integer(forKey: "snapshotRetentionDays")
                if days > 0,
                   let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) {
                    try? deleteOldSnapshots(olderThan: cutoff)
                }
            }
        } catch {
            Log.sync.error("Failed to fetch stores: \(error)")
        }
    }

    // MARK: - Cleanup

    /// Deletes snapshots older than the specified date
    func deleteOldSnapshots(olderThan cutoff: Date) throws {
        // Batch delete doesn't work due to mandatory relationship constraint
        // Fetch and delete individually instead
        let predicate = #Predicate<VariantSnapshot> { $0.capturedAt < cutoff }
        let descriptor = FetchDescriptor(predicate: predicate)
        let snapshots = try modelContext.fetch(descriptor)
        for snapshot in snapshots {
            modelContext.delete(snapshot)
        }
        try modelContext.save()
    }

    /// Returns the count of all snapshots. Used for testing.
    func snapshotCount() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<VariantSnapshot>())
    }

    // MARK: - Private Helpers

    private func deriveName(from domain: String) -> String {
        domain.split(separator: ".").first.map(String.init) ?? domain
    }
}
