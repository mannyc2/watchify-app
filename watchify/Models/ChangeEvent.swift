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
    var isRead: Bool
    var magnitude: ChangeMagnitude

    var store: Store?

    init(
        changeType: ChangeType,
        productTitle: String,
        variantTitle: String? = nil,
        oldValue: String? = nil,
        newValue: String? = nil,
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
        self.isRead = false
        self.magnitude = magnitude
        self.store = store
    }
}

enum ChangeType: String, Codable {
    case priceDropped
    case priceIncreased
    case backInStock
    case outOfStock
    case newProduct
    case productRemoved
}

enum ChangeMagnitude: String, Codable {
    case small    // < 10%
    case medium   // 10-25%
    case large    // > 25%
}
