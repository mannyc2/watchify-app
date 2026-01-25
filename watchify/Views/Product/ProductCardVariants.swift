//
//  ProductCardVariants.swift
//  watchify
//
//  Creative design exploration for ProductCard.
//

import SwiftUI

// MARK: - Sample Data

private enum SampleProducts {
    static let basic = ProductDTO(
        shopifyId: 1,
        title: "Wool Runners",
        imageURL: nil,
        cachedPrice: 110,
        cachedIsAvailable: true
    )

    static let outOfStock = ProductDTO(
        shopifyId: 2,
        title: "Tree Dashers",
        imageURL: nil,
        cachedPrice: 125,
        cachedIsAvailable: false
    )

    static let longTitle = ProductDTO(
        shopifyId: 3,
        title: "Men's Tree Runner Go - Limited Edition",
        imageURL: nil,
        cachedPrice: 175,
        cachedIsAvailable: true
    )
}

// MARK: - Variant A: Diagonal Ribbon

/// Corner ribbon for deals, image bleeds to edge.
struct ProductCardRibbon: View {
    let product: ProductDTO
    var previewImageAsset: String?
    var dealText: String?

    @State private var isHovering = false
    private let cornerRadius: CGFloat = 16

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        NavigationLink(value: product.shopifyId) {
            ZStack {
                // Full bleed image
                imageView
                    .overlay {
                        LinearGradient(
                            colors: [.clear, .clear, .black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                // Diagonal ribbon
                if let deal = dealText {
                    ribbonView(deal)
                }

                // Bottom info
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                            Text(product.cachedPrice, format: .currency(code: "USD"))
                                .font(.title3.weight(.bold))
                        }
                        Spacer()
                        if !product.cachedIsAvailable {
                            Text("SOLD OUT")
                                .font(.caption2.weight(.black))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.red)
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(12)
                }
            }
            .frame(height: 220)
            .clipShape(shape)
        }
        .buttonStyle(.plain)
        .contentShape(shape)
        .overlay {
            shape.strokeBorder(.white.opacity(isHovering ? 0.3 : 0.1), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.3), radius: isHovering ? 12 : 6, y: isHovering ? 8 : 4)
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
    }

    private func ribbonView(_ text: String) -> some View {
        GeometryReader { _ in
            Text(text)
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 6)
                .background(.green.gradient)
                .rotationEffect(.degrees(-45))
                .position(x: 40, y: 40)
        }
    }

    @ViewBuilder
    private var imageView: some View {
        if let asset = previewImageAsset {
            Image(asset)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(.fill.tertiary)
                .overlay {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.quaternary)
                }
        }
    }
}

// MARK: - Variant B: Split Card

/// Half image, half colored panel with info.
struct ProductCardSplit: View {
    let product: ProductDTO
    var previewImageAsset: String?
    var accentColor: Color = .blue

    @State private var isHovering = false
    private let cornerRadius: CGFloat = 16

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        NavigationLink(value: product.shopifyId) {
            HStack(spacing: 0) {
                // Image half
                imageView
                    .frame(width: 100)
                    .clipped()

                // Info half
                VStack(alignment: .leading, spacing: 8) {
                    Spacer()

                    Text(product.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(3)

                    Text(product.cachedPrice, format: .currency(code: "USD"))
                        .font(.title2.weight(.black))

                    HStack(spacing: 4) {
                        Circle()
                            .fill(product.cachedIsAvailable ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(product.cachedIsAvailable ? "Available" : "Sold out")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(accentColor.opacity(0.08))
            }
            .frame(height: 160)
            .clipShape(shape)
        }
        .buttonStyle(.plain)
        .contentShape(shape)
        .interactiveGlassCard(isHovering: isHovering, cornerRadius: cornerRadius)
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.2), value: isHovering)
    }

    @ViewBuilder
    private var imageView: some View {
        if let asset = previewImageAsset {
            Image(asset)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(.fill.tertiary)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.quaternary)
                }
        }
    }
}

// MARK: - Variant C: Sparkline Card

/// Mini price history chart on card.
struct ProductCardSparkline: View {
    let product: ProductDTO
    var previewImageAsset: String?

    // Mock price history for preview
    var priceHistory: [Decimal] = [120, 115, 125, 110, 105, 110]

    @State private var isHovering = false
    private let cornerRadius: CGFloat = 12

    private var priceChange: Decimal {
        guard let first = priceHistory.first, let last = priceHistory.last else { return 0 }
        return last - first
    }

    private var isDown: Bool { priceChange < 0 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        NavigationLink(value: product.shopifyId) {
            VStack(alignment: .leading, spacing: 0) {
                // Image
                imageView
                    .frame(height: 100)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(8)

                // Sparkline
                HStack(spacing: 0) {
                    sparklineView
                        .frame(height: 30)
                        .padding(.horizontal, 8)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.title)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline) {
                        Text(product.cachedPrice, format: .currency(code: "USD"))
                            .font(.headline.weight(.bold))

                        if priceChange != 0 {
                            HStack(spacing: 2) {
                                Image(systemName: isDown ? "arrow.down.right" : "arrow.up.right")
                                    .font(.caption2.weight(.bold))
                                Text(abs(priceChange), format: .currency(code: "USD"))
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(isDown ? .green : .red)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contentShape(shape)
        .interactiveGlassCard(isHovering: isHovering, cornerRadius: cornerRadius)
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.18), value: isHovering)
    }

    private var sparklineView: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let prices = priceHistory.map { NSDecimalNumber(decimal: $0).doubleValue }
            guard let minPrice = prices.min(), let maxPrice = prices.max(), maxPrice > minPrice else {
                return AnyView(EmptyView())
            }
            let range = maxPrice - minPrice
            let stepX = width / CGFloat(prices.count - 1)

            let path = Path { pathBuilder in
                for (index, price) in prices.enumerated() {
                    let pointX = CGFloat(index) * stepX
                    let pointY = height - (CGFloat((price - minPrice) / range) * height)
                    if index == 0 {
                        pathBuilder.move(to: CGPoint(x: pointX, y: pointY))
                    } else {
                        pathBuilder.addLine(to: CGPoint(x: pointX, y: pointY))
                    }
                }
            }

            return AnyView(
                path.stroke(
                    isDown ? Color.green : Color.red,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            )
        }
    }

    @ViewBuilder
    private var imageView: some View {
        if let asset = previewImageAsset {
            Image(asset)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(.fill.tertiary)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.quaternary)
                }
        }
    }
}

// MARK: - Variant D: Stacked Depth

/// Layered card with depth effect.
struct ProductCardStacked: View {
    let product: ProductDTO
    var previewImageAsset: String?
    var priceDropPercent: Int?

    @State private var isHovering = false
    private let cornerRadius: CGFloat = 14

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        NavigationLink(value: product.shopifyId) {
            ZStack {
                // Back layer (shadow card)
                shape
                    .fill(.primary.opacity(0.05))
                    .offset(x: 6, y: 6)

                // Middle layer
                shape
                    .fill(.primary.opacity(0.08))
                    .offset(x: 3, y: 3)

                // Main card
                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .bottomTrailing) {
                        imageView
                            .frame(height: 120)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        if let percent = priceDropPercent {
                            Text("-\(percent)%")
                                .font(.caption.weight(.black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    .green.gradient,
                                    in: UnevenRoundedRectangle(topLeadingRadius: 10, bottomTrailingRadius: 10)
                                )
                        }
                    }

                    Text(product.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)

                    HStack {
                        Text(product.cachedPrice, format: .currency(code: "USD"))
                            .font(.headline.weight(.bold))

                        Spacer()

                        Circle()
                            .fill(product.cachedIsAvailable ? .green : .red)
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(10)
                .background {
                    shape.fill(.background)
                }
                .overlay {
                    shape.strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(shape)
        .shadow(color: .black.opacity(0.15), radius: isHovering ? 20 : 10, y: isHovering ? 10 : 5)
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isHovering)
    }

    @ViewBuilder
    private var imageView: some View {
        if let asset = previewImageAsset {
            Image(asset)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(.fill.tertiary)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.quaternary)
                }
        }
    }
}

// MARK: - Variant E: Notification Style

/// Looks like a system notification with action context.
struct ProductCardNotification: View {
    let product: ProductDTO
    var previewImageAsset: String?

    var changeType: ChangeType?

    enum ChangeType {
        case priceDrop(from: Decimal)
        case backInStock
        case newProduct

        var icon: String {
            switch self {
            case .priceDrop: return "arrow.down.circle.fill"
            case .backInStock: return "shippingbox.fill"
            case .newProduct: return "sparkles"
            }
        }

        var color: Color {
            switch self {
            case .priceDrop: return .green
            case .backInStock: return .orange
            case .newProduct: return .blue
            }
        }

        var title: String {
            switch self {
            case .priceDrop: return "Price Drop"
            case .backInStock: return "Back in Stock"
            case .newProduct: return "New Product"
            }
        }
    }

    @State private var isHovering = false
    private let cornerRadius: CGFloat = 14

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        NavigationLink(value: product.shopifyId) {
            HStack(spacing: 12) {
                // Product thumbnail
                imageView
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    // Change type header
                    if let change = changeType {
                        HStack(spacing: 4) {
                            Image(systemName: change.icon)
                                .font(.caption2)
                            Text(change.title)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(change.color)
                    }

                    Text(product.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    // Price info
                    HStack(spacing: 6) {
                        Text(product.cachedPrice, format: .currency(code: "USD"))
                            .font(.callout.weight(.bold))

                        if case .priceDrop(let oldPrice) = changeType {
                            Text(oldPrice, format: .currency(code: "USD"))
                                .font(.caption)
                                .strikethrough()
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
        }
        .buttonStyle(.plain)
        .contentShape(shape)
        .interactiveGlassCard(isHovering: isHovering, cornerRadius: cornerRadius)
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.18), value: isHovering)
    }

    @ViewBuilder
    private var imageView: some View {
        if let asset = previewImageAsset {
            Image(asset)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(.fill.tertiary)
                .overlay {
                    Image(systemName: "photo")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
        }
    }
}

// MARK: - Variant F: Bold Typography

/// Large, bold price dominates. Minimal other info.
struct ProductCardBoldPrice: View {
    let product: ProductDTO
    var previewImageAsset: String?
    var originalPrice: Decimal?

    @State private var isHovering = false
    private let cornerRadius: CGFloat = 16

    private var hasDiscount: Bool {
        originalPrice != nil && originalPrice! > product.cachedPrice
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        NavigationLink(value: product.shopifyId) {
            VStack(spacing: 0) {
                // Image
                imageView
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
                    .clipped()

                // Price dominant section
                VStack(alignment: .leading, spacing: 6) {
                    // Giant price
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(product.cachedPrice, format: .currency(code: "USD"))
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(hasDiscount ? .green : .primary)

                        if let original = originalPrice, hasDiscount {
                            Text(original, format: .currency(code: "USD"))
                                .font(.callout.weight(.medium))
                                .strikethrough()
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Text(product.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .compositingGroup()
                .background {
                    Color.clear.glassEffect(.regular, in: Rectangle())
                }
            }
            .clipShape(shape)
        }
        .buttonStyle(.plain)
        .contentShape(shape)
        .overlay {
            shape.strokeBorder(.white.opacity(isHovering ? 0.25 : 0.1), lineWidth: 1)
        }
        .shadow(radius: isHovering ? 8 : 4)
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.18), value: isHovering)
    }

    @ViewBuilder
    private var imageView: some View {
        if let asset = previewImageAsset {
            Image(asset)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(.fill.tertiary)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.quaternary)
                }
        }
    }
}

// MARK: - Previews

#Preview("A: Diagonal Ribbon") {
    HStack {
        ProductCardRibbon(
            product: SampleProducts.basic,
            previewImageAsset: PreviewAssets.product1,
            dealText: "SAVE 20%"
        )
        ProductCardRibbon(
            product: SampleProducts.outOfStock,
            previewImageAsset: PreviewAssets.product2
        )
    }
    .padding()
    .frame(width: 420)
}

#Preview("B: Split Card") {
    VStack {
        ProductCardSplit(
            product: SampleProducts.basic,
            previewImageAsset: PreviewAssets.product1,
            accentColor: .green
        )
        ProductCardSplit(
            product: SampleProducts.outOfStock,
            previewImageAsset: PreviewAssets.product2,
            accentColor: .orange
        )
    }
    .padding()
    .frame(width: 280)
}

#Preview("C: Sparkline") {
    HStack {
        ProductCardSparkline(
            product: SampleProducts.basic,
            previewImageAsset: PreviewAssets.product1,
            priceHistory: [130, 125, 120, 115, 110, 110]
        )
        ProductCardSparkline(
            product: SampleProducts.outOfStock,
            previewImageAsset: PreviewAssets.product2,
            priceHistory: [100, 105, 110, 115, 120, 125]
        )
    }
    .padding()
    .frame(width: 380)
}

#Preview("D: Stacked Depth") {
    HStack {
        ProductCardStacked(
            product: SampleProducts.basic,
            previewImageAsset: PreviewAssets.product1,
            priceDropPercent: 25
        )
        ProductCardStacked(
            product: SampleProducts.longTitle,
            previewImageAsset: PreviewAssets.product2
        )
    }
    .padding(20)
    .frame(width: 420)
}

#Preview("E: Notification Style") {
    VStack {
        ProductCardNotification(
            product: SampleProducts.basic,
            previewImageAsset: PreviewAssets.product1,
            changeType: .priceDrop(from: 140)
        )
        ProductCardNotification(
            product: SampleProducts.outOfStock,
            previewImageAsset: PreviewAssets.product2,
            changeType: .backInStock
        )
        ProductCardNotification(
            product: SampleProducts.longTitle,
            previewImageAsset: PreviewAssets.product3,
            changeType: .newProduct
        )
    }
    .padding()
    .frame(width: 340)
}

#Preview("F: Bold Price") {
    HStack {
        ProductCardBoldPrice(
            product: SampleProducts.basic,
            previewImageAsset: PreviewAssets.product1,
            originalPrice: 150
        )
        ProductCardBoldPrice(
            product: SampleProducts.outOfStock,
            previewImageAsset: PreviewAssets.product2
        )
    }
    .padding()
    .frame(width: 400)
}

#Preview("All Variants") {
    ScrollView {
        VStack(alignment: .leading, spacing: 32) {
            Group {
                Text("A: Diagonal Ribbon").font(.headline)
                ProductCardRibbon(
                    product: SampleProducts.basic,
                    previewImageAsset: PreviewAssets.product1,
                    dealText: "SAVE 20%"
                )
                .frame(width: 200)
            }

            Group {
                Text("B: Split Card").font(.headline)
                ProductCardSplit(
                    product: SampleProducts.basic,
                    previewImageAsset: PreviewAssets.product1,
                    accentColor: .blue
                )
                .frame(width: 260)
            }

            Group {
                Text("C: Sparkline").font(.headline)
                ProductCardSparkline(
                    product: SampleProducts.basic,
                    previewImageAsset: PreviewAssets.product1,
                    priceHistory: [130, 125, 120, 115, 110, 110]
                )
                .frame(width: 180)
            }

            Group {
                Text("D: Stacked Depth").font(.headline)
                ProductCardStacked(
                    product: SampleProducts.basic,
                    previewImageAsset: PreviewAssets.product1,
                    priceDropPercent: 25
                )
                .frame(width: 190)
            }

            Group {
                Text("E: Notification Style").font(.headline)
                ProductCardNotification(
                    product: SampleProducts.basic,
                    previewImageAsset: PreviewAssets.product1,
                    changeType: .priceDrop(from: 140)
                )
                .frame(width: 320)
            }

            Group {
                Text("F: Bold Price").font(.headline)
                ProductCardBoldPrice(
                    product: SampleProducts.basic,
                    previewImageAsset: PreviewAssets.product1,
                    originalPrice: 150
                )
                .frame(width: 190)
            }
        }
        .padding(24)
    }
    .frame(width: 400, height: 900)
}
