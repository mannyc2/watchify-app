//
//  VariantSnapshot.swift
//  watchify
//

import Foundation
import SwiftData

@Model
final class VariantSnapshot {
    var capturedAt: Date
    var price: Decimal
    var compareAtPrice: Decimal?
    var available: Bool

    var variant: Variant?

    init(
        capturedAt: Date = Date(),
        price: Decimal,
        compareAtPrice: Decimal? = nil,
        available: Bool
    ) {
        self.capturedAt = capturedAt
        self.price = price
        self.compareAtPrice = compareAtPrice
        self.available = available
    }
}
