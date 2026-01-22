//
//  ProductDTO.swift
//  watchify
//

import Foundation

/// Sendable DTO for transferring Product data from background actor to MainActor.
/// Contains only the fields needed for list display to minimize data transfer.
struct ProductDTO: Sendable, Identifiable, Equatable, Hashable {
    let shopifyId: Int64
    let title: String
    let imageURL: URL?
    let cachedPrice: Decimal
    let cachedIsAvailable: Bool
    let firstSeenAt: Date

    /// Use shopifyId as the Identifiable id
    var id: Int64 { shopifyId }

    /// Creates a DTO from a Product. Must be called on the same actor as the product.
    nonisolated init(from product: Product) {
        self.shopifyId = product.shopifyId
        self.title = product.title
        self.imageURL = product.primaryImageURL
        self.cachedPrice = product.cachedPrice
        self.cachedIsAvailable = product.cachedIsAvailable
        self.firstSeenAt = product.firstSeenAt
    }

    /// Direct initializer for previews and testing
    init(
        shopifyId: Int64,
        title: String,
        imageURL: URL? = nil,
        cachedPrice: Decimal,
        cachedIsAvailable: Bool,
        firstSeenAt: Date = Date()
    ) {
        self.shopifyId = shopifyId
        self.title = title
        self.imageURL = imageURL
        self.cachedPrice = cachedPrice
        self.cachedIsAvailable = cachedIsAvailable
        self.firstSeenAt = firstSeenAt
    }
}
