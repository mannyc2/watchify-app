//
//  ChangeEvent.swift
//  watchify
//

import Foundation
import SwiftData

@Model
final class ChangeEvent {
    var id: UUID
    var occurredAt: Date
    var changeType: ChangeType
    var productTitle: String
    var variantTitle: String?
    var oldValue: String?
    var newValue: String?
    var priceChange: Decimal?
    var isRead: Bool
    var magnitude: ChangeMagnitude

    var store: Store?

    init(
        changeType: ChangeType,
        productTitle: String,
        variantTitle: String? = nil,
        oldValue: String? = nil,
        newValue: String? = nil,
        priceChange: Decimal? = nil,
        magnitude: ChangeMagnitude = .medium,
        store: Store? = nil
    ) {
        self.id = UUID()
        self.occurredAt = Date()
        self.changeType = changeType
        self.productTitle = productTitle
        self.variantTitle = variantTitle
        self.oldValue = oldValue
        self.newValue = newValue
        self.priceChange = priceChange
        self.isRead = false
        self.magnitude = magnitude
        self.store = store
    }
}

enum ChangeType: String, Codable, Sendable {
    case priceDropped
    case priceIncreased
    case backInStock
    case outOfStock
    case newProduct
    case productRemoved
    case imagesChanged
}

enum ChangeMagnitude: String, Codable, Sendable {
    case small    // < 10%
    case medium   // 10-25%
    case large    // > 25%
}

import SwiftUI

extension ChangeType {
    var icon: String {
        switch self {
        case .priceDropped, .priceIncreased: "tag.fill"
        case .backInStock, .outOfStock: "shippingbox.fill"
        case .newProduct: "bag.badge.plus"
        case .productRemoved: "bag.badge.minus"
        case .imagesChanged: "photo.on.rectangle"
        }
    }

    var color: Color {
        switch self {
        case .priceDropped: .green
        case .priceIncreased: .red
        case .backInStock: .blue
        case .outOfStock: .orange
        case .newProduct: .purple
        case .productRemoved: .secondary
        case .imagesChanged: .blue
        }
    }
}
