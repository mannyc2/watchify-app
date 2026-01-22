//
//  StoreServiceTestHelpers.swift
//  watchifyTests
//

import Foundation
import SwiftData
import Testing
@testable import watchify

// MARK: - Shared Test Context

/// Encapsulates all test dependencies for cleaner test setup.
@MainActor
final class StoreServiceTestContext {
    let container: ModelContainer
    let context: ModelContext
    let mockAPI: MockShopifyAPI
    let service: StoreService

    init() async throws {
        let schema = Schema([Store.self, Product.self, Variant.self, VariantSnapshot.self, ChangeEvent.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        self.container = try ModelContainer(for: schema, configurations: config)
        self.context = container.mainContext  // Use mainContext to see actor's saved changes
        self.mockAPI = MockShopifyAPI()
        // Use factory method instead of private init
        self.service = await StoreService.makeBackground(container: container, api: mockAPI)
    }

    /// Adds a store with the given products pre-loaded in the mock API.
    /// Returns the Store by fetching it after creation.
    func addStore(
        name: String = "Test Store",
        domain: String = "test.myshopify.com",
        products: [ShopifyProduct]
    ) async throws -> Store {
        await mockAPI.setProducts(products)
        let storeId = try await service.addStore(name: name, domain: domain)
        // Fetch the store from context since addStore returns UUID
        let descriptor = FetchDescriptor<Store>(predicate: #Predicate { $0.id == storeId })
        guard let store = try context.fetch(descriptor).first else {
            throw TestError.storeNotFound
        }
        return store
    }

    /// Prepares a store for sync testing by clearing rate limit.
    /// Call this before syncStore() in tests that need immediate sync.
    func clearRateLimit(for store: Store) {
        store.lastFetchedAt = Date.distantPast
        // Persist so the background ModelActor can observe the change.
        try? context.save()
    }

    /// Sets lastFetchedAt and saves so the background context observes it.
    func setLastFetchedAt(_ date: Date, for store: Store) {
        store.lastFetchedAt = date
        try? context.save()
    }
}

enum TestError: Error {
    case storeNotFound
}

// MARK: - Assertion Helpers

@MainActor
func fetchEvents(from context: ModelContext) throws -> [ChangeEvent] {
    let descriptor = FetchDescriptor<ChangeEvent>(
        sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
    )
    return try context.fetch(descriptor)
}

@MainActor
func expectEventCount(
    _ count: Int,
    in context: ModelContext,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let events = try fetchEvents(from: context)
    #expect(events.count == count, sourceLocation: sourceLocation)
}

@MainActor
func expectEvent(
    type: ChangeType,
    count: Int = 1,
    in context: ModelContext,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let events = try fetchEvents(from: context)
    let matching = events.filter { $0.changeType == type }
    #expect(matching.count == count, sourceLocation: sourceLocation)
}
