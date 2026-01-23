//
//  Product.swift
//  watchify
//

import Foundation
import SwiftData

@Model
final class Product {
    // MARK: - Indexes (macOS 15+ / iOS 18+)
    // Compound indexes for common query patterns
    #Index<Product>(
        [\.store],
        [\.store, \.isRemoved],
        [\.store, \.cachedIsAvailable],
        [\.store, \.cachedPrice],
        [\.store, \.titleSearchKey]
    )

    @Attribute(.unique) var shopifyId: Int64
    var handle: String
    var title: String
    var vendor: String?
    var productType: String?
    var firstSeenAt: Date
    var isRemoved: Bool

    var store: Store?

    // a product has many variants
    // variants are usually different sizes or colors
    @Relationship(deleteRule: .cascade, inverse: \Variant.product)
    var variants: [Variant] = []

    /// Ordered array of image URLs (CDN URLs as strings)
    var imageURLs: [String] = []

    // MARK: - Denormalized listing fields (for N+1 prevention)
    // These are computed from variants during sync to avoid relationship faults in list views

    /// Cached price from the first variant (for list display)
    var cachedPrice: Decimal = 0

    /// Cached availability status (true if any variant is available)
    var cachedIsAvailable: Bool = false

    /// Lowercase/normalized title for fast text search
    var titleSearchKey: String = ""

    init(
        shopifyId: Int64,
        handle: String,
        title: String,
        vendor: String? = nil,
        productType: String? = nil,
        firstSeenAt: Date = Date(),
        isRemoved: Bool = false
    ) {
        self.shopifyId = shopifyId
        self.handle = handle
        self.title = title
        self.vendor = vendor
        self.productType = productType
        self.firstSeenAt = firstSeenAt
        self.isRemoved = isRemoved
        self.titleSearchKey = Self.makeSearchKey(title)
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

    // MARK: - Listing Cache Helpers

    /// Updates the denormalized listing fields from the variants relationship.
    /// Call this after variants are modified (during sync or backfill).
    func updateListingCache() {
        let sortedVariants = variants.sorted { $0.position < $1.position }
        cachedPrice = sortedVariants.first?.price ?? 0
        cachedIsAvailable = sortedVariants.contains { $0.available }
        titleSearchKey = Self.makeSearchKey(title)
    }

    /// Updates the listing cache directly from DTOs (no relationship traversal).
    /// Use this during sync when you have the variant DTOs available.
    func updateListingCache(from variantDTOs: [ShopifyVariant]) {
        let sorted = variantDTOs.sorted { $0.position < $1.position }
        cachedPrice = sorted.first?.price ?? 0
        cachedIsAvailable = sorted.contains { $0.available }
        titleSearchKey = Self.makeSearchKey(title)
    }

    /// Creates a normalized search key for fast text matching.
    static func makeSearchKey(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
