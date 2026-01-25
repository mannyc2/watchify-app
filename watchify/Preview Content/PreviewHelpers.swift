//
//  PreviewHelpers.swift
//  watchify
//

import Foundation
import SwiftData

/// Shared ModelContainer for SwiftUI previews. Uses in-memory storage.
func makePreviewContainer() -> ModelContainer {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Store.self, Product.self, Variant.self, VariantSnapshot.self, ChangeEvent.self,
            configurations: config
        )
    } catch {
        fatalError("Failed to create preview container: \(error)")
    }
}

// MARK: - Preview Assets

/// Asset names for preview images. Add corresponding images to PreviewAssets.xcassets.
enum PreviewAssets {
    static let product1 = "preview-product-1"
    static let product2 = "preview-product-2"
    static let product3 = "preview-product-3"
}

// MARK: - Sample Store Data

/// Sample stores for previews.
enum PreviewStores {
    static let allbirds = StoreDTO(
        name: "Allbirds",
        domain: "allbirds.com",
        lastFetchedAt: Date().addingTimeInterval(-3600),
        cachedProductCount: 42
    )

    static let gymshark = StoreDTO(
        name: "Gymshark",
        domain: "gymshark.com",
        lastFetchedAt: Date().addingTimeInterval(-86400),
        cachedProductCount: 128
    )

    static let mvmt = StoreDTO(
        name: "MVMT Watches",
        domain: "mvmt.com",
        lastFetchedAt: Date().addingTimeInterval(-7200),
        cachedProductCount: 15
    )

    static let empty = StoreDTO(
        name: "New Store",
        domain: "newstore.com"
    )

    static let syncing = StoreDTO(
        name: "Syncing Store",
        domain: "syncing.com",
        lastFetchedAt: Date().addingTimeInterval(-300),
        isSyncing: true,
        cachedProductCount: 64
    )
}
