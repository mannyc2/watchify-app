//
//  ActivityRow.swift
//  watchify
//

import SwiftUI

/// Activity row with notification-style design.
/// Shows product thumbnail, change type with icon, and glass hover effect.
/// Adapts layout based on horizontal size class:
/// - Compact: Stacked notification-style card
/// - Regular: Data-dense table-like row
struct ActivityRowDTO: View {
    let event: ChangeEventDTO
    let onAppear: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var isHovering = false
    private let cornerRadius: CGFloat = 12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if let shopifyId = event.productShopifyId {
                NavigationLink(value: shopifyId) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .contentShape(shape)
        .background {
            Color.clear.glassEffect(.regular.interactive())
                .opacity(isHovering ? 1 : 0)
                .clipShape(shape)
        }
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.15), value: isHovering)
        .onAppear {
            if !event.isRead { onAppear() }
        }
    }

    @ViewBuilder
    private var rowContent: some View {
        if sizeClass == .compact {
            compactRowContent
        } else {
            regularRowContent
        }
    }

    // MARK: - Compact Layout (narrow widths)

    private var compactRowContent: some View {
        HStack(spacing: 12) {
            // Product thumbnail
            productImage
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                // Change type with icon
                HStack(spacing: 4) {
                    Image(systemName: event.changeType.icon)
                        .font(.caption2.weight(.semibold))
                    Text(changeTypeLabel)
                        .font(.caption.weight(.semibold))

                    if !event.isRead {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                    }
                }
                .foregroundStyle(event.changeType.color)

                // Product title
                Text(event.productTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                // Value row
                if let newValue = event.newValue {
                    HStack(spacing: 6) {
                        Text(newValue)
                            .font(.callout.weight(.bold))

                        if let oldValue = event.oldValue {
                            Text(oldValue)
                                .font(.caption)
                                .strikethrough()
                                .foregroundStyle(.secondary)
                        }

                        if let change = event.priceChange {
                            PriceChangeIndicator(change: change)
                        }
                    }
                } else if let variant = event.variantTitle {
                    Text(variant)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Time + chevron
            VStack(alignment: .trailing, spacing: 4) {
                Text(event.occurredAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if event.productShopifyId != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.quaternary)
                }
            }
        }
        .padding(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Regular Layout (wide widths)

    private var regularRowContent: some View {
        HStack(spacing: 10) {
            // Smaller thumbnail
            productImage
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            // Change type badge
            HStack(spacing: 4) {
                Image(systemName: event.changeType.icon)
                Text(changeTypeLabel)
                if !event.isRead {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(event.changeType.color)
            .frame(width: 100, alignment: .leading)

            // Product title
            Text(event.productTitle)
                .font(.subheadline)
                .lineLimit(1)
                .frame(minWidth: 120, alignment: .leading)

            // Variant (if present)
            if let variant = event.variantTitle {
                Text(variant)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 100, alignment: .leading)
            }

            Spacer()

            // Price info
            if let newValue = event.newValue {
                HStack(spacing: 4) {
                    Text(newValue)
                        .font(.subheadline.weight(.semibold))
                    if let oldValue = event.oldValue {
                        Text(oldValue)
                            .font(.caption)
                            .strikethrough()
                            .foregroundStyle(.secondary)
                    }
                    if let change = event.priceChange {
                        PriceChangeIndicator(change: change)
                    }
                }
                .frame(width: 120, alignment: .trailing)
            }

            // Store name
            if let storeName = event.storeName {
                Text(storeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }

            // Time
            Text(event.occurredAt, format: .relative(presentation: .named))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 60, alignment: .trailing)

            // Chevron
            if event.productShopifyId != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Shared Components

    @ViewBuilder
    private var productImage: some View {
        if let urlString = event.productImageURL, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                imagePlaceholder
            }
        } else {
            imagePlaceholder
        }
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(.fill.tertiary)
            .overlay {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
                    .accessibilityHidden(true)
            }
    }

    private var changeTypeLabel: String {
        switch event.changeType {
        case .priceDropped: "Price Drop"
        case .priceIncreased: "Price Increased"
        case .backInStock: "Back in Stock"
        case .outOfStock: "Out of Stock"
        case .newProduct: "New Product"
        case .productRemoved: "Removed"
        case .imagesChanged: "Images Updated"
        }
    }

    private var accessibilityLabel: String {
        var parts = [changeTypeLabel, event.productTitle]
        if let variant = event.variantTitle { parts.append(variant) }
        if let change = event.priceChange {
            let amount = abs(change).formatted(.currency(code: "USD"))
            parts.append(change > 0 ? "up \(amount)" : "down \(amount)")
        }
        parts.append(event.occurredAt.formatted(.relative(presentation: .named)))
        if !event.isRead { parts.insert("Unread", at: 0) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Previews

private enum SampleEvents {
    static let priceDrop = ChangeEventDTO(
        changeType: .priceDropped,
        productTitle: "Wool Runners",
        variantTitle: "Size 10 / Natural White",
        oldValue: "$110",
        newValue: "$89",
        priceChange: -21,
        magnitude: .medium,
        productShopifyId: 123456789,
        storeId: UUID(),
        storeName: "Allbirds"
    )

    static let backInStock = ChangeEventDTO(
        changeType: .backInStock,
        productTitle: "Tree Dashers",
        variantTitle: "Size 9 / Thunder",
        magnitude: .medium,
        productShopifyId: 234567890,
        storeId: UUID(),
        storeName: "Allbirds"
    )

    static let newProduct = ChangeEventDTO(
        changeType: .newProduct,
        productTitle: "SuperLight Wool Runners",
        newValue: "$98",
        magnitude: .medium,
        productShopifyId: 345678901,
        storeId: UUID(),
        storeName: "Allbirds"
    )

    static let outOfStock = ChangeEventDTO(
        changeType: .outOfStock,
        productTitle: "Wool Loungers",
        variantTitle: "Size 8 / Natural Grey",
        magnitude: .medium,
        productShopifyId: 456789012,
        storeId: UUID(),
        storeName: "Allbirds"
    )

    static let removed = ChangeEventDTO(
        changeType: .productRemoved,
        productTitle: "Limited Edition Runners",
        magnitude: .medium,
        productShopifyId: nil,
        storeId: UUID(),
        storeName: "Allbirds"
    )

    static let readEvent = ChangeEventDTO(
        changeType: .priceDropped,
        productTitle: "Tree Runners",
        variantTitle: "Size 11 / Natural Black",
        oldValue: "$98",
        newValue: "$79",
        priceChange: -19,
        magnitude: .medium,
        productShopifyId: 567890123,
        isRead: true,
        storeId: UUID(),
        storeName: "Allbirds"
    )
}

// MARK: - Compact Layout Previews

#Preview("Compact Layout") {
    VStack(spacing: 0) {
        ActivityRowDTO(event: SampleEvents.priceDrop, onAppear: {})
        ActivityRowDTO(event: SampleEvents.backInStock, onAppear: {})
        ActivityRowDTO(event: SampleEvents.newProduct, onAppear: {})
        ActivityRowDTO(event: SampleEvents.outOfStock, onAppear: {})
        ActivityRowDTO(event: SampleEvents.removed, onAppear: {})
        ActivityRowDTO(event: SampleEvents.readEvent, onAppear: {})
    }
    .environment(\.horizontalSizeClass, .compact)
    .frame(width: 380)
    .padding()
}

// MARK: - Regular Layout Previews

#Preview("Regular Layout") {
    VStack(spacing: 0) {
        ActivityRowDTO(event: SampleEvents.priceDrop, onAppear: {})
        ActivityRowDTO(event: SampleEvents.backInStock, onAppear: {})
        ActivityRowDTO(event: SampleEvents.newProduct, onAppear: {})
        ActivityRowDTO(event: SampleEvents.outOfStock, onAppear: {})
        ActivityRowDTO(event: SampleEvents.removed, onAppear: {})
        ActivityRowDTO(event: SampleEvents.readEvent, onAppear: {})
    }
    .environment(\.horizontalSizeClass, .regular)
    .frame(width: 700)
    .padding()
}
