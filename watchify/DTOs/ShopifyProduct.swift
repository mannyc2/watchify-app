//
//  ShopifyProduct.swift
//  watchify
//

import Foundation

struct ShopifyProductsResponse: Sendable, Codable {
    let products: [ShopifyProduct]

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        products = try container.decode([ShopifyProduct].self, forKey: .products)
    }
}

struct ShopifyProduct: Sendable, Codable {
    let id: Int64
    let title: String
    let handle: String
    let vendor: String?
    let productType: String?
    let createdAt: Date?
    let publishedAt: Date?
    let updatedAt: Date?
    let images: [ShopifyImage]
    let variants: [ShopifyVariant]

    enum CodingKeys: String, CodingKey {
        case id, title, handle, vendor, images, variants
        case productType = "product_type"
        case createdAt = "created_at"
        case publishedAt = "published_at"
        case updatedAt = "updated_at"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        handle = try container.decode(String.self, forKey: .handle)
        vendor = try container.decodeIfPresent(String.self, forKey: .vendor)
        productType = try container.decodeIfPresent(String.self, forKey: .productType)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        publishedAt = try container.decodeIfPresent(Date.self, forKey: .publishedAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        images = try container.decode([ShopifyImage].self, forKey: .images)
        variants = try container.decode([ShopifyVariant].self, forKey: .variants)
    }

    init(
        id: Int64,
        title: String,
        handle: String,
        vendor: String?,
        productType: String?,
        createdAt: Date? = nil,
        publishedAt: Date? = nil,
        updatedAt: Date? = nil,
        images: [ShopifyImage],
        variants: [ShopifyVariant]
    ) {
        self.id = id
        self.title = title
        self.handle = handle
        self.vendor = vendor
        self.productType = productType
        self.createdAt = createdAt
        self.publishedAt = publishedAt
        self.updatedAt = updatedAt
        self.images = images
        self.variants = variants
    }
}

struct ShopifyImage: Sendable, Codable {
    let src: String

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        src = try container.decode(String.self, forKey: .src)
    }

    init(src: String) {
        self.src = src
    }
}

struct ShopifyVariant: Sendable, Codable {
    let id: Int64
    let title: String
    let sku: String?
    let available: Bool
    let position: Int
    let price: Decimal
    let compareAtPrice: Decimal?

    enum CodingKeys: String, CodingKey {
        case id, title, sku, available, position, price
        case compareAtPrice = "compare_at_price"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        sku = try container.decodeIfPresent(String.self, forKey: .sku)
        available = try container.decode(Bool.self, forKey: .available)
        position = try container.decode(Int.self, forKey: .position)

        let priceString = try container.decode(String.self, forKey: .price)
        price = Decimal(string: priceString) ?? 0

        if let compareString = try container.decodeIfPresent(String.self, forKey: .compareAtPrice) {
            compareAtPrice = Decimal(string: compareString)
        } else {
            compareAtPrice = nil
        }
    }

    init(
        id: Int64,
        title: String,
        sku: String?,
        price: Decimal,
        compareAtPrice: Decimal?,
        available: Bool,
        position: Int
    ) {
        self.id = id
        self.title = title
        self.sku = sku
        self.price = price
        self.compareAtPrice = compareAtPrice
        self.available = available
        self.position = position
    }
}
