//
//  StoreDTO.swift
//  watchify
//

import Foundation

/// Sendable DTO for Store data used in views.
struct StoreDTO: Sendable, Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let domain: String
    let addedAt: Date
    let lastFetchedAt: Date?
    let isSyncing: Bool
    let cachedProductCount: Int
    let cachedPreviewImageURLs: [String]

    /// Creates a DTO from a Store. Must be called on the same actor as the store.
    nonisolated init(from store: Store) {
        self.id = store.id
        self.name = store.name
        self.domain = store.domain
        self.addedAt = store.addedAt
        self.lastFetchedAt = store.lastFetchedAt
        self.isSyncing = store.isSyncing
        self.cachedProductCount = store.cachedProductCount
        self.cachedPreviewImageURLs = store.cachedPreviewImageURLs
    }

    /// Direct init for previews/tests
    init(
        id: UUID = UUID(),
        name: String,
        domain: String = "",
        addedAt: Date = Date(),
        lastFetchedAt: Date? = nil,
        isSyncing: Bool = false,
        cachedProductCount: Int = 0,
        cachedPreviewImageURLs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.domain = domain
        self.addedAt = addedAt
        self.lastFetchedAt = lastFetchedAt
        self.isSyncing = isSyncing
        self.cachedProductCount = cachedProductCount
        self.cachedPreviewImageURLs = cachedPreviewImageURLs
    }
}
