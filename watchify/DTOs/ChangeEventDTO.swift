//
//  ChangeEventDTO.swift
//  watchify
//

import Foundation

/// Sendable DTO for transferring ChangeEvent data from background actor to MainActor.
/// Includes denormalized store fields to avoid relationship traversal on the main thread.
struct ChangeEventDTO: Sendable, Identifiable, Equatable {
    let id: UUID
    let occurredAt: Date
    let changeType: ChangeType
    let productTitle: String
    let variantTitle: String?
    let oldValue: String?
    let newValue: String?
    let priceChange: Decimal?
    let isRead: Bool
    let magnitude: ChangeMagnitude

    /// Shopify product ID for navigation. Nil for removed products.
    let productShopifyId: Int64?

    /// Product image URL for thumbnails. Nil for removed products or products without images.
    let productImageURL: String?

    // Denormalized store fields to avoid N+1 relationship faults
    let storeId: UUID?
    let storeName: String?

    /// Memberwise initializer with defaults for direct construction (e.g., in tests).
    nonisolated init(
        changeType: ChangeType,
        productTitle: String,
        variantTitle: String? = nil,
        oldValue: String? = nil,
        newValue: String? = nil,
        priceChange: Decimal? = nil,
        magnitude: ChangeMagnitude = .small,
        productShopifyId: Int64? = nil,
        productImageURL: String? = nil,
        id: UUID = UUID(),
        occurredAt: Date = Date(),
        isRead: Bool = false,
        storeId: UUID? = nil,
        storeName: String? = nil
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.changeType = changeType
        self.productTitle = productTitle
        self.variantTitle = variantTitle
        self.oldValue = oldValue
        self.newValue = newValue
        self.priceChange = priceChange
        self.isRead = isRead
        self.magnitude = magnitude
        self.productShopifyId = productShopifyId
        self.productImageURL = productImageURL
        self.storeId = storeId
        self.storeName = storeName
    }

    /// Creates a DTO from a ChangeEvent. Must be called on the same actor as the event.
    /// Marked nonisolated to avoid MainActor hop when called from background ModelActor.
    /// - Parameter productImageURL: Optional image URL, passed in when batch-fetching events
    nonisolated init(from event: ChangeEvent, productImageURL: String? = nil) {
        self.id = event.id
        self.occurredAt = event.occurredAt
        self.changeType = event.changeType
        self.productTitle = event.productTitle
        self.variantTitle = event.variantTitle
        self.oldValue = event.oldValue
        self.newValue = event.newValue
        self.priceChange = event.priceChange
        self.isRead = event.isRead
        self.magnitude = event.magnitude
        self.productShopifyId = event.productShopifyId
        self.productImageURL = productImageURL
        self.storeId = event.store?.id
        self.storeName = event.store?.name
    }
}
