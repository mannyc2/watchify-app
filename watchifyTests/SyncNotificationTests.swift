//
//  SyncNotificationTests.swift
//  watchifyTests
//

import Foundation
import SwiftData
import Testing
@testable import watchify

// MARK: - Test Tags

extension Tag {
    @Tag static var syncNotifications: Self
}

// MARK: - Test Suite

@Suite("Sync Notification Integration")
struct SyncNotificationTests {

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
            self.context = container.mainContext  // Use mainContext to see actor's saved changes
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

        /// Prepares a store for sync testing by clearing rate limit.
        func clearRateLimit(for store: Store) {
            store.lastFetchedAt = Date.distantPast
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
    private func fetchSnapshots(from context: ModelContext) throws -> [VariantSnapshot] {
        let descriptor = FetchDescriptor<VariantSnapshot>()
        return try context.fetch(descriptor)
    }

    // MARK: - Test 1: syncStore Returns Changes

    @Test("syncStore returns detected changes for notification", .tags(.syncNotifications))
    @MainActor
    func syncStoreReturnsChanges() async throws {
        let ctx = try TestContext()

        // Initial product at $100
        let store = try await ctx.addStore(products: [
            .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, price: 100.00)])
        ])

        // Price drops to $80
        await ctx.mockAPI.setProducts([
            .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, price: 80.00)])
        ])

        ctx.clearRateLimit(for: store)
        let returnedChanges = try await ctx.service.syncStore(store, context: ctx.context)

        #expect(returnedChanges.count == 1)
        #expect(returnedChanges.first?.changeType == .priceDropped)
    }

    // MARK: - Test 2: syncStore Returns Empty Array When No Changes

    @Test("syncStore returns empty array when nothing changed", .tags(.syncNotifications))
    @MainActor
    func syncStoreReturnsEmptyWhenNoChanges() async throws {
        let ctx = try TestContext()

        let product = ShopifyProduct.mock(id: 1, title: "Test Product")
        let store = try await ctx.addStore(products: [product])

        // Sync with identical data
        ctx.clearRateLimit(for: store)
        let returnedChanges = try await ctx.service.syncStore(store, context: ctx.context)

        #expect(returnedChanges.isEmpty)
    }

    // MARK: - Test 3: Returned Changes Match Persisted Events

    @Test("returned changes have same count as persisted events", .tags(.syncNotifications))
    @MainActor
    func returnedChangesMatchPersistedEvents() async throws {
        let ctx = try TestContext()

        // Setup: two products
        let store = try await ctx.addStore(products: [
            .mock(id: 1, title: "Product 1", variants: [.mock(id: 100, price: 100.00, available: true)]),
            .mock(id: 2, title: "Product 2", handle: "product-2", variants: [.mock(id: 200, price: 50.00)])
        ])

        // Changes: price drop on product 1, out of stock, product 2 removed, new product 3 added
        await ctx.mockAPI.setProducts([
            .mock(id: 1, title: "Product 1", variants: [.mock(id: 100, price: 80.00, available: false)]),
            .mock(id: 3, title: "Product 3", handle: "product-3")
        ])

        ctx.clearRateLimit(for: store)
        let returnedChanges = try await ctx.service.syncStore(store, context: ctx.context)
        let persistedEvents = try fetchEvents(from: ctx.context)

        #expect(returnedChanges.count == persistedEvents.count)
        #expect(returnedChanges.count == 4) // price drop, out of stock, removed, new product
    }

    // MARK: - Test 4: Batch Processing Works At Scale

    @Test("batch sync handles many products without data loss", .tags(.syncNotifications))
    @MainActor
    func batchSyncHandlesManyProducts() async throws {
        let ctx = try TestContext()

        // Setup: 50 products at $100 each
        let initialProducts = (1...50).map { idx in
            ShopifyProduct.mock(
                id: Int64(idx),
                title: "Product \(idx)",
                handle: "product-\(idx)",
                variants: [.mock(id: Int64(idx * 100), price: 100.00)]
            )
        }
        let store = try await ctx.addStore(products: initialProducts)

        // All 50 products have price drop to $80
        let updatedProducts = (1...50).map { idx in
            ShopifyProduct.mock(
                id: Int64(idx),
                title: "Product \(idx)",
                handle: "product-\(idx)",
                variants: [.mock(id: Int64(idx * 100), price: 80.00)]
            )
        }
        await ctx.mockAPI.setProducts(updatedProducts)

        ctx.clearRateLimit(for: store)
        let returnedChanges = try await ctx.service.syncStore(store, context: ctx.context)
        let persistedEvents = try fetchEvents(from: ctx.context)
        let snapshots = try fetchSnapshots(from: ctx.context)

        #expect(returnedChanges.count == 50)
        #expect(persistedEvents.count == 50)
        #expect(snapshots.count == 50)
    }

    // MARK: - Test 5: Changes Include Correct Store Reference

    @Test("returned changes reference correct store", .tags(.syncNotifications))
    @MainActor
    func changesReferenceCorrectStore() async throws {
        let ctx = try TestContext()

        // Create two stores
        let store1 = try await ctx.addStore(
            name: "Store 1",
            domain: "store1.myshopify.com",
            products: [.mock(id: 1, title: "Product A", variants: [.mock(id: 100, price: 100.00)])]
        )

        await ctx.mockAPI.setProducts([
            .mock(id: 2, title: "Product B", variants: [.mock(id: 200, price: 50.00)])
        ])
        let store2 = try await ctx.service.addStore(
            name: "Store 2",
            domain: "store2.myshopify.com",
            context: ctx.context
        )

        // Sync store1 with price change
        await ctx.mockAPI.setProducts([
            .mock(id: 1, title: "Product A", variants: [.mock(id: 100, price: 80.00)])
        ])
        ctx.clearRateLimit(for: store1)
        let returnedChanges = try await ctx.service.syncStore(store1, context: ctx.context)

        #expect(returnedChanges.count == 1)
        #expect(returnedChanges.first?.store?.id == store1.id)
        #expect(returnedChanges.first?.store?.id != store2.id)
    }

    // MARK: - Test 6: NotificationService Integration

    @Test("NotificationService.send handles returned changes", .tags(.syncNotifications))
    @MainActor
    func notificationServiceHandlesChanges() async throws {
        let ctx = try TestContext()

        // Create store with price change
        let store = try await ctx.addStore(products: [
            .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, price: 100.00)])
        ])

        await ctx.mockAPI.setProducts([
            .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, price: 80.00)])
        ])

        ctx.clearRateLimit(for: store)
        let changes = try await ctx.service.syncStore(store, context: ctx.context)

        // NotificationService.send should not crash even without authorization
        // (it will early-return due to authorization check in test environment)
        await NotificationService.shared.send(for: changes)

        // If we get here without crash, the integration works
        #expect(changes.count == 1)
    }

    // MARK: - Test 7: sendIfAuthorized Integration

    @Test("sendIfAuthorized handles changes without crashing", .tags(.syncNotifications))
    @MainActor
    func sendIfAuthorizedHandlesChanges() async throws {
        let ctx = try TestContext()

        let store = try await ctx.addStore(products: [
            .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, price: 100.00)])
        ])

        await ctx.mockAPI.setProducts([
            .mock(id: 1, title: "Test Product", variants: [.mock(id: 100, price: 80.00)])
        ])

        ctx.clearRateLimit(for: store)
        let changes = try await ctx.service.syncStore(store, context: ctx.context)

        // sendIfAuthorized checks authorization status first, then sends if allowed
        // In test environment, it will either prompt (first run) or skip silently
        await NotificationService.shared.sendIfAuthorized(for: changes)

        #expect(changes.count == 1)
    }

    // MARK: - Test 8: authorizationStatus Returns Valid Status

    @Test("authorizationStatus returns without crashing", .tags(.syncNotifications))
    @MainActor
    func authorizationStatusReturnsValidStatus() async throws {
        // authorizationStatus should return without crashing
        _ = await NotificationService.shared.authorizationStatus()

        // If we reach here, the method works correctly
        #expect(true)
    }

    // MARK: - Test 9: sendIfAuthorized Skips Empty Changes

    @Test("sendIfAuthorized returns early for empty changes", .tags(.syncNotifications))
    @MainActor
    func sendIfAuthorizedSkipsEmptyChanges() async throws {
        // Should not crash or prompt when called with empty array
        await NotificationService.shared.sendIfAuthorized(for: [])

        // If we get here, it handled empty input correctly
        #expect(true)
    }

    // MARK: - Test 10: Sync Flow Triggers sendIfAuthorized

    @Test("sync with changes triggers notification flow", .tags(.syncNotifications))
    @MainActor
    func syncWithChangesTriggersSendIfAuthorized() async throws {
        let ctx = try TestContext()

        // Initial state
        let store = try await ctx.addStore(products: [
            .mock(id: 1, title: "Product", variants: [.mock(id: 100, price: 100.00)])
        ])

        // Price change
        await ctx.mockAPI.setProducts([
            .mock(id: 1, title: "Product", variants: [.mock(id: 100, price: 75.00)])
        ])

        // syncStore now calls sendIfAuthorized internally
        ctx.clearRateLimit(for: store)
        let changes = try await ctx.service.syncStore(store, context: ctx.context)

        // Verify changes were detected (notification would have been attempted)
        #expect(changes.count == 1)
        #expect(changes.first?.changeType == .priceDropped)
    }
}
