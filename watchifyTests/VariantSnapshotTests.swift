//
//  VariantSnapshotTests.swift
//  watchifyTests
//

import Foundation
import SwiftData
import Testing
@testable import watchify

@Suite("Variant Snapshot Tests")
struct VariantSnapshotTests {

    // MARK: - Shared Test Context

    @MainActor
    final class TestContext {
        let container: ModelContainer
        let context: ModelContext
        let mockAPI: MockShopifyAPI
        let service: StoreService

        init() throws {
            let schema = Schema([
                Store.self,
                Product.self,
                Variant.self,
                VariantSnapshot.self,
                ChangeEvent.self
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            self.container = try ModelContainer(for: schema, configurations: config)
            self.context = ModelContext(container)
            self.mockAPI = MockShopifyAPI()
            self.service = StoreService(api: mockAPI)
        }

        func addStore(
            name: String = "Test Store",
            domain: String = "test.myshopify.com",
            products: [ShopifyProduct]
        ) async throws -> Store {
            await mockAPI.setProducts(products)
            return try await service.addStore(name: name, domain: domain, context: context)
        }
    }

    // MARK: - Helper to create variants

    private func makeVariant(
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

    // MARK: - Price Change Snapshot Tests

    @Test("Sync creates snapshot on price change", .tags(.variantSnapshots, .priceChanges))
    @MainActor
    func syncCreatesSnapshotOnPriceChange() async throws {
        let ctx = try TestContext()

        // Initial setup: add a store with a product at price $50
        let product = ShopifyProduct.mock(
            id: 1,
            title: "Sneakers",
            variants: [makeVariant(id: 100, title: "Size 10", sku: "SNK-10", price: 50)]
        )
        let store = try await ctx.addStore(products: [product])

        // Get the variant
        let variant = store.products.first!.variants.first!
        #expect(variant.snapshots.isEmpty, "No snapshots should exist initially")

        // Sync with updated price: $50 → $45
        let updatedProduct = ShopifyProduct.mock(
            id: 1,
            title: "Sneakers",
            variants: [makeVariant(id: 100, title: "Size 10", sku: "SNK-10", price: 45)]
        )
        await ctx.mockAPI.setProducts([updatedProduct])
        try await ctx.service.syncStore(store, context: ctx.context)

        // Verify snapshot was created with old price
        #expect(variant.snapshots.count == 1, "One snapshot should be created")
        let snapshot = try #require(variant.snapshots.first)
        #expect(snapshot.price == 50, "Snapshot should contain old price")
        #expect(snapshot.available == true, "Snapshot should contain old availability")

        // Verify current variant has new price
        #expect(variant.price == 45, "Variant should have new price")
    }

    @Test("Multiple changes create multiple snapshots", .tags(.variantSnapshots, .priceChanges))
    @MainActor
    func multipleChangesCreateMultipleSnapshots() async throws {
        let ctx = try TestContext()

        // Initial: $100
        let product1 = ShopifyProduct.mock(
            id: 1,
            title: "Laptop",
            variants: [makeVariant(id: 100, title: "Base Model", sku: "LAP-BASE", price: 100)]
        )
        let store = try await ctx.addStore(products: [product1])
        let variant = store.products.first!.variants.first!

        // First change: $100 → $90
        let product2 = ShopifyProduct.mock(
            id: 1,
            title: "Laptop",
            variants: [makeVariant(id: 100, title: "Base Model", sku: "LAP-BASE", price: 90)]
        )
        await ctx.mockAPI.setProducts([product2])
        try await ctx.service.syncStore(store, context: ctx.context)

        #expect(variant.snapshots.count == 1, "One snapshot after first change")
        #expect(variant.price == 90, "Price should be updated to $90")

        // Second change: $90 → $85
        let product3 = ShopifyProduct.mock(
            id: 1,
            title: "Laptop",
            variants: [makeVariant(id: 100, title: "Base Model", sku: "LAP-BASE", price: 85)]
        )
        await ctx.mockAPI.setProducts([product3])
        try await ctx.service.syncStore(store, context: ctx.context)

        // Verify two snapshots exist
        #expect(variant.snapshots.count == 2, "Two snapshots after two changes")

        // Verify price history is correct
        let history = variant.priceHistory
        #expect(history[0].price == 100, "First snapshot should be $100")
        #expect(history[1].price == 90, "Second snapshot should be $90")
        #expect(variant.price == 85, "Current price should be $85")
    }

    @Test("Snapshot includes compareAtPrice changes", .tags(.variantSnapshots, .priceChanges))
    @MainActor
    func snapshotIncludesCompareAtPriceChanges() async throws {
        let ctx = try TestContext()

        // Initial: sale price $80, compare at $100
        let product1 = ShopifyProduct.mock(
            id: 1,
            title: "Shoes",
            variants: [makeVariant(id: 100, title: "Size 9", sku: "SH-9", price: 80, compareAtPrice: 100)]
        )
        let store = try await ctx.addStore(products: [product1])
        let variant = store.products.first!.variants.first!

        // Change compareAtPrice: $100 → $120
        let product2 = ShopifyProduct.mock(
            id: 1,
            title: "Shoes",
            variants: [makeVariant(id: 100, title: "Size 9", sku: "SH-9", price: 80, compareAtPrice: 120)]
        )
        await ctx.mockAPI.setProducts([product2])
        try await ctx.service.syncStore(store, context: ctx.context)

        // Verify snapshot was created
        #expect(variant.snapshots.count == 1, "Snapshot created when compareAtPrice changes")
        let snapshot = try #require(variant.snapshots.first)
        #expect(snapshot.compareAtPrice == 100, "Snapshot should contain old compareAtPrice")
        #expect(variant.compareAtPrice == 120, "Variant should have new compareAtPrice")
    }

    // MARK: - Availability Change Snapshot Tests

    @Test("Sync creates snapshot on availability change", .tags(.variantSnapshots, .stockChanges))
    @MainActor
    func syncCreatesSnapshotOnAvailabilityChange() async throws {
        let ctx = try TestContext()

        // Initial setup: product in stock
        let product = ShopifyProduct.mock(
            id: 1,
            title: "Widget",
            variants: [makeVariant(id: 100, price: 29.99, available: true)]
        )
        let store = try await ctx.addStore(products: [product])
        let variant = store.products.first!.variants.first!

        // Sync with updated availability: true → false
        let updatedProduct = ShopifyProduct.mock(
            id: 1,
            title: "Widget",
            variants: [makeVariant(id: 100, price: 29.99, available: false)]
        )
        await ctx.mockAPI.setProducts([updatedProduct])
        try await ctx.service.syncStore(store, context: ctx.context)

        // Verify snapshot was created
        #expect(variant.snapshots.count == 1, "One snapshot should be created")
        let snapshot = try #require(variant.snapshots.first)
        #expect(snapshot.available == true, "Snapshot should contain old availability (true)")
        #expect(snapshot.price == 29.99, "Snapshot should contain price at time of change")

        // Verify current variant has new availability
        #expect(variant.available == false, "Variant should be out of stock")
    }

    // MARK: - No Change Tests

    @Test("No snapshot created when no change", .tags(.variantSnapshots))
    @MainActor
    func noSnapshotWhenNoChange() async throws {
        let ctx = try TestContext()

        // Initial setup
        let product = ShopifyProduct.mock(
            id: 1,
            title: "Book",
            variants: [makeVariant(id: 100, title: "Hardcover", sku: "BK-HC", price: 24.99)]
        )
        let store = try await ctx.addStore(products: [product])
        let variant = store.products.first!.variants.first!

        // Sync with identical data
        await ctx.mockAPI.setProducts([product])
        try await ctx.service.syncStore(store, context: ctx.context)

        // Verify no snapshots were created
        #expect(variant.snapshots.isEmpty, "No snapshots when nothing changed")
    }

    // MARK: - Cascade Delete Tests

    @Test("Snapshots cascade delete with variant", .tags(.variantSnapshots, .productLifecycle))
    @MainActor
    func snapshotCascadeDeletes() async throws {
        let ctx = try TestContext()

        // Setup: Create a product with a variant that has price changes
        let product1 = ShopifyProduct.mock(
            id: 1,
            title: "Monitor",
            variants: [makeVariant(id: 100, title: "27-inch", sku: "MON-27", price: 300)]
        )
        let store = try await ctx.addStore(products: [product1])
        let variant = store.products.first!.variants.first!

        // Create a price change to generate a snapshot
        let product2 = ShopifyProduct.mock(
            id: 1,
            title: "Monitor",
            variants: [makeVariant(id: 100, title: "27-inch", sku: "MON-27", price: 250)]
        )
        await ctx.mockAPI.setProducts([product2])
        try await ctx.service.syncStore(store, context: ctx.context)

        #expect(variant.snapshots.count == 1, "Snapshot should exist")

        // Delete the variant
        ctx.context.delete(variant)

        // Fetch all snapshots to verify cascade delete
        let snapshots = try ctx.context.fetch(FetchDescriptor<VariantSnapshot>())
        #expect(snapshots.isEmpty, "Snapshots should be cascade deleted with variant")
    }

    // MARK: - Convenience Property Tests

    @Test("Most recent snapshot returns latest snapshot", .tags(.variantSnapshots))
    @MainActor
    func mostRecentSnapshotReturnsLatest() async throws {
        let ctx = try TestContext()

        // Create a variant with multiple price changes
        let product1 = ShopifyProduct.mock(
            id: 1,
            title: "Gadget",
            variants: [makeVariant(id: 100, title: "v1", price: 100)]
        )
        let store = try await ctx.addStore(products: [product1])
        let variant = store.products.first!.variants.first!

        // First change
        let product2 = ShopifyProduct.mock(
            id: 1,
            title: "Gadget",
            variants: [makeVariant(id: 100, title: "v1", price: 90)]
        )
        await ctx.mockAPI.setProducts([product2])
        try await ctx.service.syncStore(store, context: ctx.context)

        // Small delay to ensure distinct timestamps
        try await Task.sleep(for: .milliseconds(10))

        // Second change
        let product3 = ShopifyProduct.mock(
            id: 1,
            title: "Gadget",
            variants: [makeVariant(id: 100, title: "v1", price: 80)]
        )
        await ctx.mockAPI.setProducts([product3])
        try await ctx.service.syncStore(store, context: ctx.context)

        // Verify mostRecentSnapshot returns the latest one
        let mostRecent = try #require(variant.mostRecentSnapshot)
        #expect(mostRecent.price == 90, "Most recent snapshot should be the $90 price point")
    }
}
