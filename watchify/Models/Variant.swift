//
//  Variant.swift
//  watchify
//

import Foundation
import SwiftData

@Model
final class Variant {
    @Attribute(.unique) var shopifyId: Int64
    var title: String
    var sku: String?
    var price: Decimal
    var compareAtPrice: Decimal?
    var available: Bool
    var position: Int

    var product: Product?

    @Relationship(deleteRule: .cascade, inverse: \VariantSnapshot.variant)
    var snapshots: [VariantSnapshot] = []

    init(
        shopifyId: Int64,
        title: String,
        sku: String? = nil,
        price: Decimal,
        compareAtPrice: Decimal? = nil,
        available: Bool,
        position: Int
    ) {
        self.shopifyId = shopifyId
        self.title = title
        self.sku = sku
        self.price = price
        self.compareAtPrice = compareAtPrice
        self.available = available
        self.position = position
    }

    // MARK: - Convenience Computed Properties

    /// Returns all snapshots sorted chronologically (oldest to newest)
    var priceHistory: [VariantSnapshot] {
        snapshots.sorted { $0.capturedAt < $1.capturedAt }
    }

    /// Returns the most recent snapshot, if any
    var mostRecentSnapshot: VariantSnapshot? {
        snapshots.max { $0.capturedAt < $1.capturedAt }
    }
}
