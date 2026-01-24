//
//  StoreDetailViewModel.swift
//  watchify
//

import Foundation

/// ViewModel for StoreDetailView. Runs on MainActor, communicates with
/// StoreService via Sendable DTOs for background data fetching.
@MainActor @Observable
final class StoreDetailViewModel {
    // MARK: - Published State

    private(set) var products: [ProductDTO] = []
    private(set) var isLoading = false
    private(set) var filteredCount: Int = 0
    private(set) var totalCount: Int = 0

    // Store metadata (passed from parent, used for display)
    let storeId: UUID
    private(set) var storeName: String
    private(set) var storeDomain: String
    private(set) var lastFetchedAt: Date?
    private(set) var isSyncing: Bool = false

    // Error state
    private(set) var rateLimitRetryAfter: TimeInterval?
    private(set) var syncError: SyncError?

    // MARK: - Filters

    var searchText: String = "" {
        didSet {
            if oldValue != searchText {
                Task { await fetchProducts() }
            }
        }
    }

    var stockScope: StockScope = .all {
        didSet {
            if oldValue != stockScope {
                Task { await fetchProducts() }
            }
        }
    }

    var sortOrder: ProductSort = .name {
        didSet {
            if oldValue != sortOrder {
                Task { await fetchProducts() }
            }
        }
    }

    // MARK: - Computed Properties

    var hasActiveFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || stockScope != .all
            || sortOrder != .name
    }

    var subtitleText: String {
        let countPart: String = hasActiveFilters
            ? "\(filteredCount) of \(totalCount) products"
            : "\(totalCount) products"

        let syncPart: String = {
            if let lastFetched = lastFetchedAt {
                return "Synced \(lastFetched.formatted(.relative(presentation: .named)))"
            } else {
                return "Never synced"
            }
        }()

        return "\(storeDomain) · \(countPart) · \(syncPart)"
    }

    // MARK: - Initialization

    init(storeId: UUID, name: String, domain: String, lastFetchedAt: Date?, isSyncing: Bool, cachedProductCount: Int) {
        self.storeId = storeId
        self.storeName = name
        self.storeDomain = domain
        self.lastFetchedAt = lastFetchedAt
        self.isSyncing = isSyncing
        self.totalCount = cachedProductCount
    }

    // MARK: - Public Methods

    /// Loads initial data.
    func loadInitial() async {
        // totalCount is set from cachedProductCount in init - no DB call needed
        await fetchProducts()
    }

    /// Fetches products with current filters.
    func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }

        // Capture filter state for background task
        let id = storeId
        let search = searchText
        let scope = stockScope
        let sort = sortOrder
        let needsFilteredCount = hasActiveFilters

        // CRITICAL: Use Task.detached for StoreService calls to avoid deadlock.
        // SwiftData's ModelActor uses performBlockAndWait which blocks if main
        // thread awaits while actor is mid-save.
        let (fetchedProducts, fetchedCount) = await Task.detached {
            let request = ProductFetchRequest(
                storeId: id,
                searchText: search,
                stockScope: scope,
                sortOrder: sort,
                offset: 0,
                limit: 10000
            )
            let products = await StoreService.shared.fetchProducts(request)

            let count: Int
            if needsFilteredCount {
                count = await StoreService.shared.fetchProductCount(
                    storeId: id,
                    searchText: search,
                    stockScope: scope
                )
            } else {
                count = -1  // Sentinel: use totalCount
            }

            return (products, count)
        }.value

        products = fetchedProducts
        filteredCount = fetchedCount >= 0 ? fetchedCount : totalCount
    }

    /// Syncs the store and refreshes products.
    func sync() async {
        rateLimitRetryAfter = nil
        syncError = nil

        // Check network connectivity first
        if !NetworkMonitor.shared.isConnected {
            syncError = .networkUnavailable
            return
        }

        isSyncing = true

        let id = storeId

        do {
            // CRITICAL: Use Task.detached for StoreService calls to avoid deadlock.
            let changes = try await Task.detached {
                try await StoreService.shared.syncStore(storeId: id)
            }.value
            await NotificationService.shared.sendIfAuthorized(for: changes)

            // Refresh counts and products (also via detached)
            let newCount = await Task.detached {
                await StoreService.shared.fetchTotalProductCount(storeId: id)
            }.value
            totalCount = newCount
            await fetchProducts()

            // Update lastFetchedAt
            lastFetchedAt = Date()
        } catch let error as SyncError {
            if case .rateLimited(let retryAfter) = error {
                rateLimitRetryAfter = retryAfter
            } else {
                syncError = error
            }
        } catch {
            syncError = SyncError.from(error)
        }

        isSyncing = false
    }

    /// Dismisses the rate limit banner.
    func dismissRateLimitBanner() {
        rateLimitRetryAfter = nil
    }

    /// Dismisses the sync error alert.
    func dismissSyncError() {
        syncError = nil
    }
}
