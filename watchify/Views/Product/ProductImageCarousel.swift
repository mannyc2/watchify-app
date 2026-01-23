//
//  ProductImageCarousel.swift
//  watchify
//

import SwiftUI

/// Layout configuration for image gallery display
enum ImageGalleryLayout {
    case compact   // Wide layout (side-by-side): 1:1 aspect ratio
    case expanded  // Narrow layout (full width): 4:3 aspect ratio

    var aspectRatio: CGFloat {
        switch self {
        case .compact: 1.0
        case .expanded: 4.0 / 3.0
        }
    }

    var thumbnailSize: CGFloat {
        switch self {
        case .compact: 64
        case .expanded: 80
        }
    }
}

/// Direction for carousel navigation
enum CarouselDirection {
    case previous, next

    var systemImage: String {
        switch self {
        case .previous: "chevron.left"
        case .next: "chevron.right"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .previous: "Previous image"
        case .next: "Next image"
        }
    }
}

/// A carousel view for displaying multiple product images with thumbnail navigation
struct ProductImageCarousel: View {
    let imageURLs: [URL]
    let layout: ImageGalleryLayout
    @Binding var selectedIndex: Int
    var onTapImage: ((URL) -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Color.clear
                .aspectRatio(layout.aspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    CachedAsyncImage(url: imageURLs[selectedIndex], displaySize: .fullSize) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .transition(.opacity)
                    } placeholder: {
                        ProgressView()
                    }
                    .id(selectedIndex)
                }
                .overlay {
                    HStack {
                        carouselButton(direction: .previous)
                        Spacer()
                        carouselButton(direction: .next)
                    }
                    .padding(8)
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onTapGesture {
                    onTapImage?(imageURLs[selectedIndex])
                }
                .accessibilityAddTraits(.isButton)
                .focusable()
                .onKeyPress(.leftArrow) {
                    withAnimation { navigateCarousel(.previous) }
                    return .handled
                }
                .onKeyPress(.rightArrow) {
                    withAnimation { navigateCarousel(.next) }
                    return .handled
                }
                .accessibilityLabel("Product image \(selectedIndex + 1) of \(imageURLs.count)")
                .accessibilityHint("Tap to view full size")

            thumbnailStrip(size: layout.thumbnailSize)
        }
    }

    private func carouselButton(direction: CarouselDirection) -> some View {
        Button {
            withAnimation { navigateCarousel(direction) }
        } label: {
            Image(systemName: direction.systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(direction.accessibilityLabel)
    }

    private func navigateCarousel(_ direction: CarouselDirection) {
        let count = imageURLs.count
        switch direction {
        case .previous:
            selectedIndex = (selectedIndex - 1 + count) % count
        case .next:
            selectedIndex = (selectedIndex + 1) % count
        }
    }

    private func thumbnailStrip(size: CGFloat) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                CachedAsyncImage(
                    url: url,
                    displaySize: layout == .compact ? .thumbnailCompact : .thumbnailExpanded
                ) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(.fill.tertiary)
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(selectedIndex == index ? Color.accentColor : .clear, lineWidth: 2)
                }
                .onTapGesture {
                    withAnimation { selectedIndex = index }
                }
                .accessibilityLabel("Image \(index + 1)")
                .accessibilityAddTraits(.isButton)
                .accessibilityAddTraits(selectedIndex == index ? .isSelected : [])
            }
        }
    }
}

/// Placeholder view for missing or failed images
struct ImagePlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(.fill.tertiary)
            .overlay {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.quaternary)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("No image available")
    }
}
