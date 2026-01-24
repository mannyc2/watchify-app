//
//  StoreServiceTests+ChangeDetection.swift
//  watchifyTests
//

import Foundation
import SwiftData
import Testing
@testable import watchify

extension StoreServiceTests {

    @Suite("Change Detection")
    struct ChangeDetection {

        // MARK: - Initial Import Tests

        /// Change events should only be created on subsequent syncs, not during initial import.
        @Test("Adding a new store creates no change events", .tags(.changeDetection, .productLifecycle))
        @MainActor
        func addStoreCreatesNoEvents() async throws {
            let ctx = try await StoreServiceTestContext()

            let store = try await ctx.addStore(products: [.mock(id: 1, title: "Test Product")])

            try expectEventCount(0, in: ctx.context)
            #expect(store.products.count == 1)
        }

        @Test("Syncing with no changes creates no events", .tags(.changeDetection))
        @MainActor
        func syncWithNoChangesCreatesNoEvents() async throws {
            let ctx = try await StoreServiceTestContext()

            let product = ShopifyProduct.mock(id: 1, title: "Test Product")
            let store = try await ctx.addStore(products: [product])

            // Clear rate limit and sync - nothing changed
            ctx.clearRateLimit(for: store)
            _ = try await ctx.service.syncStore(storeId: store.id)

            try expectEventCount(0, in: ctx.context)
        }

        // MARK: - Price Change Tests

        /// Detects price decrease with correct magnitude calculation (20% = medium).
        @Test("Syncing detects price drop", .tags(.changeDetection, .priceChanges))
        @MainActor
        func syncDetectsPriceDrop() async throws {
            let ctx = try await StoreServiceTestContext()

            // Initial product at $100
            let store = try await ctx.addStore(products: [
                .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, price: 100.00)])
            ])

            // Price drops to $80 (20% drop = medium magnitude)
            await ctx.mockAPI.setProducts([
                .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, price: 80.00)])
            ])
            ctx.clearRateLimit(for: store)
            _ = try await ctx.service.syncStore(storeId: store.id)

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
            let ctx = try await StoreServiceTestContext()

            let store = try await ctx.addStore(products: [
                .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, price: 100.00)])
            ])

            // Price increases to $130 (30% = large magnitude)
            await ctx.mockAPI.setProducts([
                .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, price: 130.00)])
            ])
            ctx.clearRateLimit(for: store)
            _ = try await ctx.service.syncStore(storeId: store.id)

            let events = try fetchEvents(from: ctx.context)
            #expect(events.count == 1)
            #expect(events.first?.changeType == .priceIncreased)
            #expect(events.first?.magnitude == .large)
        }

        // MARK: - Stock Change Tests

        @Test("Syncing detects back in stock", .tags(.changeDetection, .stockChanges))
        @MainActor
        func syncDetectsBackInStock() async throws {
            let ctx = try await StoreServiceTestContext()

            // Initially out of stock
            let store = try await ctx.addStore(products: [
                .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, available: false)])
            ])

            // Now back in stock
            await ctx.mockAPI.setProducts([
                .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, available: true)])
            ])
            ctx.clearRateLimit(for: store)
            _ = try await ctx.service.syncStore(storeId: store.id)

            try expectEvent(type: .backInStock, in: ctx.context)
            let events = try fetchEvents(from: ctx.context)
            #expect(events.first?.productTitle == "Test Product")
        }

        @Test("Syncing detects out of stock", .tags(.changeDetection, .stockChanges))
        @MainActor
        func syncDetectsOutOfStock() async throws {
            let ctx = try await StoreServiceTestContext()

            let store = try await ctx.addStore(products: [
                .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, available: true)])
            ])

            // Now out of stock
            await ctx.mockAPI.setProducts([
                .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, available: false)])
            ])
            ctx.clearRateLimit(for: store)
            _ = try await ctx.service.syncStore(storeId: store.id)

            try expectEvent(type: .outOfStock, in: ctx.context)
        }

        // MARK: - Product Lifecycle Tests

        @Test("Syncing detects new products", .tags(.changeDetection, .productLifecycle))
        @MainActor
        func syncDetectsNewProducts() async throws {
            let ctx = try await StoreServiceTestContext()

            let product1 = ShopifyProduct.mock(id: 1, title: "Product 1")
            let store = try await ctx.addStore(products: [product1])

            // Add a second product
            await ctx.mockAPI.setProducts([
                product1,
                .mock(id: 2, title: "Product 2", handle: "product-2")
            ])
            ctx.clearRateLimit(for: store)
            _ = try await ctx.service.syncStore(storeId: store.id)

            let events = try fetchEvents(from: ctx.context)
            #expect(events.count == 1)
            #expect(events.first?.changeType == .newProduct)
            #expect(events.first?.productTitle == "Product 2")
        }

        @Test("Syncing detects removed products", .tags(.changeDetection, .productLifecycle))
        @MainActor
        func syncDetectsRemovedProducts() async throws {
            let ctx = try await StoreServiceTestContext()

            let product1 = ShopifyProduct.mock(id: 1, title: "Product 1")
            let product2 = ShopifyProduct.mock(id: 2, title: "Product 2", handle: "product-2")
            let store = try await ctx.addStore(products: [product1, product2])

            // Remove product 2
            await ctx.mockAPI.setProducts([product1])
            ctx.clearRateLimit(for: store)
            _ = try await ctx.service.syncStore(storeId: store.id)

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
            let ctx = try await StoreServiceTestContext()

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
            ctx.clearRateLimit(for: store)
            _ = try await ctx.service.syncStore(storeId: store.id)

            try expectEventCount(3, in: ctx.context)
            try expectEvent(type: .priceDropped, in: ctx.context)
            try expectEvent(type: .outOfStock, in: ctx.context)
            try expectEvent(type: .productRemoved, in: ctx.context)
        }

        // MARK: - Isolation Tests

        @Test("Tests are properly isolated", .tags(.changeDetection), arguments: 1...3)
        @MainActor
        func testsAreIsolated(iteration: Int) async throws {
            let ctx = try await StoreServiceTestContext()

            _ = try await ctx.addStore(
                name: "Store \(iteration)",
                domain: "test-\(iteration).myshopify.com",
                products: [.mock(id: Int64(iteration))]
            )

            let stores = try ctx.context.fetch(FetchDescriptor<Store>())
            #expect(stores.count == 1, "Each test iteration should have exactly one store")
        }
    }
}
