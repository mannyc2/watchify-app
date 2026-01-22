//
//  Store.swift
//  watchify
//

import Foundation
import SwiftData

@Model
final class Store {
    @Attribute(.unique) var id: UUID
    var name: String
    var domain: String
    var addedAt: Date
    var lastFetchedAt: Date?
    var isSyncing: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Product.store)
    var products: [Product] = []

    @Relationship(deleteRule: .cascade, inverse: \ChangeEvent.store)
    var changeEvents: [ChangeEvent] = []

    // MARK: - Denormalized fields (for N+1 prevention in StoreCard)

    /// Cached count of non-removed products
    var cachedProductCount: Int = 0

    /// Cached preview image URLs (first 3 products with images)
    var cachedPreviewImageURLs: [String] = []

    init(id: UUID = UUID(), name: String, domain: String, addedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.domain = domain
        self.addedAt = addedAt
    }

    /// Updates cached fields. Call after products are modified.
    func updateListingCache(products: [Product]) {
        cachedProductCount = products.filter { !$0.isRemoved }.count
        cachedPreviewImageURLs = products
            .filter { !$0.isRemoved && !$0.imageURLs.isEmpty }
            .prefix(3)
            .compactMap { $0.imageURLs.first }
    }
}
