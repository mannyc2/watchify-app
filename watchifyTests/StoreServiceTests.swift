//
//  StoreServiceTests.swift
//  watchifyTests
//

import Foundation
import SwiftData
import Testing
@testable import watchify

// MARK: - Test Tags

extension Tag {
    @Tag static var changeDetection: Self
    @Tag static var priceChanges: Self
    @Tag static var stockChanges: Self
    @Tag static var productLifecycle: Self
    @Tag static var errorHandling: Self
    @Tag static var variantSnapshots: Self
}

// MARK: - Test Suite

@Suite("Store Service Change Detection")
struct StoreServiceTests {

    // MARK: - Shared Test Context

    /// Encapsulates all test dependencies for cleaner test setup.
    @MainActor
    final class TestContext {
        let container: ModelContainer
        let context: ModelContext
        let mockAPI: MockShopifyAPI
        let service: StoreService

        init() throws {
            let schema = Schema([Store.self, Product.self, Variant.self, VariantSnapshot.self, ChangeEvent.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            self.container = try ModelContainer(for: schema, configurations: config)
            self.context = ModelContext(container)
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
    }

    // MARK: - Assertion Helpers

    @MainActor
    private func fetchEvents(from context: ModelContext) throws -> [ChangeEvent] {
        let descriptor = FetchDescriptor<ChangeEvent>(
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    @MainActor
    private func expectEventCount(
        _ count: Int,
        in context: ModelContext,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let events = try fetchEvents(from: context)
        #expect(events.count == count, sourceLocation: sourceLocation)
    }

    @MainActor
    private func expectEvent(
        type: ChangeType,
        count: Int = 1,
        in context: ModelContext,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let events = try fetchEvents(from: context)
        let matching = events.filter { $0.changeType == type }
        #expect(matching.count == count, sourceLocation: sourceLocation)
    }

    // MARK: - Initial Import Tests

    /// Change events should only be created on subsequent syncs, not during initial import.
    @Test("Adding a new store creates no change events", .tags(.changeDetection, .productLifecycle))
    @MainActor
    func addStoreCreatesNoEvents() async throws {
        let ctx = try TestContext()

        let store = try await ctx.addStore(products: [.mock(id: 1, title: "Test Product")])

        try expectEventCount(0, in: ctx.context)
        #expect(store.products.count == 1)
    }

    @Test("Syncing with no changes creates no events", .tags(.changeDetection))
    @MainActor
    func syncWithNoChangesCreatesNoEvents() async throws {
        let ctx = try TestContext()

        let product = ShopifyProduct.mock(id: 1, title: "Test Product")
        let store = try await ctx.addStore(products: [product])

        // Sync immediately - nothing changed
        try await ctx.service.syncStore(store, context: ctx.context)

        try expectEventCount(0, in: ctx.context)
    }

    // MARK: - Price Change Tests

    /// Detects price decrease with correct magnitude calculation (20% = medium).
    @Test("Syncing detects price drop", .tags(.changeDetection, .priceChanges))
    @MainActor
    func syncDetectsPriceDrop() async throws {
        let ctx = try TestContext()

        // Initial product at $100
        let store = try await ctx.addStore(products: [
            .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, price: 100.00)])
        ])

        // Price drops to $80 (20% drop = medium magnitude)
        await ctx.mockAPI.setProducts([
            .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, price: 80.00)])
        ])
        try await ctx.service.syncStore(store, context: ctx.context)

        let events = try fetchEvents(from: ctx.context)
        #expect(events.count == 1)
        #expect(events.first?.changeType == .priceDropped)
        #expect(events.first?.magnitude == .medium)
        #expect(events.first?.oldValue == "$100.00")
        #expect(events.first?.newValue == "$80.00")
    }

    /// Detects price increase with correct magnitude calculation (30% = large).
    @Test("Syncing detects price increase", .tags(.changeDetection, .priceChanges))
    @MainActor
    func syncDetectsPriceIncrease() async throws {
        let ctx = try TestContext()

        let store = try await ctx.addStore(products: [
            .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, price: 100.00)])
        ])

        // Price increases to $130 (30% = large magnitude)
        await ctx.mockAPI.setProducts([
            .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, price: 130.00)])
        ])
        try await ctx.service.syncStore(store, context: ctx.context)

        let events = try fetchEvents(from: ctx.context)
        #expect(events.count == 1)
        #expect(events.first?.changeType == .priceIncreased)
        #expect(events.first?.magnitude == .large)
    }

    // MARK: - Stock Change Tests

    @Test("Syncing detects back in stock", .tags(.changeDetection, .stockChanges))
    @MainActor
    func syncDetectsBackInStock() async throws {
        let ctx = try TestContext()

        // Initially out of stock
        let store = try await ctx.addStore(products: [
            .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, available: false)])
        ])

        // Now back in stock
        await ctx.mockAPI.setProducts([
            .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, available: true)])
        ])
        try await ctx.service.syncStore(store, context: ctx.context)

        try expectEvent(type: .backInStock, in: ctx.context)
        let events = try fetchEvents(from: ctx.context)
        #expect(events.first?.productTitle == "Test Product")
    }

    @Test("Syncing detects out of stock", .tags(.changeDetection, .stockChanges))
    @MainActor
    func syncDetectsOutOfStock() async throws {
        let ctx = try TestContext()

        let store = try await ctx.addStore(products: [
            .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, available: true)])
        ])

        // Now out of stock
        await ctx.mockAPI.setProducts([
            .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, available: false)])
        ])
        try await ctx.service.syncStore(store, context: ctx.context)

        try expectEvent(type: .outOfStock, in: ctx.context)
    }

    // MARK: - Product Lifecycle Tests

    @Test("Syncing detects new products", .tags(.changeDetection, .productLifecycle))
    @MainActor
    func syncDetectsNewProducts() async throws {
        let ctx = try TestContext()

        let product1 = ShopifyProduct.mock(id: 1, title: "Product 1")
        let store = try await ctx.addStore(products: [product1])

        // Add a second product
        await ctx.mockAPI.setProducts([
            product1,
            .mock(id: 2, title: "Product 2", handle: "product-2")
        ])
        try await ctx.service.syncStore(store, context: ctx.context)

        let events = try fetchEvents(from: ctx.context)
        #expect(events.count == 1)
        #expect(events.first?.changeType == .newProduct)
        #expect(events.first?.productTitle == "Product 2")
    }

    @Test("Syncing detects removed products", .tags(.changeDetection, .productLifecycle))
    @MainActor
    func syncDetectsRemovedProducts() async throws {
        let ctx = try TestContext()

        let product1 = ShopifyProduct.mock(id: 1, title: "Product 1")
        let product2 = ShopifyProduct.mock(id: 2, title: "Product 2", handle: "product-2")
        let store = try await ctx.addStore(products: [product1, product2])

        // Remove product 2
        await ctx.mockAPI.setProducts([product1])
        try await ctx.service.syncStore(store, context: ctx.context)

        try expectEvent(type: .productRemoved, in: ctx.context)
        let events = try fetchEvents(from: ctx.context)
        #expect(events.first?.productTitle == "Product 2")

        // Verify product is marked as removed in database
        let products = try ctx.context.fetch(FetchDescriptor<Product>())
        let removedProduct = products.first { $0.shopifyId == 2 }
        #expect(removedProduct?.isRemoved == true)
    }

    // MARK: - Complex Scenario Tests

    @Test("Syncing detects multiple changes", .tags(.changeDetection))
    @MainActor
    func syncDetectsMultipleChanges() async throws {
        let ctx = try TestContext()

        // Two products, one with two variants
        let store = try await ctx.addStore(products: [
            .mock(id: 1, title: "Product 1", variants: [
                .mock(id: 100, title: "Small", price: 50.00, available: true),
                .mock(id: 101, title: "Large", price: 60.00, available: true)
            ]),
            .mock(id: 2, title: "Product 2", handle: "product-2")
        ])

        // Changes: price drop on variant 1a, out of stock on variant 1b, product 2 removed
        await ctx.mockAPI.setProducts([
            .mock(id: 1, title: "Product 1", variants: [
                .mock(id: 100, title: "Small", price: 40.00, available: true),
                .mock(id: 101, title: "Large", price: 60.00, available: false)
            ])
        ])
        try await ctx.service.syncStore(store, context: ctx.context)

        try expectEventCount(3, in: ctx.context)
        try expectEvent(type: .priceDropped, in: ctx.context)
        try expectEvent(type: .outOfStock, in: ctx.context)
        try expectEvent(type: .productRemoved, in: ctx.context)
    }

    // MARK: - Error Handling Tests

    @Test("Syncing handles API errors gracefully", .tags(.errorHandling))
    @MainActor
    func syncHandlesAPIErrors() async throws {
        let ctx = try TestContext()

        let store = try await ctx.addStore(products: [.mock(id: 1)])

        // Simulate API error on next sync
        await ctx.mockAPI.setShouldThrow(true)

        await #expect(throws: URLError.self) {
            try await ctx.service.syncStore(store, context: ctx.context)
        }

        // Verify no partial changes were saved
        try expectEventCount(0, in: ctx.context)
    }

    @Test("Adding store handles API errors", .tags(.errorHandling))
    @MainActor
    func addStoreHandlesAPIErrors() async throws {
        let ctx = try TestContext()

        await ctx.mockAPI.setShouldThrow(true, error: ShopifyAPIError.httpError(statusCode: 404))

        await #expect(throws: ShopifyAPIError.self) {
            try await ctx.service.addStore(
                name: "Invalid Store",
                domain: "non-existent.myshopify.com",
                context: ctx.context
            )
        }
    }

    // MARK: - Isolation Tests

    @Test("Tests are properly isolated", .tags(.changeDetection), arguments: 1...3)
    @MainActor
    func testsAreIsolated(iteration: Int) async throws {
        let ctx = try TestContext()

        _ = try await ctx.addStore(
            name: "Store \(iteration)",
            domain: "test-\(iteration).myshopify.com",
            products: [.mock(id: Int64(iteration))]
        )

        let stores = try ctx.context.fetch(FetchDescriptor<Store>())
        #expect(stores.count == 1, "Each test iteration should have exactly one store")
    }

}
