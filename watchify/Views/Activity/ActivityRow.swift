//
//  ActivityRowDTO.swift
//  watchify
//

import SwiftUI

/// Activity row that displays a ChangeEventDTO (Sendable).
/// Used with ActivityViewModel for background-fetched data.
struct ActivityRowDTO: View {
    let event: ChangeEventDTO
    let onAppear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Unread indicator
            Circle()
                .fill(event.isRead ? Color.clear : Color.accentColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Image(systemName: event.changeType.icon)
                .foregroundStyle(event.changeType.color)
                .font(.title2)
                .frame(width: 32)
                .accessibilityHidden(true)

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
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(event.occurredAt, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .onAppear {
            if !event.isRead {
                onAppear()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityValue(event.isRead ? "Read" : "Unread")
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

    private var rowAccessibilityLabel: String {
        var parts: [String] = []

        if !event.isRead {
            parts.append("Unread")
        }

        parts.append(accessibilityLabel)
        parts.append("on \(event.productTitle)")

        if let variant = event.variantTitle {
            parts.append(variant)
        }

        if let change = event.priceChange {
            let amount = abs(change).formatted(.currency(code: "USD"))
            parts.append(change > 0 ? "up \(amount)" : "down \(amount)")
        }

        parts.append(event.occurredAt.formatted(.relative(presentation: .named)))

        return parts.joined(separator: ", ")
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
    ActivityRowDTO(
        event: ChangeEventDTO(
            id: UUID(),
            occurredAt: Date(),
            changeType: .priceDropped,
            productTitle: "Wool Runners",
            variantTitle: "Size 10 / Natural White",
            oldValue: "$110",
            newValue: "$89",
            priceChange: -21,
            isRead: false,
            magnitude: .medium,
            storeId: nil,
            storeName: nil
        ),
        onAppear: {}
    )
    .padding()
}

#Preview("Read Event") {
    ActivityRowDTO(
        event: ChangeEventDTO(
            id: UUID(),
            occurredAt: Date(),
            changeType: .backInStock,
            productTitle: "Tree Dashers",
            variantTitle: "Size 9",
            oldValue: nil,
            newValue: nil,
            priceChange: nil,
            isRead: true,
            magnitude: .medium,
            storeId: nil,
            storeName: nil
        ),
        onAppear: {}
    )
    .padding()
}
