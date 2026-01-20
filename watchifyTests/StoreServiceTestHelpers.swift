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

    init() throws {
        let schema = Schema([Store.self, Product.self, Variant.self, VariantSnapshot.self, ChangeEvent.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        self.container = try ModelContainer(for: schema, configurations: config)
        self.context = container.mainContext  // Use mainContext to see actor's saved changes
        self.mockAPI = MockShopifyAPI()
        self.service = StoreService(api: mockAPI)
    }

    /// Adds a store with the given products pre-loaded in the mock API.
    func addStore(
        name: String = "Test Store",
        domain: String = "test.myshopify.com",
        products: [ShopifyProduct]
    ) async throws -> Store {
        await mockAPI.setProducts(products)
        return try await service.addStore(name: name, domain: domain, context: context)
    }

    /// Prepares a store for sync testing by clearing rate limit.
    /// Call this before syncStore() in tests that need immediate sync.
    func clearRateLimit(for store: Store) {
        store.lastFetchedAt = Date.distantPast
    }
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
