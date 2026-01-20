//
//  StoreService.swift
//  watchify
//

import Foundation
import SwiftData

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

    func syncStore(_ store: Store, context: ModelContext) async throws {
        let shopifyProducts = try await api.fetchProducts(domain: store.domain)
        let changes = saveProducts(shopifyProducts, to: store, context: context, isInitialImport: false)
        store.lastFetchedAt = Date()

        if !changes.isEmpty {
            print("[StoreService] Detected \(changes.count) changes")
        }
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

        var changes: [ChangeEvent] = []
        let existingProducts = store.products
        let existingByShopifyId = Dictionary(uniqueKeysWithValues: existingProducts.map { ($0.shopifyId, $0) })
        let fetchedIds = Set(shopifyProducts.map { $0.id })

        for shopifyProduct in shopifyProducts {
            if let existing = existingByShopifyId[shopifyProduct.id] {
                // Detect changes BEFORE updating
                let productChanges = detectChanges(existing: existing, fetched: shopifyProduct, store: store)
                changes.append(contentsOf: productChanges)

                updateProduct(existing, from: shopifyProduct, context: context)
            } else {
                // New product
                let product = createProduct(from: shopifyProduct)
                product.store = store
                context.insert(product)

                changes.append(ChangeEvent(
                    changeType: .newProduct,
                    productTitle: shopifyProduct.title,
                    store: store
                ))
            }
        }

        // Removed products
        for existing in existingProducts where !fetchedIds.contains(existing.shopifyId) {
            if !existing.isRemoved {
                changes.append(ChangeEvent(
                    changeType: .productRemoved,
                    productTitle: existing.title,
                    store: store
                ))
            }
            existing.isRemoved = true
        }

        // Insert all change events
        for change in changes {
            context.insert(change)
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
            guard let existingVariant = existingVariants[fetchedVariant.id] else {
                // New variant - could track this too, but skip for now
                continue
            }

            // Price change
            if existingVariant.price != fetchedVariant.price {
                let priceDrop = fetchedVariant.price < existingVariant.price
                let oldPrice = existingVariant.price as NSDecimalNumber
                let difference = abs((fetchedVariant.price - existingVariant.price) as NSDecimalNumber as Decimal)
                let percentChange = oldPrice.decimalValue != 0
                    ? (difference / oldPrice.decimalValue) * 100
                    : Decimal(0)

                let magnitude: ChangeMagnitude =
                    percentChange > 25 ? .large :
                    percentChange > 10 ? .medium : .small

                changes.append(ChangeEvent(
                    changeType: priceDrop ? .priceDropped : .priceIncreased,
                    productTitle: existing.title,
                    variantTitle: existingVariant.title,
                    oldValue: formatPrice(existingVariant.price),
                    newValue: formatPrice(fetchedVariant.price),
                    magnitude: magnitude,
                    store: store
                ))
            }

            // Availability change
            if existingVariant.available != fetchedVariant.available {
                changes.append(ChangeEvent(
                    changeType: fetchedVariant.available ? .backInStock : .outOfStock,
                    productTitle: existing.title,
                    variantTitle: existingVariant.title,
                    store: store
                ))
            }
        }

        return changes
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
            productType: shopify.productType,
            imageURL: shopify.images.first.flatMap { URL(string: $0.src) }
        )

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
        product.imageURL = shopify.images.first.flatMap { URL(string: $0.src) }
        product.lastSeenAt = Date()
        product.isRemoved = false

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
