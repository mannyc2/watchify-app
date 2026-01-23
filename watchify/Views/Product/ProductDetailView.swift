//
//  ProductDetailView.swift
//  watchify
//

import QuickLook
import SwiftData
import SwiftUI

struct ProductDetailView: View {
    let product: Product

    @State private var selectedImageIndex = 0
    @State private var quickLookURL: URL?

    private var sortedVariants: [Variant] {
        product.variants.sorted { lhs, rhs in
            if lhs.position != rhs.position {
                return lhs.position < rhs.position
            }
            return lhs.shopifyId < rhs.shopifyId
        }
    }

    private var productURL: URL? {
        guard let domain = product.store?.domain else { return nil }
        return URL(string: "https://\(domain)/products/\(product.handle)")
    }

    private var imageURLs: [URL] {
        product.allImageURLs
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ViewThatFits(in: .horizontal) {
                    wideLayout
                    narrowLayout
                }
                priceHistorySection
            }
            .padding()
        }
        .navigationTitle(product.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let url = productURL {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.glass)

                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("Open in Browser", systemImage: "globe")
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .quickLookPreview($quickLookURL, in: imageURLs)
    }

    // MARK: - Image Section

    @ViewBuilder
    private func imageSection(layout: ImageGalleryLayout) -> some View {
        if imageURLs.isEmpty {
            ImagePlaceholder()
                .frame(maxWidth: .infinity)
                .aspectRatio(layout.aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if imageURLs.count == 1 {
            singleImageView(url: imageURLs[0], aspectRatio: layout.aspectRatio)
        } else {
            ProductImageCarousel(
                imageURLs: imageURLs,
                layout: layout,
                selectedIndex: $selectedImageIndex,
                onTapImage: { quickLookURL = $0 }
            )
        }
    }

    private func singleImageView(url: URL, aspectRatio: CGFloat) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(.fill.tertiary)
                    .overlay { ProgressView() }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .transition(.opacity)
            case .failure:
                ImagePlaceholder()
            @unknown default:
                ImagePlaceholder()
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            quickLookURL = url
        }
        .accessibilityLabel("Product image")
        .accessibilityHint("Tap to view full size")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(product.title)
                .font(.largeTitle.weight(.bold))

            if let vendor = product.vendor, !vendor.isEmpty {
                Text(vendor)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if let productType = product.productType, !productType.isEmpty {
                Text(productType)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Variants

    // Alternating row backgrounds + border for visual distinction, matching
    // the price history table styling for consistency across the app.
    private var variantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Variants")
                    .font(.headline)

                if !product.variants.isEmpty {
                    Badge(text: "\(product.variants.count)", color: .blue)
                        .accessibilityLabel("Number of variants: \(product.variants.count)")
                }
            }

            if sortedVariants.isEmpty {
                ContentUnavailableView(
                    "No Variants",
                    systemImage: "tray",
                    description: Text("This product has no variants.")
                )
                .frame(minHeight: 100)
            } else {
                VStack(spacing: 1) {
                    ForEach(Array(sortedVariants.enumerated()), id: \.element.id) { index, variant in
                        VariantRow(variant: variant)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(index.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.03))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Price History

    // Constrained to 1200pt max width and centered to match the wideLayout section above,
    // so the price history doesn't stretch full-width on large screens.
    @ViewBuilder
    private var priceHistorySection: some View {
        if let variant = sortedVariants.first {
            PriceHistorySection(variant: variant)
                .frame(maxWidth: 1200)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Responsive Layouts

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: 20) {
            imageSection(layout: .compact)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 16) {
                metadataSection
                variantsSection
            }
            .frame(minWidth: 280, maxWidth: 400, alignment: .leading)
        }
        .frame(maxWidth: 1200)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var narrowLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            imageSection(layout: .expanded)
            metadataSection
            variantsSection
        }
    }
}
