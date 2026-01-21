//
//  ProductCard.swift
//  watchify
//

import SwiftData
import SwiftUI

struct ProductCard: View {
    let product: Product

    @State private var isHovering = false

    private let cornerRadius: CGFloat = 12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        NavigationLink(value: product) {
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

                // Price + change indicator + stock badge
                HStack {
                    Text(product.currentPrice, format: .currency(code: "USD"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let change = product.recentPriceChange {
                        PriceChangeIndicator(change: change)
                    }

                    Spacer()
                    Badge(
                        text: product.isAvailable ? "In Stock" : "Out",
                        color: product.isAvailable ? .green : .red
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
        let price = product.currentPrice.formatted(.currency(code: "USD"))
        let stock = product.isAvailable ? "In stock" : "Out of stock"
        var label = "\(product.title), \(price)"
        if let change = product.recentPriceChange {
            let changeAmount = abs(change).formatted(.currency(code: "USD"))
            label += change > 0 ? ", price increased by \(changeAmount)" : ", price dropped by \(changeAmount)"
        }
        return "\(label), \(stock)"
    }
}

// MARK: - Previews

#Preview("In Stock") {
    let container = makePreviewContainer()
    let product = Product(
        shopifyId: 1,
        handle: "wool-runners",
        title: "Wool Runners"
    )
    product.imageURLs = ["https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Runner.png"]
    container.mainContext.insert(product)

    let variant = Variant(
        shopifyId: 100,
        title: "Size 10",
        price: Decimal(110),
        available: true,
        position: 0
    )
    variant.product = product
    container.mainContext.insert(variant)

    return ProductCard(product: product)
        .padding()
        .frame(width: 180)
        .modelContainer(container)
}

#Preview("Out of Stock") {
    let container = makePreviewContainer()
    let product = Product(
        shopifyId: 2,
        handle: "tree-dashers",
        title: "Tree Dashers"
    )
    product.imageURLs = ["https://cdn.shopify.com/s/files/1/1104/4168/products/Tree_Dasher.png"]
    container.mainContext.insert(product)

    let variant = Variant(
        shopifyId: 200,
        title: "Size 9",
        price: Decimal(125),
        available: false,
        position: 0
    )
    variant.product = product
    container.mainContext.insert(variant)

    return ProductCard(product: product)
        .padding()
        .frame(width: 180)
        .modelContainer(container)
}

#Preview("No Image") {
    let container = makePreviewContainer()
    let product = Product(
        shopifyId: 3,
        handle: "mystery-product",
        title: "Mystery Product"
    )
    container.mainContext.insert(product)

    let variant = Variant(
        shopifyId: 300,
        title: "Default",
        price: Decimal(49.99),
        available: true,
        position: 0
    )
    variant.product = product
    container.mainContext.insert(variant)

    return ProductCard(product: product)
        .padding()
        .frame(width: 180)
        .modelContainer(container)
}

#Preview("Long Title") {
    let container = makePreviewContainer()
    let product = Product(
        shopifyId: 4,
        handle: "super-long-product-name",
        title: "Men's Tree Runner Go - Limited Edition Collaboration with Famous Designer"
    )
    product.imageURLs = ["https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Runner.png"]
    container.mainContext.insert(product)

    let variant = Variant(
        shopifyId: 400,
        title: "Size 10",
        price: Decimal(175),
        available: true,
        position: 0
    )
    variant.product = product
    container.mainContext.insert(variant)

    return ProductCard(product: product)
        .padding()
        .frame(width: 180)
        .modelContainer(container)
}

#Preview("Price Dropped") {
    let container = makePreviewContainer()
    let product = Product(
        shopifyId: 5,
        handle: "wool-runners-sale",
        title: "Wool Runners"
    )
    product.imageURLs = ["https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Runner.png"]
    container.mainContext.insert(product)

    let variant = Variant(
        shopifyId: 500,
        title: "Size 10",
        price: Decimal(95),  // Current price
        available: true,
        position: 0
    )
    variant.product = product
    container.mainContext.insert(variant)

    // Add snapshot with old higher price
    let snapshot = VariantSnapshot(
        capturedAt: Date().addingTimeInterval(-86400),
        price: Decimal(110),  // Was $110, now $95 = -$15
        available: true
    )
    snapshot.variant = variant
    container.mainContext.insert(snapshot)

    return ProductCard(product: product)
        .padding()
        .frame(width: 180)
        .modelContainer(container)
}

#Preview("Price Increased") {
    let container = makePreviewContainer()
    let product = Product(
        shopifyId: 6,
        handle: "tree-dashers-increase",
        title: "Tree Dashers"
    )
    product.imageURLs = ["https://cdn.shopify.com/s/files/1/1104/4168/products/Tree_Dasher.png"]
    container.mainContext.insert(product)

    let variant = Variant(
        shopifyId: 600,
        title: "Size 9",
        price: Decimal(135),  // Current price
        available: true,
        position: 0
    )
    variant.product = product
    container.mainContext.insert(variant)

    // Add snapshot with old lower price
    let snapshot = VariantSnapshot(
        capturedAt: Date().addingTimeInterval(-86400),
        price: Decimal(125),  // Was $125, now $135 = +$10
        available: true
    )
    snapshot.variant = variant
    container.mainContext.insert(snapshot)

    return ProductCard(product: product)
        .padding()
        .frame(width: 180)
        .modelContainer(container)
}

#Preview("Grid Layout") {
    let container = makePreviewContainer()
    let imageBase = "https://cdn.shopify.com/s/files/1/1104/4168/products"

    let products = [
        Product(shopifyId: 1, handle: "wool-runners", title: "Wool Runners"),
        Product(shopifyId: 2, handle: "tree-dashers", title: "Tree Dashers"),
        Product(shopifyId: 3, handle: "wool-loungers", title: "Wool Loungers"),
        Product(shopifyId: 4, handle: "tree-breezers", title: "Tree Breezers")
    ]

    let images: [String?] = [
        "\(imageBase)/Wool_Runner.png", "\(imageBase)/Tree_Dasher.png",
        nil, "\(imageBase)/Wool_Lounger.png"
    ]
    let prices: [Decimal] = [110, 125, 95, 100]
    let availability = [true, true, false, true]

    for (idx, product) in products.enumerated() {
        if let imageURL = images[idx] {
            product.imageURLs = [imageURL]
        }
        container.mainContext.insert(product)
        let variant = Variant(
            shopifyId: Int64(idx + 100),
            title: "Default",
            price: prices[idx],
            available: availability[idx],
            position: 0
        )
        variant.product = product
        container.mainContext.insert(variant)
    }

    return ScrollView {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160, maximum: 200))],
            spacing: 12
        ) {
            ForEach(products) { product in
                ProductCard(product: product)
            }
        }
        .padding()
    }
    .frame(width: 450, height: 400)
    .modelContainer(container)
}
