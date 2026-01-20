//
//  Product.swift
//  watchify
//

import Foundation
import SwiftData

@Model
final class Product {
    @Attribute(.unique) var shopifyId: Int64
    var handle: String
    var title: String
    var vendor: String?
    var productType: String?
    var imageURL: URL?
    var firstSeenAt: Date
    var lastSeenAt: Date
    var isRemoved: Bool

    var store: Store?

    // a product has many variants
    // variants are usually different sizes or colors
    @Relationship(deleteRule: .cascade, inverse: \Variant.product)
    var variants: [Variant] = []

    init(
        shopifyId: Int64,
        handle: String,
        title: String,
        vendor: String? = nil,
        productType: String? = nil,
        imageURL: URL? = nil,
        firstSeenAt: Date = Date(),
        lastSeenAt: Date = Date(),
        isRemoved: Bool = false
    ) {
        self.shopifyId = shopifyId
        self.handle = handle
        self.title = title
        self.vendor = vendor
        self.productType = productType
        self.imageURL = imageURL
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.isRemoved = isRemoved
    }

    var currentPrice: Decimal {
        variants.first?.price ?? 0
    }

    var isAvailable: Bool {
        variants.contains { $0.available }
    }
}
