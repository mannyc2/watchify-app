//
//  SyncNotificationBatchTests.swift
//  watchifyTests
//

import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import watchify

// MARK: - Batch and Grouping Tests

@Suite("Sync Notification Batch & Grouping")
struct SyncNotificationBatchTests {

    // MARK: - Test: Notification Grouping by Store

    @Test("changes from multiple stores produce separate groups", .tags(.syncNotifications))
    @MainActor
    func changesFromMultipleStoresProduceSeparateGroups() async throws {
        let ctx = try await StoreServiceTestContext()

        // Create first store with a product
        let store1 = try await ctx.addStore(
            name: "Store 1",
            domain: "store1.myshopify.com",
            products: [.mock(id: 1, title: "Product A", variants: [.mock(id: 100, price: 100.00)])]
        )

        // Create second store with a product
        let store2 = try await ctx.addStore(
            name: "Store 2",
            domain: "store2.myshopify.com",
            products: [.mock(id: 2, title: "Product B", variants: [.mock(id: 200, price: 50.00)])]
        )

        // Price changes on store1
        await ctx.mockAPI.setProducts([
            .mock(id: 1, title: "Product A", variants: [.mock(id: 100, price: 80.00)])
        ])
        ctx.clearRateLimit(for: store1)
        let changes1 = try await ctx.service.syncStore(storeId: store1.id)

        // Price changes on store2
        await ctx.mockAPI.setProducts([
            .mock(id: 2, title: "Product B", variants: [.mock(id: 200, price: 40.00)])
        ])
        ctx.clearRateLimit(for: store2)
        let changes2 = try await ctx.service.syncStore(storeId: store2.id)

        // Combine all changes (simulating aggregated sync)
        let allChanges = changes1 + changes2

        #expect(allChanges.count == 2)
        #expect(changes1.count == 1)
        #expect(changes2.count == 1)

        await withNotificationDefaults {
            let fakeCenter = FakeNotificationCenter()
            fakeCenter.currentAuthorizationStatus = .authorized
            let service = NotificationService(center: fakeCenter)
            await service.send(for: allChanges)

            #expect(fakeCenter.addedRequests.count == 2)
            let threadIds = Set(fakeCenter.addedRequests.map { $0.content.threadIdentifier })
            #expect(threadIds.contains(store1.id.uuidString))
            #expect(threadIds.contains(store2.id.uuidString))
        }
    }

    @Test("all changes from single store group together", .tags(.syncNotifications))
    @MainActor
    func allChangesFromSingleStoreGroupTogether() async throws {
        let ctx = try await StoreServiceTestContext()

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
        let changes = try await ctx.service.syncStore(storeId: store.id)

        #expect(changes.count == 2)  // price drop + out of stock

        try await withNotificationDefaults {
            let fakeCenter = FakeNotificationCenter()
            fakeCenter.currentAuthorizationStatus = .authorized
            let service = NotificationService(center: fakeCenter)
            await service.send(for: changes)

            #expect(fakeCenter.addedRequests.count == 1)
            let request = try #require(fakeCenter.addedRequests.first)
            #expect(request.content.threadIdentifier == store.id.uuidString)
        }
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
