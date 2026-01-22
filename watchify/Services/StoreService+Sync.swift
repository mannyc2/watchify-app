//
//  StoreService+Sync.swift
//  watchify
//

import Foundation
import OSLog
import SwiftData

// MARK: - Sync Implementation

extension StoreService {
    @discardableResult
    func saveProducts(
        _ shopifyProducts: [ShopifyProduct],
        to store: Store,
        isInitialImport: Bool = false
    ) -> [ChangeEvent] {
        let methodStart = entering("saveProducts")
        defer { exiting("saveProducts", start: methodStart) }

        Log.sync.info("saveProducts START \(ThreadInfo.current) count=\(shopifyProducts.count)")
        defer { Log.sync.info("saveProducts END \(ThreadInfo.current)") }

        guard !isInitialImport else {
            for shopifyProduct in shopifyProducts {
                let product = createProduct(from: shopifyProduct)
                product.store = store
                modelContext.insert(product)
            }
            logContextState("saveProducts initialImport after insert")
            return []
        }

        // PERF: Use FetchDescriptor with prefetching instead of store.products relationship.
        // Without prefetching, accessing product.variants in detectChanges() triggers
        // SwiftData lazy loading (faulting) for EACH variant individually - an N+1 query
        // problem that caused 1.31s of the 3.26s sync hang per trace analysis.
        //
        // NOTE: Prefetching loads the relationship but doesn't fully resolve faulting.
        // trace4.trace shows Variant.shopifyId.getter still takes 326ms due to property
        // access triggering Core Data faults. See detectChanges() comment for details.
        let storeId = store.id
        var descriptor = FetchDescriptor<Product>(
            predicate: #Predicate<Product> { $0.store?.id == storeId && !$0.isRemoved }
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.variants]

        Log.sync.info("saveProducts fetch_products START \(ThreadInfo.current)")
        let existingProducts = (try? ActorTrace.contextOp("saveProducts-fetch-existing", context: modelContext) {
            try modelContext.fetch(descriptor)
        }) ?? []
        Log.sync.info("saveProducts fetch_products END \(ThreadInfo.current) count=\(existingProducts.count)")

        let existingByShopifyId = Dictionary(uniqueKeysWithValues: existingProducts.map { ($0.shopifyId, $0) })
        let fetchedIds = Set(shopifyProducts.map { $0.id })

        // Process products without setting store relationship yet.
        Log.sync.info("saveProducts process_fetched START \(ThreadInfo.current)")
        var changes = processFetchedProducts(
            shopifyProducts,
            existingByShopifyId: existingByShopifyId,
            store: store
        )
        Log.sync.info("saveProducts process_fetched END \(ThreadInfo.current) changes=\(changes.count)")

        Log.sync.info("saveProducts process_removed START \(ThreadInfo.current)")
        changes += processRemovedProducts(existingProducts, fetchedIds: fetchedIds)
        Log.sync.info("saveProducts process_removed END \(ThreadInfo.current)")

        // Batch insert
        Log.sync.info("saveProducts batch_insert START \(ThreadInfo.current) count=\(changes.count)")
        for change in changes {
            change.store = store
            modelContext.insert(change)
        }
        Log.sync.info("saveProducts batch_insert END \(ThreadInfo.current)")
        logContextState("saveProducts after batch insert")
        return changes
    }

    private func processFetchedProducts(
        _ shopifyProducts: [ShopifyProduct],
        existingByShopifyId: [Int64: Product],
        store: Store
    ) -> [ChangeEvent] {
        let methodStart = entering("processFetchedProducts")
        defer { exiting("processFetchedProducts", start: methodStart) }

        var changes: [ChangeEvent] = []
        for shopifyProduct in shopifyProducts {
            if let existing = existingByShopifyId[shopifyProduct.id] {
                let productChanges = detectChanges(existing: existing, fetched: shopifyProduct)
                changes.append(contentsOf: productChanges)
                updateProduct(existing, from: shopifyProduct)
            } else {
                let product = createProduct(from: shopifyProduct)
                product.store = store
                modelContext.insert(product)
                // Don't pass store here - it will be set during batch insert
                changes.append(ChangeEvent(changeType: .newProduct, productTitle: shopifyProduct.title))
            }
        }
        return changes
    }

    private func processRemovedProducts(
        _ existingProducts: [Product],
        fetchedIds: Set<Int64>
    ) -> [ChangeEvent] {
        let methodStart = entering("processRemovedProducts")
        defer { exiting("processRemovedProducts", start: methodStart) }

        var changes: [ChangeEvent] = []
        for existing in existingProducts where !fetchedIds.contains(existing.shopifyId) {
            if !existing.isRemoved {
                // Don't pass store here - it will be set during batch insert
                changes.append(ChangeEvent(changeType: .productRemoved, productTitle: existing.title))
            }
            existing.isRemoved = true
        }
        return changes
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

        product.title = shopify.title
        product.handle = shopify.handle
        product.vendor = shopify.vendor
        product.productType = shopify.productType
        product.lastSeenAt = Date()
        product.isRemoved = false

        product.imageURLs = shopify.images.map { $0.src }

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

                existing.title = shopifyVariant.title
                existing.sku = shopifyVariant.sku
                existing.price = shopifyVariant.price
                existing.compareAtPrice = shopifyVariant.compareAtPrice
                existing.available = shopifyVariant.available
                existing.position = shopifyVariant.position
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
