//
//  StoreCard.swift
//  watchify
//

import SwiftUI

/// Store card with hero image, glass overlay info strip, and floating product count badge.
struct StoreCard: View {
    let store: StoreDTO
    let onSelect: () -> Void

    /// Optional local asset name for preview use (bypasses network loading).
    var previewImageAsset: String?

    @State private var isHovering = false

    private let cornerRadius: CGFloat = 16

    private var heroImageURL: URL? {
        store.cachedPreviewImageURLs.first.flatMap { URL(string: $0) }
    }

    private var lastSyncedText: String? {
        guard let date = store.lastFetchedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Button(action: onSelect) {
            ZStack(alignment: .bottom) {
                // Hero image with stats badge
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let assetName = previewImageAsset {
                            // Preview mode: use local asset
                            Image(assetName)
                                .resizable()
                                .scaledToFill()
                        } else if let url = heroImageURL {
                            CachedAsyncImage(
                                url: url,
                                displaySize: .storePreview
                            ) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Rectangle().fill(.fill.tertiary)
                            }
                        } else {
                            Rectangle()
                                .fill(.fill.tertiary)
                                .overlay {
                                    Image(systemName: "storefront")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.quaternary)
                                }
                        }
                    }
                    .frame(height: 180)
                    .clipped()
                    .accessibilityHidden(true)

                    // Floating product count badge
                    HStack(spacing: 4) {
                        Image(systemName: "cube.box")
                            .font(.caption2)
                            .accessibilityHidden(true)
                        Text("\(store.cachedProductCount)")
                            .font(.caption.monospacedDigit())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassPill()
                    .padding(8)
                }

                // Bottom glass strip
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.name)
                            .font(.headline)
                            .lineLimit(1)

                        if let synced = lastSyncedText {
                            Text("Synced \(synced)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Never synced")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    if store.isSyncing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .compositingGroup()
                .background {
                    Color.clear.glassEffect(.regular, in: Rectangle())
                }
            }
            .clipShape(shape)
        }
        .buttonStyle(.plain)
        .contentShape(shape)
        .overlay { shape.strokeBorder(.white.opacity(isHovering ? 0.22 : 0.10), lineWidth: 1) }
        .shadow(radius: isHovering ? 6 : 3)
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.18), value: isHovering)
        .accessibilityLabel("\(store.name), \(store.cachedProductCount) products")
    }
}

// MARK: - Previews

#Preview("Empty Store") {
    StoreCard(store: PreviewStores.empty) {}
        .padding()
        .frame(width: 320)
}

#Preview("With Products") {
    StoreCard(
        store: PreviewStores.allbirds,
        onSelect: {},
        previewImageAsset: PreviewAssets.product1
    )
    .padding()
    .frame(width: 320)
}

#Preview("Syncing") {
    StoreCard(
        store: PreviewStores.syncing,
        onSelect: {},
        previewImageAsset: PreviewAssets.product2
    )
    .padding()
    .frame(width: 320)
}
