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
    var firstSeenAt: Date
    var lastSeenAt: Date
    var isRemoved: Bool

    var store: Store?

    // a product has many variants
    // variants are usually different sizes or colors
    @Relationship(deleteRule: .cascade, inverse: \Variant.product)
    var variants: [Variant] = []

    /// Ordered array of image URLs (CDN URLs as strings)
    var imageURLs: [String] = []

    init(
        shopifyId: Int64,
        handle: String,
        title: String,
        vendor: String? = nil,
        productType: String? = nil,
        firstSeenAt: Date = Date(),
        lastSeenAt: Date = Date(),
        isRemoved: Bool = false
    ) {
        self.shopifyId = shopifyId
        self.handle = handle
        self.title = title
        self.vendor = vendor
        self.productType = productType
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.isRemoved = isRemoved
    }

    /// Returns the primary (first) image URL
    var primaryImageURL: URL? {
        imageURLs.first.flatMap { URL(string: $0) }
    }

    /// Returns all image URLs as URL objects
    var allImageURLs: [URL] {
        imageURLs.compactMap { URL(string: $0) }
    }

    /// Backward compatibility alias for primaryImageURL
    var imageURL: URL? {
        primaryImageURL
    }

    var currentPrice: Decimal {
        variants.first?.price ?? 0
    }

    var isAvailable: Bool {
        variants.contains { $0.available }
    }

    /// Returns the price change from the most recent snapshot, if any.
    /// Positive = price increased, Negative = price dropped, nil = no change or no history.
    var recentPriceChange: Decimal? {
        guard let variant = variants.first,
              let snapshot = variant.mostRecentSnapshot else { return nil }
        let change = variant.price - snapshot.price
        return change != 0 ? change : nil
    }
}
