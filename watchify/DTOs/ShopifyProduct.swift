//
//  ShopifyProduct.swift
//  watchify
//

import Foundation

struct ShopifyProductsResponse: Codable {
    let products: [ShopifyProduct]
}

struct ShopifyProduct: Codable {
    let id: Int64
    let title: String
    let handle: String
    let vendor: String?
    let productType: String?
    let createdAt: Date?
    let images: [ShopifyImage]
    let variants: [ShopifyVariant]

    enum CodingKeys: String, CodingKey {
        case id, title, handle, vendor, images, variants
        case productType = "product_type"
        case createdAt = "created_at"
    }
}

struct ShopifyImage: Codable {
    let src: String
}

struct ShopifyVariant: Codable {
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

    init(from decoder: Decoder) throws {
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
}
