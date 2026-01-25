//
//  StoreService+Events.swift
//  watchify
//

import Foundation
import OSLog
import SwiftData

// MARK: - ProductFetchRequest

/// Groups product fetch parameters to satisfy SwiftLint's function_parameter_count rule.
struct ProductFetchRequest: Sendable {
    let storeId: UUID
    let searchText: String
    let stockScope: StockScope
    let sortOrder: ProductSort
    let offset: Int
    let limit: Int
}

// MARK: - Activity Events

extension StoreService {
    /// Fetches activity events with filters, returning Sendable DTOs.
    /// All filtering is done in the database query.
    func fetchActivityEvents(
        storeId: UUID?,
        changeTypes: [ChangeType]?,
        startDate: Date?,
        offset: Int,
        limit: Int
    ) -> [ChangeEventDTO] {
        let predicate = buildEventPredicate(
            storeId: storeId, changeTypes: changeTypes, startDate: startDate)
        var descriptor = FetchDescriptor<ChangeEvent>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset

        do {
            let events = try modelContext.fetch(descriptor)

            // Batch-fetch product images to avoid N+1 queries
            let imageURLs = batchFetchProductImageURLs(for: events)

            return events.map { event in
                ChangeEventDTO(
                    from: event,
                    productImageURL: event.productShopifyId.flatMap { imageURLs[$0] }
                )
            }
        } catch {
            Log.db.error("fetchActivityEvents error: \(error)")
            return []
        }
    }

    /// Fetches all stores for the filter picker (sorted by name).
    func fetchStores() -> [StoreDTO] {
        let descriptor = FetchDescriptor<Store>(sortBy: [SortDescriptor(\.name)])

        do {
            let stores = try modelContext.fetch(descriptor)
            return stores.map { StoreDTO(from: $0) }
        } catch {
            Log.db.error("fetchStores error: \(error)")
            return []
        }
    }

    /// Fetches all store IDs. Returns Sendable UUIDs for cross-actor use.
    func fetchAllStoreIds() -> [UUID] {
        let descriptor = FetchDescriptor<Store>()

        do {
            let stores = try modelContext.fetch(descriptor)
            return stores.map(\.id)
        } catch {
            Log.db.error("fetchAllStoreIds error: \(error)")
            return []
        }
    }

    /// Fetches all stores for list display, sorted by addedAt descending.
    func fetchStoresForList() -> [StoreDTO] {
        let descriptor = FetchDescriptor<Store>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        do {
            let stores = try modelContext.fetch(descriptor)
            return stores.map { StoreDTO(from: $0) }
        } catch {
            Log.db.error("fetchStoresForList error: \(error)")
            return []
        }
    }

    /// Deletes a store by ID.
    func deleteStore(id: UUID) {
        let predicate = #Predicate<Store> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            if let store = try modelContext.fetch(descriptor).first {
                modelContext.delete(store)
                try modelContext.save()
                Log.db.debug("Deleted store id=\(id)")
            }
        } catch {
            Log.db.error("deleteStore error: \(error)")
        }
    }

    /// Marks a single event as read by ID.
    func markEventRead(id: UUID) {
        let predicate = #Predicate<ChangeEvent> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            if let event = try modelContext.fetch(descriptor).first {
                event.isRead = true
                try modelContext.save()
            }
        } catch {
            Log.db.error("markEventRead error: \(error)")
        }
    }

    /// Marks multiple events as read by their IDs.
    func markEventsRead(ids: [UUID]) {
        guard !ids.isEmpty else { return }

        let idSet = Set(ids)
        let predicate = #Predicate<ChangeEvent> { idSet.contains($0.id) }
        let descriptor = FetchDescriptor(predicate: predicate)

        do {
            let events = try modelContext.fetch(descriptor)
            for event in events where !event.isRead {
                event.isRead = true
            }
            try modelContext.save()
        } catch {
            Log.db.error("markEventsRead error: \(error)")
        }
    }

    /// Marks all events matching the current filters as read.
    /// All filtering is done in the database query.
    func markAllEventsRead(
        storeId: UUID?,
        changeTypes: [ChangeType]?,
        startDate: Date?
    ) {
        let predicate = buildEventPredicate(
            storeId: storeId, changeTypes: changeTypes, startDate: startDate)
        let descriptor = FetchDescriptor<ChangeEvent>(predicate: predicate)

        do {
            let events = try modelContext.fetch(descriptor)
            for event in events where !event.isRead {
                event.isRead = true
            }
            try modelContext.save()
        } catch {
            Log.db.error("markAllEventsRead error: \(error)")
        }
    }

    // MARK: - Menu Bar

    /// Fetches events for menu bar display: unread first, then recent.
    func fetchMenuBarEvents(limit: Int) -> [ChangeEventDTO] {
        let unreadPredicate = #Predicate<ChangeEvent> { !$0.isRead }
        var unreadDescriptor = FetchDescriptor<ChangeEvent>(
            predicate: unreadPredicate,
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        unreadDescriptor.fetchLimit = limit

        do {
            let unreadEvents = try modelContext.fetch(unreadDescriptor)

            if !unreadEvents.isEmpty {
                let imageURLs = batchFetchProductImageURLs(for: unreadEvents)
                return unreadEvents.map { event in
                    ChangeEventDTO(
                        from: event,
                        productImageURL: event.productShopifyId.flatMap { imageURLs[$0] }
                    )
                }
            }

            var recentDescriptor = FetchDescriptor<ChangeEvent>(
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            )
            recentDescriptor.fetchLimit = limit

            let recentEvents = try modelContext.fetch(recentDescriptor)
            let imageURLs = batchFetchProductImageURLs(for: recentEvents)
            return recentEvents.map { event in
                ChangeEventDTO(
                    from: event,
                    productImageURL: event.productShopifyId.flatMap { imageURLs[$0] }
                )
            }
        } catch {
            Log.db.error("MenuBar fetch error: \(error)")
            return []
        }
    }

    /// Returns the count of unread events.
    func fetchUnreadCount() -> Int {
        let predicate = #Predicate<ChangeEvent> { !$0.isRead }
        var descriptor = FetchDescriptor<ChangeEvent>(predicate: predicate)
        descriptor.propertiesToFetch = []

        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            Log.db.error("fetchUnreadCount error: \(error)")
            return 0
        }
    }

    /// Marks all unread events as read.
    func markAllUnreadEventsRead() {
        let predicate = #Predicate<ChangeEvent> { !$0.isRead }
        let descriptor = FetchDescriptor<ChangeEvent>(predicate: predicate)

        do {
            let events = try modelContext.fetch(descriptor)
            for event in events {
                event.isRead = true
            }
            try modelContext.save()
        } catch {
            Log.db.error("markAllUnreadEventsRead error: \(error)")
        }
    }

    /// Deletes all change events from the database.
    func deleteAllEvents() {
        do {
            try modelContext.delete(model: ChangeEvent.self)
            try modelContext.save()
            Log.db.info("Deleted all events")
        } catch {
            Log.db.error("deleteAllEvents error: \(error)")
        }
    }

    // MARK: - Products

    /// Fetches products for a store with filtering and sorting done in the database.
    func fetchProducts(_ request: ProductFetchRequest) -> [ProductDTO] {
        let query = request.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            // Build predicate based on filters
            let predicate = buildProductPredicate(
                storeId: request.storeId, query: query, stockScope: request.stockScope)
            let sortDescriptors = buildProductSortDescriptors(sortOrder: request.sortOrder)

            var descriptor = FetchDescriptor<Product>(predicate: predicate, sortBy: sortDescriptors)
            descriptor.fetchLimit = request.limit
            descriptor.fetchOffset = request.offset

            let products = try modelContext.fetch(descriptor)
            return products.map { ProductDTO(from: $0) }
        } catch {
            Log.db.error("fetchProducts error: \(error)")
            return []
        }
    }

    /// Returns total count of products matching filters (for "X of Y products" display).
    func fetchProductCount(storeId: UUID, searchText: String, stockScope: StockScope) -> Int {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let predicate = buildProductPredicate(
            storeId: storeId, query: query, stockScope: stockScope)
        let descriptor = FetchDescriptor<Product>(predicate: predicate)

        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            Log.db.error("fetchProductCount error: \(error)")
            return 0
        }
    }

    /// Returns total count of all products for a store (unfiltered).
    func fetchTotalProductCount(storeId: UUID) -> Int {
        let predicate = #Predicate<Product> { product in
            product.store?.id == storeId && !product.isRemoved
        }
        let descriptor = FetchDescriptor<Product>(predicate: predicate)

        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            Log.db.error("fetchTotalProductCount error: \(error)")
            return 0
        }
    }

    private func buildProductPredicate(
        storeId: UUID, query: String, stockScope: StockScope
    ) -> Predicate<Product> {
        // Capture filter conditions as bools (enums can't be compared in predicates)
        let hasQuery = !query.isEmpty
        let filterInStock = stockScope == .inStock
        let filterOutOfStock = stockScope == .outOfStock

        return #Predicate<Product> { product in
            product.store?.id == storeId
                && !product.isRemoved
                && (!hasQuery || product.titleSearchKey.contains(query))
                && (!filterInStock || product.cachedIsAvailable)
                && (!filterOutOfStock || !product.cachedIsAvailable)
        }
    }

    private func buildProductSortDescriptors(sortOrder: ProductSort) -> [SortDescriptor<Product>] {
        switch sortOrder {
        case .name:
            return [SortDescriptor(\.title)]
        case .priceLowHigh:
            return [SortDescriptor(\.cachedPrice, order: .forward)]
        case .priceHighLow:
            return [SortDescriptor(\.cachedPrice, order: .reverse)]
        case .recentlyAdded:
            // Sort by Shopify's published date, falling back to firstSeenAt if nil
            return [SortDescriptor(\.shopifyPublishedAt, order: .reverse)]
        }
    }

    // MARK: - Private Helpers

    /// Batch-fetches product image URLs for a list of events.
    /// Returns a dictionary mapping shopifyId to the primary image URL string.
    private func batchFetchProductImageURLs(for events: [ChangeEvent]) -> [Int64: String] {
        let shopifyIds = events.compactMap(\.productShopifyId)
        guard !shopifyIds.isEmpty else { return [:] }

        let idSet = Set(shopifyIds)
        let productPredicate = #Predicate<Product> { idSet.contains($0.shopifyId) }
        let productDescriptor = FetchDescriptor<Product>(predicate: productPredicate)

        guard let products = try? modelContext.fetch(productDescriptor) else { return [:] }

        return Dictionary(uniqueKeysWithValues:
            products.compactMap { product -> (Int64, String)? in
                guard let url = product.imageURLs.first else { return nil }
                return (product.shopifyId, url)
            }
        )
    }

    /// Builds a predicate for ChangeEvent filtering.
    /// Returns nil when no filters are set (fast path for fetch-all).
    private func buildEventPredicate(
        storeId: UUID?,
        changeTypes: [ChangeType]?,
        startDate: Date?
    ) -> Predicate<ChangeEvent>? {
        // Build type raw values set, preserving original "paired filter" behavior
        let typeRawValues: Set<String>? = {
            guard let changeTypes, !changeTypes.isEmpty else { return nil }
            let requested = Set(changeTypes)

            let price: Set<ChangeType> = [.priceDropped, .priceIncreased]
            let stock: Set<ChangeType> = [.backInStock, .outOfStock]
            let product: Set<ChangeType> = [.newProduct, .productRemoved]

            if requested.isSuperset(of: price) { return Set(price.map(\.rawValue)) }
            if requested.isSuperset(of: stock) { return Set(stock.map(\.rawValue)) }
            if requested.isSuperset(of: product) { return Set(product.map(\.rawValue)) }
            return nil
        }()

        // No filters -> no predicate (fetch all)
        guard storeId != nil || startDate != nil || typeRawValues != nil else {
            return nil
        }

        return #Predicate<ChangeEvent> { event in
            (storeId == nil || event.store?.id == storeId!)
                && (startDate == nil || event.occurredAt >= startDate!)
                && (typeRawValues == nil || typeRawValues!.contains(event.changeTypeRaw))
        }
    }
}
