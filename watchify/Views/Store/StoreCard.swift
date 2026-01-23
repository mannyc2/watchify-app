//
//  StoreCard.swift
//  watchify
//

import SwiftUI

struct StoreCard: View {
    let store: StoreDTO
    let onSelect: () -> Void

    @State private var isHovering = false

    private let cornerRadius: CGFloat = 16

    private var previewImages: [URL] {
        store.cachedPreviewImageURLs.compactMap { URL(string: $0) }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Side-by-side images
                HStack(spacing: 4) {
                    if previewImages.isEmpty {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.fill.tertiary)
                            .aspectRatio(3, contentMode: .fit)
                            .overlay {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.largeTitle)
                                    .foregroundStyle(.quaternary)
                                    .accessibilityHidden(true)
                            }
                    } else {
                        ForEach(previewImages, id: \.self) { url in
                            CachedAsyncImage(url: url, displaySize: .storePreview) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Rectangle()
                                    .fill(.fill.tertiary)
                            }
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .clipped()
                            .accessibilityHidden(true)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Store info
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text("\(store.cachedProductCount) products")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contentShape(shape)
        .interactiveGlassCard(isHovering: isHovering, cornerRadius: cornerRadius)
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.18), value: isHovering)
        .accessibilityLabel("\(store.name), \(store.cachedProductCount) products")
    }
}

// MARK: - Previews

#Preview("Empty Store") {
    StoreCard(store: StoreDTO(name: "New Store", domain: "newstore.com")) {}
        .padding()
        .frame(width: 280)
}

#Preview("With Products") {
    let imageURLs = [
        "https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Runner_Natural_White_Profile.png",
        "https://cdn.shopify.com/s/files/1/1104/4168/products/Tree_Dasher_Blizzard.png",
        "https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Lounger_Natural_Grey.png"
    ]

    return StoreCard(
        store: StoreDTO(
            name: "Allbirds",
            domain: "allbirds.com",
            cachedProductCount: 42,
            cachedPreviewImageURLs: imageURLs
        )
    ) {}
    .padding()
    .frame(width: 280)
}
