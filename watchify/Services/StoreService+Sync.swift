//
//  StoreService+Sync.swift
//  watchify
//

import Foundation
import OSLog
import SwiftData

// MARK: - SaveProductsResult

/// Result of saveProducts() - returns changes and active products to avoid
/// re-faulting store.products relationship after sync.
struct SaveProductsResult {
    var changes: [ChangeEvent]
    /// Products that are currently active (fetched from Shopify, not removed).
    /// Use this for updateListingCache() instead of store.products.
    var activeProducts: [Product]
}

// MARK: - Sync Implementation

extension StoreService {
    @discardableResult
    func saveProducts(
        _ shopifyProducts: [ShopifyProduct],
        to store: Store,
        isInitialImport: Bool = false
    ) async -> SaveProductsResult {
        let methodStart = entering("saveProducts")
        defer { exiting("saveProducts", start: methodStart) }

        Log.sync.info("saveProducts START \(ThreadInfo.current) count=\(shopifyProducts.count)")
        defer { Log.sync.info("saveProducts END \(ThreadInfo.current)") }

        let fetchedIdSet = Set(shopifyProducts.map(\.id))
        let storeId = store.id

        // Initial import: create + return the created products so callers never touch store.products.
        if isInitialImport {
            var newProducts: [Product] = []
            newProducts.reserveCapacity(shopifyProducts.count)

            for shopifyProduct in shopifyProducts {
                let product = createProduct(from: shopifyProduct)
                product.store = store
                modelContext.insert(product)
                newProducts.append(product)
            }

            logContextState("saveProducts initialImport after insert")
            return SaveProductsResult(changes: [], activeProducts: newProducts)
        }

        // PERF: Use FetchDescriptor with prefetching instead of store.products relationship.
        // Without prefetching, accessing product.variants in detectChanges() triggers
        // SwiftData lazy loading (faulting) for EACH variant individually - an N+1 query
        // problem that caused 1.31s of the 3.26s sync hang per trace analysis.
        //
        // NOTE: Prefetching loads the relationship but doesn't fully resolve faulting.
        // trace4.trace shows Variant.shopifyId.getter still takes 326ms due to property
        // access triggering Core Data faults. See detectChanges() comment for details.
        var activeDescriptor = FetchDescriptor<Product>(
            predicate: #Predicate<Product> { $0.store?.id == storeId && !$0.isRemoved }
        )
        activeDescriptor.relationshipKeyPathsForPrefetching = [\.variants]

        Log.sync.info("saveProducts fetch_existing_active START \(ThreadInfo.current)")
        let existingActive = (try? ActorTrace.contextOp("saveProducts-fetch-existing-active", context: modelContext) {
            try modelContext.fetch(activeDescriptor)
        }) ?? []
        Log.sync.info("saveProducts fetch_existing_active END \(ThreadInfo.current) count=\(existingActive.count)")

        // BUG FIX: Also fetch removed products that re-appear in Shopify feed.
        // Without this, a product removed in a prior sync that reappears would cause
        // a duplicate Product insert (existingByShopifyId wouldn't contain it).
        var resurrectDescriptor = FetchDescriptor<Product>(
            predicate: #Predicate<Product> {
                $0.store?.id == storeId &&
                $0.isRemoved &&
                fetchedIdSet.contains($0.shopifyId)
            }
        )
        resurrectDescriptor.relationshipKeyPathsForPrefetching = [\.variants]

        Log.sync.info("saveProducts fetch_resurrect_candidates START \(ThreadInfo.current)")
        let resurrectCandidates = (try? ActorTrace.contextOp("saveProducts-fetch-resurrect", context: modelContext) {
            try modelContext.fetch(resurrectDescriptor)
        }) ?? []
        Log.sync.info(
            "saveProducts fetch_resurrect_candidates END \(ThreadInfo.current) count=\(resurrectCandidates.count)"
        )

        let allExisting = existingActive + resurrectCandidates
        let existingByShopifyId: [Int64: Product] =
            Dictionary(uniqueKeysWithValues: allExisting.map { ($0.shopifyId, $0) })

        // PERF: Build activeProducts directly from the fetched feed order.
        // This lets callers use activeProducts for updateListingCache() without
        // accessing store.products relationship (~600 faults avoided per trace).
        var activeProducts: [Product] = []
        activeProducts.reserveCapacity(shopifyProducts.count)

        var changes: [ChangeEvent] = []

        Log.sync.info("saveProducts process_fetched START \(ThreadInfo.current)")
        for (index, shopifyProduct) in shopifyProducts.enumerated() {
            // Yield every 50 products (~20ms) to let queued reads through
            if index > 0, index.isMultiple(of: 50) {
                await Task.yield()
            }

            if let existing = existingByShopifyId[shopifyProduct.id] {
                // If it was previously removed, revive it instead of inserting a duplicate.
                if existing.isRemoved { existing.isRemoved = false }

                changes.append(contentsOf: detectChanges(existing: existing, fetched: shopifyProduct))
                updateProduct(existing, from: shopifyProduct)
                activeProducts.append(existing)
            } else {
                let product = createProduct(from: shopifyProduct)
                product.store = store
                modelContext.insert(product)
                activeProducts.append(product)

                changes.append(ChangeEvent(changeType: .newProduct, productTitle: shopifyProduct.title))
            }
        }
        Log.sync.info("saveProducts process_fetched END \(ThreadInfo.current) changes=\(changes.count)")

        // Mark products removed: only consider the ones that were active going into the sync.
        Log.sync.info("saveProducts process_removed START \(ThreadInfo.current)")
        for existing in existingActive where !fetchedIdSet.contains(existing.shopifyId) {
            if !existing.isRemoved {
                changes.append(ChangeEvent(changeType: .productRemoved, productTitle: existing.title))
            }
            existing.isRemoved = true
        }
        Log.sync.info("saveProducts process_removed END \(ThreadInfo.current)")

        // Batch insert changes
        Log.sync.info("saveProducts batch_insert START \(ThreadInfo.current) count=\(changes.count)")
        for change in changes {
            change.store = store
            modelContext.insert(change)
        }
        Log.sync.info("saveProducts batch_insert END \(ThreadInfo.current)")
        logContextState("saveProducts after batch insert")

        return SaveProductsResult(changes: changes, activeProducts: activeProducts)
    }

    private func detectChanges(
        existing: Product,
        fetched: ShopifyProduct
    ) -> [ChangeEvent] {
        let methodStart = entering("detectChanges")
        defer { exiting("detectChanges", start: methodStart) }

        var changes: [ChangeEvent] = []
        // PERF: N+1 faulting issue - partially mitigated but not fully resolved.
        //
        // We prefetch variants via relationshipKeyPathsForPrefetching in saveProducts(),
        // which loads the relationship in one query. However, trace4.trace shows
        // Variant.shopifyId.getter still takes 326ms (36.5% of sync time).
        //
        // The call chain for each .shopifyId access:
        //   Variant.shopifyId.getter
        //     → SwiftData internals
        //       → NSManagedObjectContext.performAndWait (sync dispatch)
        //         → NSSQLiteConnection.performAndWait (sync dispatch)
        //
        // Prefetching loads the Variant objects but may not fully materialize all
        // properties. Each property access can still trigger Core Data faulting.
        //
        // Potential fixes:
        // - Use @Transient for shopifyId if it doesn't need observation
        // - Build lookup dictionary from raw fetch results before mapping
        // - Cache shopifyIds in a separate non-SwiftData structure
        //
        // See: CLAUDE.md "ModelActor Deadlock Prevention"

        // DIAG: Log thread before property access (N+1 faulting hot path)
        let beforeFaultThread = ThreadInfo.current.description
        Log.sync.debug("detectChanges beforeFault variantCount=\(existing.variants.count) \(beforeFaultThread)")

        let existingVariants = Log.sync.span("build_variant_dict", meta: "count=\(existing.variants.count)") {
            Dictionary(uniqueKeysWithValues: existing.variants.map { ($0.shopifyId, $0) })
        }

        // DIAG: Log thread after property access
        let afterFaultThread = ThreadInfo.current.description
        Log.sync.debug("detectChanges afterFault \(afterFaultThread)")

        for fetchedVariant in fetched.variants {
            guard let existingVariant = existingVariants[fetchedVariant.id] else { continue }
            changes += detectVariantChanges(
                existing: existingVariant,
                fetched: fetchedVariant,
                productTitle: existing.title
            )
        }

        changes += detectImageChanges(existing: existing, fetched: fetched)
        return changes
    }

    private func detectVariantChanges(
        existing: Variant,
        fetched: ShopifyVariant,
        productTitle: String
    ) -> [ChangeEvent] {
        var changes: [ChangeEvent] = []

        if existing.price != fetched.price {
            changes.append(makePriceChangeEvent(
                existing: existing,
                fetched: fetched,
                productTitle: productTitle
            ))
        }

        if existing.available != fetched.available {
            // Don't pass store here - it will be set during batch insert
            changes.append(ChangeEvent(
                changeType: fetched.available ? .backInStock : .outOfStock,
                productTitle: productTitle,
                variantTitle: existing.title
            ))
        }

        return changes
    }

    private func makePriceChangeEvent(
        existing: Variant,
        fetched: ShopifyVariant,
        productTitle: String
    ) -> ChangeEvent {
        let priceDrop = fetched.price < existing.price
        let oldPrice = existing.price as NSDecimalNumber
        let difference = abs((fetched.price - existing.price) as NSDecimalNumber as Decimal)
        let percentChange = oldPrice.decimalValue != 0 ? (difference / oldPrice.decimalValue) * 100 : Decimal(0)
        let magnitude: ChangeMagnitude = percentChange > 25 ? .large : percentChange > 10 ? .medium : .small

        // Don't pass store here - it will be set during batch insert
        return ChangeEvent(
            changeType: priceDrop ? .priceDropped : .priceIncreased,
            productTitle: productTitle,
            variantTitle: existing.title,
            oldValue: formatPrice(existing.price),
            newValue: formatPrice(fetched.price),
            priceChange: fetched.price - existing.price,
            magnitude: magnitude
        )
    }

    private func detectImageChanges(existing: Product, fetched: ShopifyProduct) -> [ChangeEvent] {
        let fetchedURLs = fetched.images.map { $0.src }
        guard existing.imageURLs != fetchedURLs else { return [] }
        let oldCount = existing.imageURLs.count, newCount = fetchedURLs.count
        guard oldCount != newCount else { return [] }

        // Don't pass store here - it will be set during batch insert
        return [ChangeEvent(
            changeType: .imagesChanged,
            productTitle: existing.title,
            oldValue: "\(oldCount) images",
            newValue: "\(newCount) images"
        )]
    }

    private func formatPrice(_ price: Decimal) -> String {
        price.formatted(.currency(code: "USD"))
    }

    func createProduct(from shopify: ShopifyProduct) -> Product {
        let methodStart = entering("createProduct")
        defer { exiting("createProduct", start: methodStart) }

        let product = Product(
            shopifyId: shopify.id,
            handle: shopify.handle,
            title: shopify.title,
            vendor: shopify.vendor,
            productType: shopify.productType
        )

        product.imageURLs = shopify.images.map { $0.src }

        for shopifyVariant in shopify.variants {
            let variant = Variant(
                shopifyId: shopifyVariant.id,
                title: shopifyVariant.title,
                sku: shopifyVariant.sku,
                price: shopifyVariant.price,
                compareAtPrice: shopifyVariant.compareAtPrice,
                available: shopifyVariant.available,
                position: shopifyVariant.position
            )
            variant.product = product
            product.variants.append(variant)
        }

        product.updateListingCache(from: shopify.variants)
        return product
    }

    // swiftlint:disable:next function_body_length
    private func updateProduct(_ product: Product, from shopify: ShopifyProduct) {
        let methodStart = entering("updateProduct")
        defer { exiting("updateProduct", start: methodStart) }

        // Dirty-checking: only assign if changed to avoid marking Product dirty
        if product.title != shopify.title { product.title = shopify.title }
        if product.handle != shopify.handle { product.handle = shopify.handle }
        if product.vendor != shopify.vendor { product.vendor = shopify.vendor }
        if product.productType != shopify.productType { product.productType = shopify.productType }
        // isRemoved is already guarded in caller (line 110)

        let newImageURLs = shopify.images.map { $0.src }
        if product.imageURLs != newImageURLs { product.imageURLs = newImageURLs }

        // PERF: Same N+1 faulting issue as detectChanges() - see comment there.
        // Prefetching loads relationships but property access still triggers faulting.
        let existingVariants = Log.sync.span("build_variant_dict_update", meta: "count=\(product.variants.count)") {
            Dictionary(uniqueKeysWithValues: product.variants.map { ($0.shopifyId, $0) })
        }
        let fetchedVariantIds = Set(shopify.variants.map { $0.id })

        for shopifyVariant in shopify.variants {
            if let existing = existingVariants[shopifyVariant.id] {
                if existing.price != shopifyVariant.price ||
                   existing.compareAtPrice != shopifyVariant.compareAtPrice ||
                   existing.available != shopifyVariant.available {
                    let snapshot = VariantSnapshot(
                        price: existing.price,
                        compareAtPrice: existing.compareAtPrice,
                        available: existing.available
                    )
                    snapshot.variant = existing
                    existing.snapshots.append(snapshot)
                    modelContext.insert(snapshot)
                }

                // Dirty-checking: only assign if changed to avoid marking Variant dirty
                if existing.title != shopifyVariant.title { existing.title = shopifyVariant.title }
                if existing.sku != shopifyVariant.sku { existing.sku = shopifyVariant.sku }
                if existing.price != shopifyVariant.price { existing.price = shopifyVariant.price }
                if existing.compareAtPrice != shopifyVariant.compareAtPrice {
                    existing.compareAtPrice = shopifyVariant.compareAtPrice
                }
                if existing.available != shopifyVariant.available { existing.available = shopifyVariant.available }
                if existing.position != shopifyVariant.position { existing.position = shopifyVariant.position }
            } else {
                let variant = Variant(
                    shopifyId: shopifyVariant.id,
                    title: shopifyVariant.title,
                    sku: shopifyVariant.sku,
                    price: shopifyVariant.price,
                    compareAtPrice: shopifyVariant.compareAtPrice,
                    available: shopifyVariant.available,
                    position: shopifyVariant.position
                )
                variant.product = product
                product.variants.append(variant)
            }
        }

        for existing in product.variants where !fetchedVariantIds.contains(existing.shopifyId) {
            modelContext.delete(existing)
        }

        product.updateListingCache(from: shopify.variants)
    }
}
