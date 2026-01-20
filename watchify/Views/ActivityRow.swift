//
//  ActivityRow.swift
//  watchify
//

import SwiftUI

struct ActivityRow: View {
    let event: ChangeEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.changeType.icon)
                .foregroundStyle(event.changeType.color)
                .font(.title2)
                .frame(width: 32)
                .accessibilityLabel(accessibilityLabel)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.productTitle)
                    .font(.headline)
                    .lineLimit(1)

                if let variantTitle = event.variantTitle {
                    Text(variantTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let priceChange = event.priceChange, let newValue = event.newValue {
                    HStack(spacing: 4) {
                        Text(newValue)
                            .foregroundStyle(.secondary)
                        PriceChangeIndicator(change: priceChange)
                    }
                    .font(.caption)
                } else if let description = changeDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(event.occurredAt, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var accessibilityLabel: String {
        switch event.changeType {
        case .priceDropped:
            "Price dropped"
        case .priceIncreased:
            "Price increased"
        case .backInStock:
            "Back in stock"
        case .outOfStock:
            "Out of stock"
        case .newProduct:
            "New product"
        case .productRemoved:
            "Product removed"
        case .imagesChanged:
            "Images changed"
        }
    }

    private var changeDescription: String? {
        guard let oldValue = event.oldValue, let newValue = event.newValue else {
            return nil
        }
        return "\(oldValue) → \(newValue)"
    }
}

// MARK: - Previews

#Preview("Price Dropped") {
    ActivityRow(event: ChangeEvent(
        changeType: .priceDropped,
        productTitle: "Wool Runners",
        variantTitle: "Size 10 / Natural White",
        oldValue: "$110",
        newValue: "$89",
        priceChange: -21
    ))
    .padding()
}

#Preview("Price Increased") {
    ActivityRow(event: ChangeEvent(
        changeType: .priceIncreased,
        productTitle: "Tree Dashers",
        variantTitle: "Size 9",
        oldValue: "$125",
        newValue: "$135",
        priceChange: 10
    ))
    .padding()
}

#Preview("Back In Stock") {
    ActivityRow(event: ChangeEvent(
        changeType: .backInStock,
        productTitle: "Wool Loungers",
        variantTitle: "Size 11 / Natural Black"
    ))
    .padding()
}

#Preview("Out of Stock") {
    ActivityRow(event: ChangeEvent(
        changeType: .outOfStock,
        productTitle: "Tree Breezers",
        variantTitle: "Size 8"
    ))
    .padding()
}

#Preview("New Product") {
    ActivityRow(event: ChangeEvent(
        changeType: .newProduct,
        productTitle: "Trail Runner SWT"
    ))
    .padding()
}

#Preview("Product Removed") {
    ActivityRow(event: ChangeEvent(
        changeType: .productRemoved,
        productTitle: "Discontinued Shoe"
    ))
    .padding()
}
