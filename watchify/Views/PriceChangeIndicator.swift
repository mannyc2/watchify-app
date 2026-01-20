//
//  PriceChangeIndicator.swift
//  watchify
//

import SwiftUI

struct PriceChangeIndicator: View {
    /// The price change amount. Positive = increase, Negative = drop.
    let change: Decimal

    private var isIncrease: Bool { change > 0 }
    private var color: Color { isIncrease ? ChangeType.priceIncreased.color : ChangeType.priceDropped.color }
    private var icon: String { isIncrease ? "arrow.up" : "arrow.down" }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text(abs(change), format: .currency(code: "USD"))
                .font(.caption2)
        }
        .foregroundStyle(color)
    }
}

// MARK: - Previews

/// Helper to show indicator in card-like context
private struct PriceRow: View {
    let currentPrice: Decimal
    let change: Decimal?

    var body: some View {
        HStack {
            Text(currentPrice, format: .currency(code: "USD"))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let change {
                PriceChangeIndicator(change: change)
            }
            Spacer()
            Badge(text: "In Stock", color: .green)
        }
        .padding(10)
        .frame(width: 180)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview("Price Dropped") {
    PriceRow(currentPrice: 95, change: -15)
        .padding()
        .frame(width: 220, height: 80)
        .background(Color(nsColor: .windowBackgroundColor))
}

#Preview("Price Increased") {
    PriceRow(currentPrice: 135, change: 10)
        .padding()
        .frame(width: 220, height: 80)
        .background(Color(nsColor: .windowBackgroundColor))
}

#Preview("No Change") {
    PriceRow(currentPrice: 110, change: nil)
        .padding()
        .frame(width: 220, height: 80)
        .background(Color(nsColor: .windowBackgroundColor))
}

#Preview("Various Changes") {
    VStack(spacing: 12) {
        PriceRow(currentPrice: 60, change: -50)
        PriceRow(currentPrice: 95, change: -15)
        PriceRow(currentPrice: 105, change: -5)
        PriceRow(currentPrice: 115, change: 5)
        PriceRow(currentPrice: 130, change: 20)
    }
    .padding()
    .background(Color(nsColor: .windowBackgroundColor))
}
