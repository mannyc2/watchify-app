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
}
