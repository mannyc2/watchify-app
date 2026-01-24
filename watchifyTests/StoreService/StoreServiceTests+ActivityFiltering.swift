//
//  StoreServiceTests+ActivityFiltering.swift
//  watchifyTests
//

import Foundation
import SwiftData
import Testing
@testable import watchify

extension StoreServiceTests {

    @Suite("Activity Filtering")
    struct ActivityFiltering {

        // MARK: - Setup Helper

        /// Creates a store with events of various types for filter testing.
        @MainActor
        private static func createTestEvents(ctx: StoreServiceTestContext) async throws -> Store {
            let store = try await ctx.addStore(products: [.mock(id: 1, title: "Product")])

            // Create events of each type
            let priceDropEvent = ChangeEvent(
                changeType: .priceDropped,
                productTitle: "Product A",
                oldValue: "$100",
                newValue: "$80",
                priceChange: -20,
                store: store
            )

            let priceIncreaseEvent = ChangeEvent(
                changeType: .priceIncreased,
                productTitle: "Product B",
                oldValue: "$80",
                newValue: "$100",
                priceChange: 20,
                store: store
            )

            let backInStockEvent = ChangeEvent(
                changeType: .backInStock,
                productTitle: "Product C",
                store: store
            )

            let outOfStockEvent = ChangeEvent(
                changeType: .outOfStock,
                productTitle: "Product D",
                store: store
            )

            let newProductEvent = ChangeEvent(
                changeType: .newProduct,
                productTitle: "Product E",
                store: store
            )

            ctx.context.insert(priceDropEvent)
            ctx.context.insert(priceIncreaseEvent)
            ctx.context.insert(backInStockEvent)
            ctx.context.insert(outOfStockEvent)
            ctx.context.insert(newProductEvent)
            try ctx.context.save()

            return store
        }

        // MARK: - Filter Tests

        @Test("Fetching all events returns all events")
        @MainActor
        func fetchAllEvents() async throws {
            let ctx = try await StoreServiceTestContext()
            _ = try await Self.createTestEvents(ctx: ctx)

            let events = await ctx.service.fetchActivityEvents(
                storeId: nil,
                changeTypes: nil,
                startDate: nil,
                offset: 0,
                limit: 100
            )

            #expect(events.count == 5)
        }

        @Test("Filtering by store returns only that store's events")
        @MainActor
        func filterByStore() async throws {
            let ctx = try await StoreServiceTestContext()
            let store = try await Self.createTestEvents(ctx: ctx)

            // Create another store with events
            let store2 = try await ctx.addStore(
                name: "Other Store",
                domain: "other.myshopify.com",
                products: [.mock(id: 2, title: "Other Product")]
            )
            let otherEvent = ChangeEvent(
                changeType: .priceDropped,
                productTitle: "Other",
                store: store2
            )
            ctx.context.insert(otherEvent)
            try ctx.context.save()

            let events = await ctx.service.fetchActivityEvents(
                storeId: store.id,
                changeTypes: nil,
                startDate: nil,
                offset: 0,
                limit: 100
            )

            #expect(events.count == 5)
            #expect(events.allSatisfy { $0.storeId == store.id })
        }

        @Test("Filtering by price type returns only price events")
        @MainActor
        func filterByPriceType() async throws {
            let ctx = try await StoreServiceTestContext()
            _ = try await Self.createTestEvents(ctx: ctx)

            let events = await ctx.service.fetchActivityEvents(
                storeId: nil,
                changeTypes: [.priceDropped, .priceIncreased],
                startDate: nil,
                offset: 0,
                limit: 100
            )

            #expect(events.count == 2)
            #expect(events.allSatisfy {
                $0.changeType == .priceDropped || $0.changeType == .priceIncreased
            })
        }

        @Test("Filtering by stock type returns only stock events")
        @MainActor
        func filterByStockType() async throws {
            let ctx = try await StoreServiceTestContext()
            _ = try await Self.createTestEvents(ctx: ctx)

            let events = await ctx.service.fetchActivityEvents(
                storeId: nil,
                changeTypes: [.backInStock, .outOfStock],
                startDate: nil,
                offset: 0,
                limit: 100
            )

            #expect(events.count == 2)
            #expect(events.allSatisfy {
                $0.changeType == .backInStock || $0.changeType == .outOfStock
            })
        }

        @Test("Filtering by date returns only recent events")
        @MainActor
        func filterByDate() async throws {
            let ctx = try await StoreServiceTestContext()
            let store = try await Self.createTestEvents(ctx: ctx)

            // Create an old event
            let oldEvent = ChangeEvent(
                changeType: .priceDropped,
                productTitle: "Old Product",
                store: store
            )
            oldEvent.occurredAt = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
            ctx.context.insert(oldEvent)
            try ctx.context.save()

            // Filter to last 7 days
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            let events = await ctx.service.fetchActivityEvents(
                storeId: nil,
                changeTypes: nil,
                startDate: startDate,
                offset: 0,
                limit: 100
            )

            #expect(events.count == 5) // Original 5, not the old one
            #expect(!events.contains { $0.productTitle == "Old Product" })
        }

        @Test("Combined filters work together")
        @MainActor
        func combinedFilters() async throws {
            let ctx = try await StoreServiceTestContext()
            let store = try await Self.createTestEvents(ctx: ctx)

            let events = await ctx.service.fetchActivityEvents(
                storeId: store.id,
                changeTypes: [.priceDropped, .priceIncreased],
                startDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                offset: 0,
                limit: 100
            )

            #expect(events.count == 2)
            #expect(events.allSatisfy { $0.storeId == store.id })
            #expect(events.allSatisfy {
                $0.changeType == .priceDropped || $0.changeType == .priceIncreased
            })
        }
    }
}
