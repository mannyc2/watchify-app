//
//  ActivityRow.swift
//  watchify
//

import SwiftUI

struct ActivityRow: View {
    let event: ChangeEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
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

                if let description = changeDescription {
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

    private var iconName: String {
        switch event.changeType {
        case .priceDropped:
            "arrow.down.circle.fill"
        case .priceIncreased:
            "arrow.up.circle.fill"
        case .backInStock:
            "checkmark.circle.fill"
        case .outOfStock:
            "xmark.circle.fill"
        case .newProduct:
            "sparkles"
        case .productRemoved:
            "trash"
        }
    }

    private var iconColor: Color {
        switch event.changeType {
        case .priceDropped, .backInStock:
            .green
        case .priceIncreased, .outOfStock:
            .red
        case .newProduct:
            .blue
        case .productRemoved:
            .secondary
        }
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
        }
    }

    private var changeDescription: String? {
        guard let oldValue = event.oldValue, let newValue = event.newValue else {
            return nil
        }
        return "\(oldValue) → \(newValue)"
    }
}
