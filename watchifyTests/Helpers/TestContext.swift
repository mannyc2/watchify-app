//
//  TestContext.swift
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
        // Use unique name for each test context to ensure complete isolation
        let uniqueName = UUID().uuidString
        let config = ModelConfiguration(uniqueName, isStoredInMemoryOnly: true)
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

// MARK: - Variant Helpers

func makeVariant(
    id: Int64 = 100,
    title: String = "Default",
    sku: String? = nil,
    price: Decimal,
    compareAtPrice: Decimal? = nil,
    available: Bool = true
) -> ShopifyVariant {
    ShopifyVariant(
        id: id,
        title: title,
        sku: sku,
        price: price,
        compareAtPrice: compareAtPrice,
        available: available,
        position: 1
    )
}

@MainActor
func freshVariant(_ variant: Variant, in context: ModelContext) throws -> Variant {
    let variantId = variant.shopifyId
    let descriptor = FetchDescriptor<Variant>(predicate: #Predicate { $0.shopifyId == variantId })
    guard let fresh = try context.fetch(descriptor).first else {
        fatalError("Variant not found")
    }
    return fresh
}
