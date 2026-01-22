//
//  PriceHistoryRow.swift
//  watchify
//

import SwiftData
import SwiftUI

struct PriceHistoryRow: View {
    let snapshot: VariantSnapshot
    let previousPrice: Decimal?

    private var priceChange: Decimal? {
        guard let previous = previousPrice else { return nil }
        let change = snapshot.price - previous
        return change != 0 ? change : nil
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.capturedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline)

                Text(snapshot.capturedAt, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if let change = priceChange {
                    PriceChangeIndicator(change: change)
                }

                Text(snapshot.price, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var label = snapshot.capturedAt.formatted(date: .abbreviated, time: .shortened)
        label += ", \(snapshot.price.formatted(.currency(code: "USD")))"

        if let change = priceChange {
            let changeAmount = abs(change).formatted(.currency(code: "USD"))
            label += change > 0 ? ", increased by \(changeAmount)" : ", dropped by \(changeAmount)"
        }

        return label
    }
}

// MARK: - Previews

#Preview("Price Dropped") {
    let container = makePreviewContainer()
    let snapshot = VariantSnapshot(
        capturedAt: Date().addingTimeInterval(-86400),
        price: 95,
        available: true
    )
    container.mainContext.insert(snapshot)

    return List {
        PriceHistoryRow(snapshot: snapshot, previousPrice: 110)
    }
    .modelContainer(container)
}

#Preview("Price Increased") {
    let container = makePreviewContainer()
    let snapshot = VariantSnapshot(
        capturedAt: Date().addingTimeInterval(-86400 * 3),
        price: 125,
        available: true
    )
    container.mainContext.insert(snapshot)

    return List {
        PriceHistoryRow(snapshot: snapshot, previousPrice: 110)
    }
    .modelContainer(container)
}

#Preview("No Previous Price") {
    let container = makePreviewContainer()
    let snapshot = VariantSnapshot(
        capturedAt: Date().addingTimeInterval(-86400 * 7),
        price: 100,
        available: true
    )
    container.mainContext.insert(snapshot)

    return List {
        PriceHistoryRow(snapshot: snapshot, previousPrice: nil)
    }
    .modelContainer(container)
}

#Preview("Multiple Rows") {
    let container = makePreviewContainer()

    let dates: [TimeInterval] = [-86400, -86400 * 3, -86400 * 5, -86400 * 7]
    let prices: [Decimal] = [95, 100, 105, 110]

    var snapshots: [VariantSnapshot] = []
    for (offset, price) in zip(dates, prices) {
        let snapshot = VariantSnapshot(
            capturedAt: Date().addingTimeInterval(offset),
            price: price,
            available: true
        )
        container.mainContext.insert(snapshot)
        snapshots.append(snapshot)
    }

    return List {
        ForEach(Array(snapshots.enumerated()), id: \.element.capturedAt) { index, snapshot in
            let previousPrice = index + 1 < snapshots.count ? snapshots[index + 1].price : nil
            PriceHistoryRow(snapshot: snapshot, previousPrice: previousPrice)
        }
    }
    .modelContainer(container)
}
