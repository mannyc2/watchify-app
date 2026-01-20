//
//  StoreService.swift
//  watchify
//

import Foundation
import SwiftData

enum SyncError: Error, LocalizedError {
    case storeNotFound
    case rateLimited(retryAfter: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .storeNotFound:
            return String(localized: "Store not found")
        case .rateLimited:
            return String(localized: "Sync limited")
        }
    }

    var failureReason: String? {
        switch self {
        case .storeNotFound:
            return String(localized: "We couldn't find a store with that address.")
        case .rateLimited(let seconds):
            let rounded = Int(seconds.rounded(.up))
            return String(localized: "Please wait \(rounded) seconds before syncing again.")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .storeNotFound:
            return String(localized: "Check the domain and try again.")
        case .rateLimited:
            return String(localized: "Try again after the countdown completes.")
        }
    }
}

@MainActor
@Observable
final class StoreService {
    private let api: ShopifyAPIProtocol

    init(api: ShopifyAPIProtocol? = nil) {
        self.api = api ?? ShopifyAPI()
    }

    func addStore(name: String?, domain: String, context: ModelContext) async throws -> Store {
        let products = try await api.fetchProducts(domain: domain)

        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalName = trimmed.isEmpty ? deriveName(from: domain) : trimmed

        let store = Store(name: finalName, domain: domain)
        context.insert(store)

        // Initial import - don't emit newProduct events for every product
        _ = saveProducts(products, to: store, context: context, isInitialImport: true)
        store.lastFetchedAt = Date()

        return store
    }

    @discardableResult
    func syncStore(_ store: Store, context: ModelContext) async throws -> [ChangeEvent] {
        // Rate limit check: 60s minimum between syncs
        let minInterval: TimeInterval = 60
        if let lastFetch = store.lastFetchedAt {
            let elapsed = Date().timeIntervalSince(lastFetch)
            if elapsed < minInterval {
                throw SyncError.rateLimited(retryAfter: minInterval - elapsed)
            }
        }

        let shopifyProducts = try await api.fetchProducts(domain: store.domain)
        let changes = saveProducts(shopifyProducts, to: store, context: context, isInitialImport: false)
        store.lastFetchedAt = Date()
        return changes
    }

    @discardableResult
    private func saveProducts(
        _ shopifyProducts: [ShopifyProduct],
        to store: Store,
        context: ModelContext,
        isInitialImport: Bool = false
    ) -> [ChangeEvent] {
        // Skip change detection on initial import
        guard !isInitialImport else {
            for shopifyProduct in shopifyProducts {
                let product = createProduct(from: shopifyProduct)
                product.store = store
                context.insert(product)
            }
            return []
        }

        let existingProducts = store.products
        let existingByShopifyId = Dictionary(uniqueKeysWithValues: existingProducts.map { ($0.shopifyId, $0) })
        let fetchedIds = Set(shopifyProducts.map { $0.id })

        var changes = processFetchedProducts(
            shopifyProducts,
            existingByShopifyId: existingByShopifyId,
            store: store,
            context: context
        )
        changes += processRemovedProducts(existingProducts, fetchedIds: fetchedIds, store: store)

        for change in changes {
            context.insert(change)
        }
        return changes
    }

    private func processFetchedProducts(
        _ shopifyProducts: [ShopifyProduct],
        existingByShopifyId: [Int64: Product],
        store: Store,
        context: ModelContext
    ) -> [ChangeEvent] {
        var changes: [ChangeEvent] = []
        for shopifyProduct in shopifyProducts {
            if let existing = existingByShopifyId[shopifyProduct.id] {
                let productChanges = detectChanges(existing: existing, fetched: shopifyProduct, store: store)
                changes.append(contentsOf: productChanges)
                updateProduct(existing, from: shopifyProduct, context: context)
            } else {
                let product = createProduct(from: shopifyProduct)
                product.store = store
                context.insert(product)
                changes.append(ChangeEvent(changeType: .newProduct, productTitle: shopifyProduct.title, store: store))
            }
        }
        return changes
    }

    private func processRemovedProducts(
        _ existingProducts: [Product],
        fetchedIds: Set<Int64>,
        store: Store
    ) -> [ChangeEvent] {
        var changes: [ChangeEvent] = []
        for existing in existingProducts where !fetchedIds.contains(existing.shopifyId) {
            if !existing.isRemoved {
                changes.append(ChangeEvent(changeType: .productRemoved, productTitle: existing.title, store: store))
            }
            existing.isRemoved = true
        }
        return changes
    }

    private func detectChanges(
        existing: Product,
        fetched: ShopifyProduct,
        store: Store
    ) -> [ChangeEvent] {
        var changes: [ChangeEvent] = []
        let existingVariants = Dictionary(uniqueKeysWithValues: existing.variants.map { ($0.shopifyId, $0) })

        for fetchedVariant in fetched.variants {
            guard let existingVariant = existingVariants[fetchedVariant.id] else { continue }
            changes += detectVariantChanges(
                existing: existingVariant,
                fetched: fetchedVariant,
                productTitle: existing.title,
                store: store
            )
        }

        changes += detectImageChanges(existing: existing, fetched: fetched, store: store)
        return changes
    }

    private func detectVariantChanges(
        existing: Variant,
        fetched: ShopifyVariant,
        productTitle: String,
        store: Store
    ) -> [ChangeEvent] {
        var changes: [ChangeEvent] = []

        if existing.price != fetched.price {
            changes.append(makePriceChangeEvent(
                existing: existing,
                fetched: fetched,
                productTitle: productTitle,
                store: store
            ))
        }

        if existing.available != fetched.available {
            changes.append(ChangeEvent(
                changeType: fetched.available ? .backInStock : .outOfStock,
                productTitle: productTitle,
                variantTitle: existing.title,
                store: store
            ))
        }

        return changes
    }

    private func makePriceChangeEvent(
        existing: Variant,
        fetched: ShopifyVariant,
        productTitle: String,
        store: Store
    ) -> ChangeEvent {
        let priceDrop = fetched.price < existing.price
        let oldPrice = existing.price as NSDecimalNumber
        let difference = abs((fetched.price - existing.price) as NSDecimalNumber as Decimal)
        let percentChange = oldPrice.decimalValue != 0 ? (difference / oldPrice.decimalValue) * 100 : Decimal(0)
        let magnitude: ChangeMagnitude = percentChange > 25 ? .large : percentChange > 10 ? .medium : .small

        return ChangeEvent(
            changeType: priceDrop ? .priceDropped : .priceIncreased,
            productTitle: productTitle,
            variantTitle: existing.title,
            oldValue: formatPrice(existing.price),
            newValue: formatPrice(fetched.price),
            priceChange: fetched.price - existing.price,
            magnitude: magnitude,
            store: store
        )
    }

    private func detectImageChanges(existing: Product, fetched: ShopifyProduct, store: Store) -> [ChangeEvent] {
        let fetchedURLs = fetched.images.map { $0.src }
        guard existing.imageURLs != fetchedURLs else { return [] }
        let oldCount = existing.imageURLs.count, newCount = fetchedURLs.count
        guard oldCount != newCount else { return [] }

        return [ChangeEvent(
            changeType: .imagesChanged,
            productTitle: existing.title,
            oldValue: "\(oldCount) images",
            newValue: "\(newCount) images",
            store: store
        )]
    }

    private func formatPrice(_ price: Decimal) -> String {
        price.formatted(.currency(code: "USD"))
    }

    private func createProduct(from shopify: ShopifyProduct) -> Product {
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

        return product
    }

    private func updateProduct(_ product: Product, from shopify: ShopifyProduct, context: ModelContext) {
        product.title = shopify.title
        product.handle = shopify.handle
        product.vendor = shopify.vendor
        product.productType = shopify.productType
        product.lastSeenAt = Date()
        product.isRemoved = false

        // Update images - simple array replacement
        product.imageURLs = shopify.images.map { $0.src }

        let existingVariants = Dictionary(uniqueKeysWithValues: product.variants.map { ($0.shopifyId, $0) })
        let fetchedVariantIds = Set(shopify.variants.map { $0.id })

        for shopifyVariant in shopify.variants {
            if let existing = existingVariants[shopifyVariant.id] {
                // Create snapshot BEFORE modifying values if price or availability changed
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
                    context.insert(snapshot)
                }

                // Now update the variant with new values
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
            context.delete(existing)
        }
    }

    private func deriveName(from domain: String) -> String {
        domain.split(separator: ".").first.map(String.init) ?? domain
    }
}
