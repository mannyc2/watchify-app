//
//  MenuBarEventRow.swift
//  watchify
//

import SwiftUI

struct MenuBarEventRow: View {
    @Bindable var event: ChangeEvent

    var body: some View {
        HStack(spacing: 10) {
            // Unread indicator
            Circle()
                .fill(event.isRead ? Color.clear : Color.accentColor)
                .frame(width: 6, height: 6)

            // Change type icon
            Image(systemName: event.changeType.icon)
                .foregroundStyle(event.changeType.color)
                .font(.body)
                .frame(width: 24)

            // Content
            VStack(alignment: .leading, spacing: 1) {
                Text(event.productTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                if let priceChange = event.priceChange, let newValue = event.newValue {
                    HStack(spacing: 4) {
                        Text(newValue)
                        PriceChangeIndicator(change: priceChange)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else if let description = changeDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(event.occurredAt, format: .relative(presentation: .named))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onAppear {
            if !event.isRead {
                event.isRead = true
            }
        }
    }

    private var changeDescription: String? {
        switch event.changeType {
        case .backInStock: return "Back in stock"
        case .outOfStock: return "Out of stock"
        case .newProduct: return "New product"
        case .productRemoved: return "Removed"
        case .imagesChanged: return "Images updated"
        default: return nil
        }
    }
}

// MARK: - Previews

#Preview("Price Dropped") {
    MenuBarEventRow(event: ChangeEvent(
        changeType: .priceDropped,
        productTitle: "Wool Runners",
        variantTitle: "Size 10 / Natural White",
        oldValue: "$110",
        newValue: "$89",
        priceChange: -21
    ))
    .frame(width: 340)
    .padding()
}

#Preview("Back In Stock") {
    MenuBarEventRow(event: ChangeEvent(
        changeType: .backInStock,
        productTitle: "Tree Dashers",
        variantTitle: "Size 9 / Thunder"
    ))
    .frame(width: 340)
    .padding()
}

#Preview("Read Event") {
    let event = ChangeEvent(
        changeType: .priceDropped,
        productTitle: "Wool Loungers",
        newValue: "$79",
        priceChange: -16
    )
    event.isRead = true
    return MenuBarEventRow(event: event)
        .frame(width: 340)
        .padding()
}
