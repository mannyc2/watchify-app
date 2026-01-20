//
//  SyncNotificationBatchTests.swift
//  watchifyTests
//

import Foundation
import SwiftData
import Testing
@testable import watchify

// MARK: - Batch and Grouping Tests

@Suite("Sync Notification Batch & Grouping")
struct SyncNotificationBatchTests {

    // MARK: - Shared Test Context

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
            self.context = container.mainContext
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

        func clearRateLimit(for store: Store) {
            store.lastFetchedAt = Date.distantPast
        }
    }

    // MARK: - Test: Notification Grouping by Store

    @Test("changes from multiple stores produce separate groups", .tags(.syncNotifications))
    @MainActor
    func changesFromMultipleStoresProduceSeparateGroups() async throws {
        let ctx = try TestContext()

        // Create first store with a product
        let store1 = try await ctx.addStore(
            name: "Store 1",
            domain: "store1.myshopify.com",
            products: [.mock(id: 1, title: "Product A", variants: [.mock(id: 100, price: 100.00)])]
        )

        // Create second store with a product
        await ctx.mockAPI.setProducts([
            .mock(id: 2, title: "Product B", variants: [.mock(id: 200, price: 50.00)])
        ])
        let store2 = try await ctx.service.addStore(
            name: "Store 2",
            domain: "store2.myshopify.com",
            context: ctx.context
        )

        // Price changes on store1
        await ctx.mockAPI.setProducts([
            .mock(id: 1, title: "Product A", variants: [.mock(id: 100, price: 80.00)])
        ])
        ctx.clearRateLimit(for: store1)
        let changes1 = try await ctx.service.syncStore(store1, context: ctx.context)

        // Price changes on store2
        await ctx.mockAPI.setProducts([
            .mock(id: 2, title: "Product B", variants: [.mock(id: 200, price: 40.00)])
        ])
        ctx.clearRateLimit(for: store2)
        let changes2 = try await ctx.service.syncStore(store2, context: ctx.context)

        // Combine all changes (simulating aggregated sync)
        let allChanges = changes1 + changes2

        // Group by store (same logic as NotificationService)
        let groupedByStore = Dictionary(grouping: allChanges) { $0.store?.id }

        #expect(groupedByStore.count == 2)
        #expect(groupedByStore[store1.id]?.count == 1)
        #expect(groupedByStore[store2.id]?.count == 1)
    }

    @Test("all changes from single store group together", .tags(.syncNotifications))
    @MainActor
    func allChangesFromSingleStoreGroupTogether() async throws {
        let ctx = try TestContext()

        // Create store with multiple products
        let store = try await ctx.addStore(
            name: "Test Store",
            domain: "test.myshopify.com",
            products: [
                .mock(id: 1, title: "Product 1", variants: [
                    .mock(id: 100, price: 100.00, available: true)
                ]),
                .mock(id: 2, title: "Product 2", handle: "product-2", variants: [
                    .mock(id: 200, price: 50.00, available: true)
                ])
            ]
        )

        // Multiple changes: price drop on product 1, out of stock on product 2
        await ctx.mockAPI.setProducts([
            .mock(id: 1, title: "Product 1", variants: [
                .mock(id: 100, price: 80.00, available: true)
            ]),
            .mock(id: 2, title: "Product 2", handle: "product-2", variants: [
                .mock(id: 200, price: 50.00, available: false)
            ])
        ])

        ctx.clearRateLimit(for: store)
        let changes = try await ctx.service.syncStore(store, context: ctx.context)

        // Group by store
        let groupedByStore = Dictionary(grouping: changes) { $0.store?.id }

        #expect(changes.count == 2)  // price drop + out of stock
        #expect(groupedByStore.count == 1)  // all from one store
        #expect(groupedByStore[store.id]?.count == 2)
    }

    @Test("grouping dictionary handles nil store gracefully", .tags(.syncNotifications))
    @MainActor
    func groupingDictionaryHandlesNilStore() async throws {
        // Create changes without store references (edge case)
        let orphanChange = ChangeEvent(
            changeType: .priceDropped,
            productTitle: "Orphan Product",
            variantTitle: "Default",
            oldValue: "$100.00",
            newValue: "$80.00",
            priceChange: -20,
            magnitude: .medium
        )

        let changes = [orphanChange]
        let groupedByStore = Dictionary(grouping: changes) { $0.store?.id }

        // Should have one group with nil key
        #expect(groupedByStore.count == 1)
        let nilKey: UUID? = nil
        #expect(groupedByStore[nilKey]?.count == 1)
    }
}
