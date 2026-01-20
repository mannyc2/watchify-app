//
//  StoreService.swift
//  watchify
//

import Foundation
import SwiftData

@MainActor
@Observable
final class StoreService {
    private let api = ShopifyAPI()

    func addStore(name: String?, domain: String, context: ModelContext) async throws -> Store {
        let products = try await api.fetchProducts(domain: domain)

        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalName = trimmed.isEmpty ? deriveName(from: domain) : trimmed

        let store = Store(name: finalName, domain: domain)
        context.insert(store)

        // Save products immediately
        saveProducts(products, to: store, context: context)
        store.lastFetchedAt = Date()

        return store
    }

    func syncStore(_ store: Store, context: ModelContext) async throws {
        let shopifyProducts = try await api.fetchProducts(domain: store.domain)
        saveProducts(shopifyProducts, to: store, context: context)
        store.lastFetchedAt = Date()
    }

    private func saveProducts(_ shopifyProducts: [ShopifyProduct], to store: Store, context: ModelContext) {
        let existingProducts = store.products
        let existingByShopifyId = Dictionary(uniqueKeysWithValues: existingProducts.map { ($0.shopifyId, $0) })
        let fetchedIds = Set(shopifyProducts.map { $0.id })

        for shopifyProduct in shopifyProducts {
            if let existing = existingByShopifyId[shopifyProduct.id] {
                updateProduct(existing, from: shopifyProduct, context: context)
            } else {
                let product = createProduct(from: shopifyProduct)
                product.store = store
                context.insert(product)
            }
        }

        for existing in existingProducts where !fetchedIds.contains(existing.shopifyId) {
            existing.isRemoved = true
        }
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
