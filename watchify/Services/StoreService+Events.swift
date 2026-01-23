//
//  StoreService+Events.swift
//  watchify
//

// swiftlint:disable file_length

import Foundation
import OSLog
import SwiftData

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
        let methodStart = entering("fetchActivityEvents")
        defer { exiting("fetchActivityEvents", start: methodStart) }

        let start = CFAbsoluteTimeGetCurrent()

        let predicate = buildEventPredicate(storeId: storeId, changeTypes: changeTypes, startDate: startDate)
        var descriptor = FetchDescriptor<ChangeEvent>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset

        do {
            let events = try ActorTrace.contextOp("fetch-activity-events", context: modelContext) {
                try modelContext.fetch(descriptor)
            }
            let dtos = events.map { ChangeEventDTO(from: $0) }

            let fetchTime = CFAbsoluteTimeGetCurrent() - start
            Log.db.debug("fetchActivityEvents: \(dtos.count) events, offset=\(offset), time=\(fetchTime)s")
            return dtos
        } catch {
            Log.db.error("fetchActivityEvents error: \(error)")
            return []
        }
    }

    /// Fetches all stores for the filter picker (sorted by name).
    func fetchStores() -> [StoreDTO] {
        let methodStart = entering("fetchStores")
        defer { exiting("fetchStores", start: methodStart) }

        let descriptor = FetchDescriptor<Store>(sortBy: [SortDescriptor(\.name)])

        do {
            let stores = try ActorTrace.contextOp("fetch-stores", context: modelContext) {
                try modelContext.fetch(descriptor)
            }
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
        let methodStart = entering("fetchStoresForList")
        defer { exiting("fetchStoresForList", start: methodStart) }

        let start = CFAbsoluteTimeGetCurrent()
        let threadInfo = ThreadInfo.current.description

        let descriptor = FetchDescriptor<Store>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        do {
            let stores = try ActorTrace.contextOp("fetch-stores-list", context: modelContext) {
                try modelContext.fetch(descriptor)
            }
            let dtos = stores.map { StoreDTO(from: $0) }

            let elapsed = CFAbsoluteTimeGetCurrent() - start
            Log.db.debug("fetchStoresForList: \(dtos.count) stores in \(elapsed)s \(threadInfo)")
            return dtos
        } catch {
            Log.db.error("fetchStoresForList error: \(error)")
            return []
        }
    }

    /// Deletes a store by ID.
    func deleteStore(id: UUID) {
        let methodStart = entering("deleteStore")
        defer { exiting("deleteStore", start: methodStart) }

        let predicate = #Predicate<Store> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            let store = try ActorTrace.contextOp("fetch-store-delete", context: modelContext) {
                try modelContext.fetch(descriptor).first
            }
            if let store {
                modelContext.delete(store)
                logContextState("deleteStore before save")
                try ActorTrace.contextOp("deleteStore-save", context: modelContext) {
                    try modelContext.save()
                }
                logContextState("deleteStore after save")
                Log.db.debug("Deleted store id=\(id)")
            }
        } catch {
            Log.db.error("deleteStore error: \(error)")
        }
    }

    /// Marks a single event as read by ID.
    func markEventRead(id: UUID) {
        let methodStart = entering("markEventRead")
        defer { exiting("markEventRead", start: methodStart) }

        let predicate = #Predicate<ChangeEvent> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            let event = try ActorTrace.contextOp("fetch-event", context: modelContext) {
                try modelContext.fetch(descriptor).first
            }
            if let event {
                event.isRead = true
                logContextState("markEventRead before save")
                try ActorTrace.contextOp("markEventRead-save", context: modelContext) {
                    try modelContext.save()
                }
                logContextState("markEventRead after save")
            }
        } catch {
            Log.db.error("markEventRead error: \(error)")
        }
    }

    /// Marks multiple events as read by their IDs.
    func markEventsRead(ids: [UUID]) {
        let methodStart = entering("markEventsRead")
        defer { exiting("markEventsRead", start: methodStart) }

        guard !ids.isEmpty else { return }

        let idSet = Set(ids)
        let predicate = #Predicate<ChangeEvent> { idSet.contains($0.id) }
        let descriptor = FetchDescriptor(predicate: predicate)

        do {
            let events = try ActorTrace.contextOp("fetch-events", context: modelContext) {
                try modelContext.fetch(descriptor)
            }
            for event in events where !event.isRead {
                event.isRead = true
            }
            logContextState("markEventsRead before save")
            try ActorTrace.contextOp("markEventsRead-save", context: modelContext) {
                try modelContext.save()
            }
            logContextState("markEventsRead after save")
            Log.db.debug("marked \(events.count) events as read")
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
        let methodStart = entering("markAllEventsRead")
        defer { exiting("markAllEventsRead", start: methodStart) }

        let predicate = buildEventPredicate(storeId: storeId, changeTypes: changeTypes, startDate: startDate)
        let descriptor = FetchDescriptor<ChangeEvent>(predicate: predicate)

        do {
            let events = try ActorTrace.contextOp("fetch-events-all", context: modelContext) {
                try modelContext.fetch(descriptor)
            }

            var count = 0
            for event in events where !event.isRead {
                event.isRead = true
                count += 1
            }

            logContextState("markAllEventsRead before save")
            try ActorTrace.contextOp("markAllEventsRead-save", context: modelContext) {
                try modelContext.save()
            }
            logContextState("markAllEventsRead after save")
            Log.db.debug("marked \(count) events as read")
        } catch {
            Log.db.error("markAllEventsRead error: \(error)")
        }
    }

    // MARK: - Menu Bar

    /// Fetches events for menu bar display: unread first, then recent.
    func fetchMenuBarEvents(limit: Int) -> [ChangeEventDTO] {
        let methodStart = entering("fetchMenuBarEvents")
        defer { exiting("fetchMenuBarEvents", start: methodStart) }

        let unreadPredicate = #Predicate<ChangeEvent> { !$0.isRead }
        var unreadDescriptor = FetchDescriptor<ChangeEvent>(
            predicate: unreadPredicate,
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        unreadDescriptor.fetchLimit = limit

        do {
            let unreadEvents = try ActorTrace.contextOp("fetch-menubar-unread", context: modelContext) {
                try modelContext.fetch(unreadDescriptor)
            }

            if !unreadEvents.isEmpty {
                let dtos = unreadEvents.map { ChangeEventDTO(from: $0) }
                Log.db.debug("MenuBar: fetched \(dtos.count) unread events")
                return dtos
            }

            var recentDescriptor = FetchDescriptor<ChangeEvent>(
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            )
            recentDescriptor.fetchLimit = limit

            let recentEvents = try ActorTrace.contextOp("fetch-menubar-recent", context: modelContext) {
                try modelContext.fetch(recentDescriptor)
            }
            let dtos = recentEvents.map { ChangeEventDTO(from: $0) }
            Log.db.debug("MenuBar: fetched \(dtos.count) recent events (no unread)")
            return dtos
        } catch {
            Log.db.error("MenuBar fetch error: \(error)")
            return []
        }
    }

    /// Returns the count of unread events.
    func fetchUnreadCount() -> Int {
        let methodStart = entering("fetchUnreadCount")
        defer { exiting("fetchUnreadCount", start: methodStart) }

        let predicate = #Predicate<ChangeEvent> { !$0.isRead }
        var descriptor = FetchDescriptor<ChangeEvent>(predicate: predicate)
        descriptor.propertiesToFetch = []

        do {
            return try ActorTrace.contextOp("fetch-unread-count", context: modelContext) {
                try modelContext.fetchCount(descriptor)
            }
        } catch {
            Log.db.error("fetchUnreadCount error: \(error)")
            return 0
        }
    }

    /// Marks all unread events as read.
    func markAllUnreadEventsRead() {
        let methodStart = entering("markAllUnreadEventsRead")
        defer { exiting("markAllUnreadEventsRead", start: methodStart) }

        let predicate = #Predicate<ChangeEvent> { !$0.isRead }
        let descriptor = FetchDescriptor<ChangeEvent>(predicate: predicate)

        do {
            let events = try ActorTrace.contextOp("fetch-unread-events", context: modelContext) {
                try modelContext.fetch(descriptor)
            }
            for event in events {
                event.isRead = true
            }
            logContextState("markAllUnreadEventsRead before save")
            try ActorTrace.contextOp("markAllUnreadEventsRead-save", context: modelContext) {
                try modelContext.save()
            }
            logContextState("markAllUnreadEventsRead after save")
            Log.db.debug("MenuBar: marked \(events.count) events as read")
        } catch {
            Log.db.error("markAllUnreadEventsRead error: \(error)")
        }
    }

    /// Deletes all change events from the database.
    func deleteAllEvents() {
        let methodStart = entering("deleteAllEvents")
        defer { exiting("deleteAllEvents", start: methodStart) }

        do {
            try ActorTrace.contextOp("delete-all-events", context: modelContext) {
                try modelContext.delete(model: ChangeEvent.self)
            }
            logContextState("deleteAllEvents before save")
            try ActorTrace.contextOp("deleteAllEvents-save", context: modelContext) {
                try modelContext.save()
            }
            logContextState("deleteAllEvents after save")
            Log.db.info("Deleted all events")
        } catch {
            Log.db.error("deleteAllEvents error: \(error)")
        }
    }

    // MARK: - Products

    /// Fetches products for a store with filtering and sorting done in the database.
    func fetchProducts( // swiftlint:disable:this function_parameter_count
        storeId: UUID,
        searchText: String,
        stockScope: StockScope,
        sortOrder: ProductSort,
        offset: Int,
        limit: Int
    ) -> [ProductDTO] {
        let methodStart = entering("fetchProducts")
        defer { exiting("fetchProducts", start: methodStart) }

        let start = CFAbsoluteTimeGetCurrent()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            // Build predicate based on filters
            let predicate = buildProductPredicate(storeId: storeId, query: query, stockScope: stockScope)
            let sortDescriptors = buildProductSortDescriptors(sortOrder: sortOrder)

            var descriptor = FetchDescriptor<Product>(predicate: predicate, sortBy: sortDescriptors)
            descriptor.fetchLimit = limit
            descriptor.fetchOffset = offset

            let products = try ActorTrace.contextOp("fetch-products", context: modelContext) {
                try modelContext.fetch(descriptor)
            }
            let dtos = products.map { ProductDTO(from: $0) }

            let fetchTime = CFAbsoluteTimeGetCurrent() - start
            Log.db.debug("fetchProducts: \(dtos.count) products, offset=\(offset), time=\(fetchTime)s")
            return dtos
        } catch {
            Log.db.error("fetchProducts error: \(error)")
            return []
        }
    }

    /// Returns total count of products matching filters (for "X of Y products" display).
    func fetchProductCount(storeId: UUID, searchText: String, stockScope: StockScope) -> Int {
        let methodStart = entering("fetchProductCount")
        defer { exiting("fetchProductCount", start: methodStart) }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let predicate = buildProductPredicate(storeId: storeId, query: query, stockScope: stockScope)
        let descriptor = FetchDescriptor<Product>(predicate: predicate)

        do {
            return try ActorTrace.contextOp("fetch-product-count", context: modelContext) {
                try modelContext.fetchCount(descriptor)
            }
        } catch {
            Log.db.error("fetchProductCount error: \(error)")
            return 0
        }
    }

    /// Returns total count of all products for a store (unfiltered).
    func fetchTotalProductCount(storeId: UUID) -> Int {
        let methodStart = entering("fetchTotalProductCount")
        defer { exiting("fetchTotalProductCount", start: methodStart) }

        let threadInfo = ThreadInfo.current.description
        Log.db.info("fetchTotalProductCount START \(threadInfo)")

        let predicate = #Predicate<Product> { product in
            product.store?.id == storeId && !product.isRemoved
        }
        let descriptor = FetchDescriptor<Product>(predicate: predicate)

        do {
            return try ActorTrace.contextOp("fetch-total-product-count", context: modelContext) {
                try modelContext.fetchCount(descriptor)
            }
        } catch {
            Log.db.error("fetchTotalProductCount error: \(error)")
            return 0
        }
    }

    private func buildProductPredicate(storeId: UUID, query: String, stockScope: StockScope) -> Predicate<Product> {
        switch (query.isEmpty, stockScope) {
        case (true, .all):
            return #Predicate<Product> { product in
                product.store?.id == storeId && !product.isRemoved
            }
        case (true, .inStock):
            return #Predicate<Product> { product in
                product.store?.id == storeId && !product.isRemoved && product.cachedIsAvailable
            }
        case (true, .outOfStock):
            return #Predicate<Product> { product in
                product.store?.id == storeId && !product.isRemoved && !product.cachedIsAvailable
            }
        case (false, .all):
            return #Predicate<Product> { product in
                product.store?.id == storeId && !product.isRemoved &&
                product.titleSearchKey.contains(query)
            }
        case (false, .inStock):
            return #Predicate<Product> { product in
                product.store?.id == storeId && !product.isRemoved &&
                product.titleSearchKey.contains(query) && product.cachedIsAvailable
            }
        case (false, .outOfStock):
            return #Predicate<Product> { product in
                product.store?.id == storeId && !product.isRemoved &&
                product.titleSearchKey.contains(query) && !product.cachedIsAvailable
            }
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
            return [SortDescriptor(\.firstSeenAt, order: .reverse)]
        }
    }

    // MARK: - Private Helpers

    /// Builds a predicate for ChangeEvent filtering. Handles all combinations of filters.
    /// Switch handles 18 cases (3 optional filters × 2 states each) - complexity is inherent.
    private func buildEventPredicate( // swiftlint:disable:this cyclomatic_complexity function_body_length
        storeId: UUID?,
        changeTypes: [ChangeType]?,
        startDate: Date?
    ) -> Predicate<ChangeEvent>? {
        // Determine which type filter is active
        let typeFilter: EventTypeFilter = {
            guard let types = changeTypes else { return .all }
            if types.contains(.priceDropped) && types.contains(.priceIncreased) {
                return .price
            } else if types.contains(.backInStock) && types.contains(.outOfStock) {
                return .stock
            } else if types.contains(.newProduct) && types.contains(.productRemoved) {
                return .product
            }
            return .all
        }()

        // Local constants for predicate capture
        let priceDropped = ChangeType.priceDropped
        let priceIncreased = ChangeType.priceIncreased
        let backInStock = ChangeType.backInStock
        let outOfStock = ChangeType.outOfStock
        let newProduct = ChangeType.newProduct
        let productRemoved = ChangeType.productRemoved

        // Build predicate based on filter combination
        switch (storeId, typeFilter, startDate) {
        // No store filter
        case (nil, .all, nil):
            return nil
        case (nil, .all, let date?):
            return #Predicate<ChangeEvent> { $0.occurredAt >= date }
        case (nil, .price, nil):
            return #Predicate<ChangeEvent> {
                $0.changeType == priceDropped || $0.changeType == priceIncreased
            }
        case (nil, .price, let date?):
            return #Predicate<ChangeEvent> {
                $0.occurredAt >= date && ($0.changeType == priceDropped || $0.changeType == priceIncreased)
            }
        case (nil, .stock, nil):
            return #Predicate<ChangeEvent> {
                $0.changeType == backInStock || $0.changeType == outOfStock
            }
        case (nil, .stock, let date?):
            return #Predicate<ChangeEvent> {
                $0.occurredAt >= date && ($0.changeType == backInStock || $0.changeType == outOfStock)
            }
        case (nil, .product, nil):
            return #Predicate<ChangeEvent> {
                $0.changeType == newProduct || $0.changeType == productRemoved
            }
        case (nil, .product, let date?):
            return #Predicate<ChangeEvent> {
                $0.occurredAt >= date && ($0.changeType == newProduct || $0.changeType == productRemoved)
            }

        // With store filter
        case (let id?, .all, nil):
            return #Predicate<ChangeEvent> { $0.store?.id == id }
        case (let id?, .all, let date?):
            return #Predicate<ChangeEvent> { $0.store?.id == id && $0.occurredAt >= date }
        case (let id?, .price, nil):
            return #Predicate<ChangeEvent> {
                $0.store?.id == id && ($0.changeType == priceDropped || $0.changeType == priceIncreased)
            }
        case (let id?, .price, let date?):
            return #Predicate<ChangeEvent> {
                $0.store?.id == id && $0.occurredAt >= date &&
                ($0.changeType == priceDropped || $0.changeType == priceIncreased)
            }
        case (let id?, .stock, nil):
            return #Predicate<ChangeEvent> {
                $0.store?.id == id && ($0.changeType == backInStock || $0.changeType == outOfStock)
            }
        case (let id?, .stock, let date?):
            return #Predicate<ChangeEvent> {
                $0.store?.id == id && $0.occurredAt >= date &&
                ($0.changeType == backInStock || $0.changeType == outOfStock)
            }
        case (let id?, .product, nil):
            return #Predicate<ChangeEvent> {
                $0.store?.id == id && ($0.changeType == newProduct || $0.changeType == productRemoved)
            }
        case (let id?, .product, let date?):
            return #Predicate<ChangeEvent> {
                $0.store?.id == id && $0.occurredAt >= date &&
                ($0.changeType == newProduct || $0.changeType == productRemoved)
            }
        }
    }
}

// MARK: - Event Type Filter

private enum EventTypeFilter {
    case all
    case price
    case stock
    case product
}
