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
///
/// This struct is only used within the StoreService actor and never crosses
/// actor boundaries. The `nonisolated(unsafe)` markers tell Swift 6 that we
/// take responsibility for ensuring thread-safe access (guaranteed by the
/// enclosing ModelActor).
struct SaveProductsResult: @unchecked Sendable {
    /// ChangeEvents detected during sync. Marked `nonisolated(unsafe)` because
    /// ChangeEvent is @MainActor isolated, but we only access this within StoreService.
    nonisolated(unsafe) var changes: [ChangeEvent]
    /// Products that are currently active (fetched from Shopify, not removed).
    /// Use this for updateListingCache() instead of store.products.
    /// Marked `nonisolated(unsafe)` because Product is @MainActor isolated,
    /// but we only access this within StoreService.
    nonisolated(unsafe) var activeProducts: [Product]
}

// MARK: - Sync Implementation

/// Result of fetching existing products for sync.
/// Uses `nonisolated(unsafe)` for the same reason as SaveProductsResult -
/// Product is @MainActor isolated but we only access this within StoreService.
private struct ExistingProductsResult: @unchecked Sendable {
    nonisolated(unsafe) var activeProducts: [Product]
    nonisolated(unsafe) var byShopifyId: [Int64: Product]
}

extension StoreService {
    @discardableResult
    func saveProducts(
        _ shopifyProducts: [ShopifyProduct],
        to store: Store,
        isInitialImport: Bool = false
    ) async -> SaveProductsResult {
        let fetchedIdSet = Set(shopifyProducts.map(\.id))

        // Initial import: create + return the created products so callers never touch store.products.
        if isInitialImport {
            let newProducts = createInitialProducts(shopifyProducts, for: store)
            return SaveProductsResult(changes: [], activeProducts: newProducts)
        }

        let existing = fetchExistingProducts(storeId: store.id, fetchedIdSet: fetchedIdSet)
        var (activeProducts, changes) = await processProducts(
            shopifyProducts, existing: existing, store: store)

        // Mark products removed: only consider the ones that were active going into the sync.
        changes += markRemovedProducts(existing.activeProducts, fetchedIdSet: fetchedIdSet)

        // Batch insert changes
        for change in changes {
            change.store = store
            modelContext.insert(change)
        }

        return SaveProductsResult(changes: changes, activeProducts: activeProducts)
    }

    /// Creates products for initial import without change detection.
    private func createInitialProducts(
        _ shopifyProducts: [ShopifyProduct], for store: Store
    ) -> [Product] {
        var newProducts: [Product] = []
        newProducts.reserveCapacity(shopifyProducts.count)

        for shopifyProduct in shopifyProducts {
            let product = createProduct(from: shopifyProduct)
            product.store = store
            modelContext.insert(product)
            newProducts.append(product)
        }
        return newProducts
    }

    /// Fetches existing products for sync, including resurrection candidates.
    private func fetchExistingProducts(
        storeId: UUID, fetchedIdSet: Set<Int64>
    ) -> ExistingProductsResult {
        // PERF: Use FetchDescriptor with prefetching instead of store.products relationship.
        var activeDescriptor = FetchDescriptor<Product>(
            predicate: #Predicate<Product> { $0.store?.id == storeId && !$0.isRemoved }
        )
        activeDescriptor.relationshipKeyPathsForPrefetching = [\.variants]
        let existingActive = (try? modelContext.fetch(activeDescriptor)) ?? []

        // BUG FIX: Also fetch removed products that re-appear in Shopify feed.
        var resurrectDescriptor = FetchDescriptor<Product>(
            predicate: #Predicate<Product> {
                $0.store?.id == storeId && $0.isRemoved && fetchedIdSet.contains($0.shopifyId)
            }
        )
        resurrectDescriptor.relationshipKeyPathsForPrefetching = [\.variants]
        let resurrectCandidates = (try? modelContext.fetch(resurrectDescriptor)) ?? []

        let allExisting = existingActive + resurrectCandidates
        let byShopifyId = Dictionary(uniqueKeysWithValues: allExisting.map { ($0.shopifyId, $0) })

        return ExistingProductsResult(activeProducts: existingActive, byShopifyId: byShopifyId)
    }

    /// Processes products: updates existing, creates new, detects changes.
    private func processProducts(
        _ shopifyProducts: [ShopifyProduct],
        existing: ExistingProductsResult,
        store: Store
    ) async -> (activeProducts: [Product], changes: [ChangeEvent]) {
        var activeProducts: [Product] = []
        activeProducts.reserveCapacity(shopifyProducts.count)
        var changes: [ChangeEvent] = []

        for (index, shopifyProduct) in shopifyProducts.enumerated() {
            if index > 0, index.isMultiple(of: 50) { await Task.yield() }

            if let existingProduct = existing.byShopifyId[shopifyProduct.id] {
                if existingProduct.isRemoved { existingProduct.isRemoved = false }
                changes.append(contentsOf: detectChanges(existing: existingProduct, fetched: shopifyProduct))
                updateProduct(existingProduct, from: shopifyProduct)
                activeProducts.append(existingProduct)
            } else {
                let product = createProduct(from: shopifyProduct)
                product.store = store
                modelContext.insert(product)
                activeProducts.append(product)
                changes.append(ChangeEvent(changeType: .newProduct, productTitle: shopifyProduct.title))
            }
        }
        return (activeProducts, changes)
    }

    /// Marks products as removed if they're no longer in the Shopify feed.
    private func markRemovedProducts(
        _ existingActive: [Product], fetchedIdSet: Set<Int64>
    ) -> [ChangeEvent] {
        var changes: [ChangeEvent] = []
        for existing in existingActive where !fetchedIdSet.contains(existing.shopifyId) {
            if !existing.isRemoved {
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
        var changes: [ChangeEvent] = []

        let existingVariants = Log.sync.span(
            "build_variant_dict", meta: "count=\(existing.variants.count)"
        ) {
            Dictionary(uniqueKeysWithValues: existing.variants.map { ($0.shopifyId, $0) })
        }

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
            changes.append(
                makePriceChangeEvent(
                    existing: existing,
                    fetched: fetched,
                    productTitle: productTitle
                ))
        }

        if existing.available != fetched.available {
            // Don't pass store here - it will be set during batch insert
            changes.append(
                ChangeEvent(
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
        let percentChange =
            oldPrice.decimalValue != 0 ? (difference / oldPrice.decimalValue) * 100 : Decimal(0)
        let magnitude: ChangeMagnitude =
            percentChange > 25 ? .large : percentChange > 10 ? .medium : .small

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
        let oldCount = existing.imageURLs.count
        let newCount = fetchedURLs.count
        guard oldCount != newCount else { return [] }

        // Don't pass store here - it will be set during batch insert
        return [
            ChangeEvent(
                changeType: .imagesChanged,
                productTitle: existing.title,
                oldValue: "\(oldCount) images",
                newValue: "\(newCount) images"
            )
        ]
    }

    private func formatPrice(_ price: Decimal) -> String {
        price.formatted(.currency(code: "USD"))
    }

    func createProduct(from shopify: ShopifyProduct) -> Product {
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

    private func updateProduct(_ product: Product, from shopify: ShopifyProduct) {
        updateProductFields(product, from: shopify)

        // PERF: Same N+1 faulting issue as detectChanges() - see comment there.
        // Prefetching loads relationships but property access still triggers faulting.
        let existingVariants = Log.sync.span(
            "build_variant_dict_update", meta: "count=\(product.variants.count)"
        ) {
            Dictionary(uniqueKeysWithValues: product.variants.map { ($0.shopifyId, $0) })
        }
        let fetchedVariantIds = Set(shopify.variants.map { $0.id })

        for shopifyVariant in shopify.variants {
            if let existing = existingVariants[shopifyVariant.id] {
                updateExistingVariant(existing, from: shopifyVariant)
            } else {
                createNewVariant(from: shopifyVariant, for: product)
            }
        }

        for existing in product.variants where !fetchedVariantIds.contains(existing.shopifyId) {
            modelContext.delete(existing)
        }

        product.updateListingCache(from: shopify.variants)
    }

    /// Updates basic product fields with dirty-checking.
    private func updateProductFields(_ product: Product, from shopify: ShopifyProduct) {
        if product.title != shopify.title { product.title = shopify.title }
        if product.handle != shopify.handle { product.handle = shopify.handle }
        if product.vendor != shopify.vendor { product.vendor = shopify.vendor }
        if product.productType != shopify.productType { product.productType = shopify.productType }

        let newImageURLs = shopify.images.map { $0.src }
        if product.imageURLs != newImageURLs { product.imageURLs = newImageURLs }
    }

    /// Updates an existing variant, creating a snapshot if price/availability changed.
    private func updateExistingVariant(_ existing: Variant, from shopifyVariant: ShopifyVariant) {
        // Create snapshot if trackable fields changed
        if existing.price != shopifyVariant.price
            || existing.compareAtPrice != shopifyVariant.compareAtPrice
            || existing.available != shopifyVariant.available {
            let snapshot = VariantSnapshot(
                price: existing.price,
                compareAtPrice: existing.compareAtPrice,
                available: existing.available
            )
            snapshot.variant = existing
            existing.snapshots.append(snapshot)
            modelContext.insert(snapshot)
        }

        // Dirty-checking: only assign if changed
        if existing.title != shopifyVariant.title { existing.title = shopifyVariant.title }
        if existing.sku != shopifyVariant.sku { existing.sku = shopifyVariant.sku }
        if existing.price != shopifyVariant.price { existing.price = shopifyVariant.price }
        if existing.compareAtPrice != shopifyVariant.compareAtPrice {
            existing.compareAtPrice = shopifyVariant.compareAtPrice
        }
        if existing.available != shopifyVariant.available {
            existing.available = shopifyVariant.available
        }
        if existing.position != shopifyVariant.position {
            existing.position = shopifyVariant.position
        }
    }

    /// Creates a new variant from Shopify data and attaches it to the product.
    private func createNewVariant(from shopifyVariant: ShopifyVariant, for product: Product) {
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
