//
//  StoreService.swift
//  watchify
//

import Foundation
import OSLog
import SwiftData

// MARK: - Queue Diagnostics

extension DispatchQueue {
    nonisolated static var currentLabel: String {
        String(validatingUTF8: __dispatch_queue_get_label(nil)) ?? "unknown"
    }
}

// MARK: - Errors

enum SyncError: Error, LocalizedError {
    case storeNotFound
    case rateLimited(retryAfter: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .storeNotFound:
            return String(localized: "Store not found")
        case .rateLimited:
            return String(localized: "Sync limited")
        }
    }

    var failureReason: String? {
        switch self {
        case .storeNotFound:
            return String(localized: "We couldn't find a store with that address.")
        case .rateLimited(let seconds):
            let rounded = Int(seconds.rounded(.up))
            return String(localized: "Please wait \(rounded) seconds before syncing again.")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .storeNotFound:
            return String(localized: "Check the domain and try again.")
        case .rateLimited:
            return String(localized: "Try again after the countdown completes.")
        }
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

    // MARK: - Actor Diagnostics

    private var methodDepth = 0

    func entering(_ method: StaticString) -> CFAbsoluteTime {
        methodDepth += 1
        let threadInfo = ThreadInfo.current
        Log.sync.info(">>> \(method, privacy: .public) ENTER depth=\(self.methodDepth) \(threadInfo)")
        return CFAbsoluteTimeGetCurrent()
    }

    func exiting(_ method: StaticString, start: CFAbsoluteTime) {
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        // swiftlint:disable:next line_length
        Log.sync.info("<<< \(method, privacy: .public) EXIT depth=\(self.methodDepth) dt=\(elapsed, format: .fixed(precision: 4))s")
        methodDepth -= 1
    }

    func logContextState(_ label: StaticString) {
        modelContext.logState(label)
    }

    // MARK: - Initialization

    /// Private init - use `makeBackground(container:api:)` factory method instead.
    private init(container: ModelContainer, api: ShopifyAPIProtocol) {
        let context = ModelContext(container)
        context.autosaveEnabled = false  // Prevent cascading saves during bulk work
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.modelContainer = container
        self.api = api

        Log.sync.info("StoreService.init isMainThread=\(Thread.isMainThread) thread=\(Thread.current)")
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
        let methodStart = entering("addStore")
        defer { exiting("addStore", start: methodStart) }

        let products = try await api.fetchProducts(domain: domain)

        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalName = trimmed.isEmpty ? deriveName(from: domain) : trimmed

        let store = Store(name: finalName, domain: domain)
        modelContext.insert(store)

        _ = saveProducts(products, to: store, isInitialImport: true)
        store.lastFetchedAt = Date()
        store.updateListingCache(products: store.products)

        logContextState("addStore before save")
        try ActorTrace.contextOp("addStore-save", context: modelContext) {
            try modelContext.save()
        }
        logContextState("addStore after save")
        return store.id
    }

    /// Syncs a store by its ID, returning DTOs for any changes detected.
    @discardableResult
    // swiftlint:disable:next function_body_length
    func syncStore(storeId: UUID) async throws -> [ChangeEventDTO] {
        let methodStart = entering("syncStore")
        defer { exiting("syncStore", start: methodStart) }

        let startThread = ThreadInfo.current.description
        Log.sync.info("syncStore START storeId=\(storeId) \(startThread)")

        let predicate = #Predicate<Store> { $0.id == storeId }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        let store = try ActorTrace.contextOp("fetch-store", context: modelContext) {
            try modelContext.fetch(descriptor).first
        }
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
        let syncStart = CFAbsoluteTimeGetCurrent()
        logContextState("syncStore before save[isSyncing]")
        try ActorTrace.contextOp("syncStore-save-isSyncing", context: modelContext) {
            try modelContext.save()
        }
        logContextState("syncStore after save[isSyncing]")
        Log.sync.info("syncStore SAVE[isSyncing] dt=\(CFAbsoluteTimeGetCurrent() - syncStart)s")

        defer {
            store.isSyncing = false
            let deferStart = CFAbsoluteTimeGetCurrent()
            logContextState("syncStore before save[defer]")
            try? ActorTrace.contextOp("syncStore-save-defer", context: modelContext) {
                try modelContext.save()
            }
            logContextState("syncStore after save[defer]")
            Log.sync.info("syncStore SAVE[defer] dt=\(CFAbsoluteTimeGetCurrent() - deferStart)s")
        }

        let fetchStart = CFAbsoluteTimeGetCurrent()
        Log.sync.info("syncStore API_START \(ThreadInfo.current)")
        let shopifyProducts = try await api.fetchProducts(domain: store.domain)
        let apiFetchTime = CFAbsoluteTimeGetCurrent() - fetchStart
        Log.sync.info("syncStore API_END \(ThreadInfo.current) dt=\(apiFetchTime)s count=\(shopifyProducts.count)")

        let saveProductsStart = CFAbsoluteTimeGetCurrent()
        let changes = saveProducts(shopifyProducts, to: store, isInitialImport: false)
        let saveTime = CFAbsoluteTimeGetCurrent() - saveProductsStart
        Log.sync.info("syncStore saveProducts dt=\(saveTime)s changes=\(changes.count)")

        let cacheStart = CFAbsoluteTimeGetCurrent()
        store.lastFetchedAt = Date()
        store.updateListingCache(products: store.products)
        Log.sync.info("syncStore updateCache dt=\(CFAbsoluteTimeGetCurrent() - cacheStart)s")

        let finalSaveStart = CFAbsoluteTimeGetCurrent()
        Log.sync.info("syncStore SAVE[final] START \(ThreadInfo.current)")
        logContextState("syncStore before save[final]")
        try ActorTrace.contextOp("syncStore-save-final", context: modelContext) {
            try modelContext.save()
        }
        logContextState("syncStore after save[final]")
        let finalSaveTime = CFAbsoluteTimeGetCurrent() - finalSaveStart
        Log.sync.info("syncStore SAVE[final] END \(ThreadInfo.current) dt=\(finalSaveTime)s")

        Log.sync.info("syncStore END totalSync=\(CFAbsoluteTimeGetCurrent() - syncStart)s")
        return changes.map { ChangeEventDTO(from: $0) }
    }

    /// Syncs all stores. Used by the background sync loop.
    func syncAllStores() async {
        let methodStart = entering("syncAllStores")
        defer { exiting("syncAllStores", start: methodStart) }

        let threadDesc = ThreadInfo.current.description
        Log.sync.info("syncAllStores START \(threadDesc)")
        do {
            let stores = try ActorTrace.contextOp("fetch-stores", context: modelContext) {
                try modelContext.fetch(FetchDescriptor<Store>())
            }
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
                    _ = try? ActorTrace.contextOp("delete-old-events", context: modelContext) {
                        try modelContext.delete(model: ChangeEvent.self, where: predicate)
                    }
                }
            }

            let endThreadDesc = ThreadInfo.current.description
            Log.sync.info("syncAllStores END \(endThreadDesc)")
        } catch {
            Log.sync.error("Failed to fetch stores: \(error)")
        }
    }

    // MARK: - Private Helpers

    private func deriveName(from domain: String) -> String {
        domain.split(separator: ".").first.map(String.init) ?? domain
    }
}
