//
//  PreviewHelpers.swift
//  watchify
//

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
