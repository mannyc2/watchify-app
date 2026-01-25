//
//  MockShopifyAPI.swift
//  watchifyTests
//

import Foundation
@testable import watchify

actor MockShopifyAPI: ShopifyAPIProtocol {
    private var productsToReturn: [ShopifyProduct] = []
    private var shouldThrowError = false
    private var errorToThrow: Error = URLError(.badServerResponse)

    func setProducts(_ products: [ShopifyProduct]) {
        productsToReturn = products
    }

    func setShouldThrow(_ shouldThrow: Bool, error: Error = URLError(.badServerResponse)) {
        shouldThrowError = shouldThrow
        errorToThrow = error
    }

    func fetchProducts(domain: String) async throws -> [ShopifyProduct] {
        if shouldThrowError {
            throw errorToThrow
        }
        return productsToReturn
    }
}

// MARK: - Test Data Helpers

extension ShopifyProduct {
    static func mock(
        id: Int64 = 1,
        title: String = "Test Product",
        handle: String = "test-product",
        vendor: String? = "Test Vendor",
        productType: String? = "Test Type",
        createdAt: Date? = nil,
        publishedAt: Date? = nil,
        updatedAt: Date? = nil,
        variants: [ShopifyVariant] = [.mock()],
        images: [ShopifyImage] = []
    ) -> ShopifyProduct {
        ShopifyProduct(
            id: id,
            title: title,
            handle: handle,
            vendor: vendor,
            productType: productType,
            createdAt: createdAt,
            publishedAt: publishedAt,
            updatedAt: updatedAt,
            images: images,
            variants: variants
        )
    }
}

extension ShopifyVariant {
    static func mock(
        id: Int64 = 1,
        title: String = "Default",
        sku: String? = "TEST-SKU",
        price: Decimal = 100.00,
        compareAtPrice: Decimal? = nil,
        available: Bool = true,
        position: Int = 1
    ) -> ShopifyVariant {
        ShopifyVariant(
            id: id,
            title: title,
            sku: sku,
            price: price,
            compareAtPrice: compareAtPrice,
            available: available,
            position: position
        )
    }
}
