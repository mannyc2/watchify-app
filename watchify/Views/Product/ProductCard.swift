//
//  ProductCardDTO.swift
//  watchify
//

import SwiftUI

/// Product card that displays a ProductDTO. Used in StoreDetailView for
/// efficient rendering without model object access on main thread.
struct ProductCardDTO: View {
    let product: ProductDTO

    @State private var isHovering = false

    private let cornerRadius: CGFloat = 12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        NavigationLink(value: product.shopifyId) {
            VStack(alignment: .leading, spacing: 8) {
                // Product image (square, AsyncImage)
                AsyncImage(url: product.imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(.fill.tertiary)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(.quaternary)
                        }
                }
                .frame(height: 120)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Title
                Text(product.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                // Price + stock badge
                HStack {
                    Text(product.cachedPrice, format: .currency(code: "USD"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                    Badge(
                        text: product.cachedIsAvailable ? "In Stock" : "Out",
                        color: product.cachedIsAvailable ? .green : .red
                    )
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contentShape(shape)
        .interactiveGlassCard(isHovering: isHovering, cornerRadius: cornerRadius)
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.18), value: isHovering)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let price = product.cachedPrice.formatted(.currency(code: "USD"))
        let stock = product.cachedIsAvailable ? "In stock" : "Out of stock"
        return "\(product.title), \(price), \(stock)"
    }
}

// MARK: - Previews

#Preview("In Stock") {
    ProductCardDTO(product: ProductDTO(
        shopifyId: 1,
        title: "Wool Runners",
        imageURL: URL(string: "https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Runner.png"),
        cachedPrice: 110,
        cachedIsAvailable: true
    ))
    .padding()
    .frame(width: 180)
}

#Preview("Out of Stock") {
    ProductCardDTO(product: ProductDTO(
        shopifyId: 2,
        title: "Tree Dashers",
        imageURL: URL(string: "https://cdn.shopify.com/s/files/1/1104/4168/products/Tree_Dasher.png"),
        cachedPrice: 125,
        cachedIsAvailable: false
    ))
    .padding()
    .frame(width: 180)
}

#Preview("No Image") {
    ProductCardDTO(product: ProductDTO(
        shopifyId: 3,
        title: "Mystery Product",
        cachedPrice: 49.99,
        cachedIsAvailable: true
    ))
    .padding()
    .frame(width: 180)
}

#Preview("Long Title") {
    ProductCardDTO(product: ProductDTO(
        shopifyId: 4,
        title: "Men's Tree Runner Go - Limited Edition Collaboration with Famous Designer",
        imageURL: URL(string: "https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Runner.png"),
        cachedPrice: 175,
        cachedIsAvailable: true
    ))
    .padding()
    .frame(width: 180)
}
