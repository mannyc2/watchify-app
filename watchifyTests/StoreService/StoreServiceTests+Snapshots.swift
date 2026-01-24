//
//  StoreServiceTests+Snapshots.swift
//  watchifyTests
//

import Foundation
import SwiftData
import Testing
@testable import watchify

extension StoreServiceTests {

    @Suite("Snapshots")
    struct Snapshots {

        // MARK: - Setup Helpers

        /// Sets up a store with initial product and syncs with updated product.
        @MainActor
        private func setupAndSync(
            ctx: StoreServiceTestContext,
            initial: ShopifyProduct,
            updated: ShopifyProduct
        ) async throws -> (store: Store, variant: Variant) {
            let store = try await ctx.addStore(products: [initial])
            let variant = store.products.first!.variants.first!
            await ctx.mockAPI.setProducts([updated])
            ctx.clearRateLimit(for: store)
            _ = try await ctx.service.syncStore(storeId: store.id)
            return (store, try freshVariant(variant, in: ctx.context))
        }

        // MARK: - Price Change Snapshot Tests

        @Test("Sync creates snapshot on price change", .tags(.variantSnapshots, .priceChanges))
        @MainActor
        func syncCreatesSnapshotOnPriceChange() async throws {
            let ctx = try await StoreServiceTestContext()

            let initial = ShopifyProduct.mock(
                id: 1,
                title: "Sneakers",
                variants: [makeVariant(id: 100, title: "Size 10", sku: "SNK-10", price: 50)]
            )
            let updated = ShopifyProduct.mock(
                id: 1,
                title: "Sneakers",
                variants: [makeVariant(id: 100, title: "Size 10", sku: "SNK-10", price: 45)]
            )

            let store = try await ctx.addStore(products: [initial])
            let variant = store.products.first!.variants.first!
            #expect(variant.snapshots.isEmpty, "No snapshots should exist initially")

            await ctx.mockAPI.setProducts([updated])
            ctx.clearRateLimit(for: store)
            _ = try await ctx.service.syncStore(storeId: store.id)

            let fresh = try freshVariant(variant, in: ctx.context)
            #expect(fresh.snapshots.count == 1, "One snapshot should be created")
            let snapshot = try #require(fresh.snapshots.first)
            #expect(snapshot.price == 50, "Snapshot should contain old price")
            #expect(snapshot.available == true, "Snapshot should contain old availability")
            #expect(fresh.price == 45, "Variant should have new price")
        }

        @Test("Multiple changes create multiple snapshots", .tags(.variantSnapshots, .priceChanges))
        @MainActor
        func multipleChangesCreateMultipleSnapshots() async throws {
            let ctx = try await StoreServiceTestContext()

            let product1 = ShopifyProduct.mock(
                id: 1,
                title: "Laptop",
                variants: [makeVariant(id: 100, title: "Base Model", sku: "LAP-BASE", price: 100)]
            )
            let store = try await ctx.addStore(products: [product1])
            var variant = store.products.first!.variants.first!

            // First change: $100 → $90
            let product2 = ShopifyProduct.mock(
                id: 1,
                title: "Laptop",
                variants: [makeVariant(id: 100, title: "Base Model", sku: "LAP-BASE", price: 90)]
            )
            await ctx.mockAPI.setProducts([product2])
            ctx.clearRateLimit(for: store)
            _ = try await ctx.service.syncStore(storeId: store.id)

            variant = try freshVariant(variant, in: ctx.context)
            #expect(variant.snapshots.count == 1, "One snapshot after first change")
            #expect(variant.price == 90, "Price should be updated to $90")

            // Second change: $90 → $85
            let product3 = ShopifyProduct.mock(
                id: 1,
                title: "Laptop",
                variants: [makeVariant(id: 100, title: "Base Model", sku: "LAP-BASE", price: 85)]
            )
            await ctx.mockAPI.setProducts([product3])
            ctx.clearRateLimit(for: store)
            _ = try await ctx.service.syncStore(storeId: store.id)

            variant = try freshVariant(variant, in: ctx.context)
            #expect(variant.snapshots.count == 2, "Two snapshots after two changes")
            let history = variant.priceHistory
            #expect(history[0].price == 100, "First snapshot should be $100")
            #expect(history[1].price == 90, "Second snapshot should be $90")
            #expect(variant.price == 85, "Current price should be $85")
        }

        @Test("Snapshot includes compareAtPrice changes", .tags(.variantSnapshots, .priceChanges))
        @MainActor
        func snapshotIncludesCompareAtPriceChanges() async throws {
            let ctx = try await StoreServiceTestContext()

            let initial = ShopifyProduct.mock(
                id: 1,
                title: "Shoes",
                variants: [makeVariant(id: 100, title: "Size 9", sku: "SH-9", price: 80, compareAtPrice: 100)]
            )
            let updated = ShopifyProduct.mock(
                id: 1,
                title: "Shoes",
                variants: [makeVariant(id: 100, title: "Size 9", sku: "SH-9", price: 80, compareAtPrice: 120)]
            )

            let (_, variant) = try await setupAndSync(ctx: ctx, initial: initial, updated: updated)

            #expect(variant.snapshots.count == 1, "Snapshot created when compareAtPrice changes")
            let snapshot = try #require(variant.snapshots.first)
            #expect(snapshot.compareAtPrice == 100, "Snapshot should contain old compareAtPrice")
            #expect(variant.compareAtPrice == 120, "Variant should have new compareAtPrice")
        }

        // MARK: - Availability Change Snapshot Tests

        @Test("Sync creates snapshot on availability change", .tags(.variantSnapshots, .stockChanges))
        @MainActor
        func syncCreatesSnapshotOnAvailabilityChange() async throws {
            let ctx = try await StoreServiceTestContext()

            let initial = ShopifyProduct.mock(
                id: 1,
                title: "Widget",
                variants: [makeVariant(id: 100, price: 29.99, available: true)]
            )
            let updated = ShopifyProduct.mock(
                id: 1,
                title: "Widget",
                variants: [makeVariant(id: 100, price: 29.99, available: false)]
            )

            let (_, variant) = try await setupAndSync(ctx: ctx, initial: initial, updated: updated)

            #expect(variant.snapshots.count == 1, "One snapshot should be created")
            let snapshot = try #require(variant.snapshots.first)
            #expect(snapshot.available == true, "Snapshot should contain old availability (true)")
            #expect(snapshot.price == 29.99, "Snapshot should contain price at time of change")
            #expect(variant.available == false, "Variant should be out of stock")
        }

        // MARK: - No Change Tests

        @Test("No snapshot created when no change", .tags(.variantSnapshots))
        @MainActor
        func noSnapshotWhenNoChange() async throws {
            let ctx = try await StoreServiceTestContext()

            let product = ShopifyProduct.mock(
                id: 1,
                title: "Book",
                variants: [makeVariant(id: 100, title: "Hardcover", sku: "BK-HC", price: 24.99)]
            )

            let (_, variant) = try await setupAndSync(ctx: ctx, initial: product, updated: product)

            #expect(variant.snapshots.isEmpty, "No snapshots when nothing changed")
        }

        // MARK: - Cascade Delete Tests

        @Test("Snapshots cascade delete with variant", .tags(.variantSnapshots, .productLifecycle))
        @MainActor
        func snapshotCascadeDeletes() async throws {
            let ctx = try await StoreServiceTestContext()

            let initial = ShopifyProduct.mock(
                id: 1,
                title: "Monitor",
                variants: [makeVariant(id: 100, title: "27-inch", sku: "MON-27", price: 300)]
            )
            let updated = ShopifyProduct.mock(
                id: 1,
                title: "Monitor",
                variants: [makeVariant(id: 100, title: "27-inch", sku: "MON-27", price: 250)]
            )

            let (_, variant) = try await setupAndSync(ctx: ctx, initial: initial, updated: updated)
            #expect(variant.snapshots.count == 1, "Snapshot should exist")

            ctx.context.delete(variant)
            let snapshots = try ctx.context.fetch(FetchDescriptor<VariantSnapshot>())
            #expect(snapshots.isEmpty, "Snapshots should be cascade deleted with variant")
        }

        // MARK: - Convenience Property Tests

        @Test("Most recent snapshot returns latest snapshot", .tags(.variantSnapshots))
        @MainActor
        func mostRecentSnapshotReturnsLatest() async throws {
            let ctx = try await StoreServiceTestContext()

            let product1 = ShopifyProduct.mock(
                id: 1,
                title: "Gadget",
                variants: [makeVariant(id: 100, title: "v1", price: 100)]
            )
            let store = try await ctx.addStore(products: [product1])
            var variant = store.products.first!.variants.first!

            // First change
            let product2 = ShopifyProduct.mock(
                id: 1,
                title: "Gadget",
                variants: [makeVariant(id: 100, title: "v1", price: 90)]
            )
            await ctx.mockAPI.setProducts([product2])
            ctx.clearRateLimit(for: store)
            _ = try await ctx.service.syncStore(storeId: store.id)

            try await Task.sleep(for: .milliseconds(10))

            // Second change
            let product3 = ShopifyProduct.mock(
                id: 1,
                title: "Gadget",
                variants: [makeVariant(id: 100, title: "v1", price: 80)]
            )
            await ctx.mockAPI.setProducts([product3])
            ctx.clearRateLimit(for: store)
            _ = try await ctx.service.syncStore(storeId: store.id)

            variant = try freshVariant(variant, in: ctx.context)
            let mostRecent = try #require(variant.mostRecentSnapshot)
            #expect(mostRecent.price == 90, "Most recent snapshot should be the $90 price point")
        }

        // MARK: - Cleanup Tests

        @Test("deleteOldSnapshots removes snapshots before cutoff date", .tags(.variantSnapshots))
        @MainActor
        func deleteOldSnapshotsRemovesBeforeCutoff() async throws {
            let ctx = try await StoreServiceTestContext()

            let initialProduct = ShopifyProduct.mock(
                id: 9001,
                title: "Cleanup Test Product",
                variants: [makeVariant(id: 90010, title: "Default", price: 100)]
            )
            let store = try await ctx.addStore(products: [initialProduct])

            // Create 3 snapshots by syncing price changes
            for price in [Decimal(90), Decimal(80), Decimal(70)] {
                let updatedProduct = ShopifyProduct.mock(
                    id: 9001,
                    title: "Cleanup Test Product",
                    variants: [makeVariant(id: 90010, title: "Default", price: price)]
                )
                await ctx.mockAPI.setProducts([updatedProduct])
                ctx.clearRateLimit(for: store)
                _ = try await ctx.service.syncStore(storeId: store.id)
            }

            // Verify snapshots were created
            let countBefore = try await ctx.service.snapshotCount()
            #expect(countBefore >= 3, "Should have at least 3 snapshots before cleanup")

            // Delete with a cutoff in the future - should delete all snapshots
            let futureCutoff = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            try await ctx.service.deleteOldSnapshots(olderThan: futureCutoff)

            let countAfter = try await ctx.service.snapshotCount()
            #expect(countAfter == 0, "All snapshots should be deleted with future cutoff")
        }

        @Test("deleteOldSnapshots preserves recent snapshots", .tags(.variantSnapshots))
        @MainActor
        func deleteOldSnapshotsPreservesRecent() async throws {
            let ctx = try await StoreServiceTestContext()

            let initialProduct = ShopifyProduct.mock(
                id: 9002,
                title: "Preserve Test Product",
                variants: [makeVariant(id: 90020, title: "Default", price: 100)]
            )
            let store = try await ctx.addStore(products: [initialProduct])

            // Create 2 snapshots
            for price in [Decimal(90), Decimal(80)] {
                let updatedProduct = ShopifyProduct.mock(
                    id: 9002,
                    title: "Preserve Test Product",
                    variants: [makeVariant(id: 90020, title: "Default", price: price)]
                )
                await ctx.mockAPI.setProducts([updatedProduct])
                ctx.clearRateLimit(for: store)
                _ = try await ctx.service.syncStore(storeId: store.id)
            }

            // Verify snapshots exist
            let countBefore = try await ctx.service.snapshotCount()
            #expect(countBefore >= 2, "Should have at least 2 snapshots")

            // Delete with a cutoff in the past - should preserve all recent snapshots
            let pastCutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
            try await ctx.service.deleteOldSnapshots(olderThan: pastCutoff)

            let countAfter = try await ctx.service.snapshotCount()
            #expect(countAfter == countBefore, "All recent snapshots should be preserved with past cutoff")
        }
    }
}
