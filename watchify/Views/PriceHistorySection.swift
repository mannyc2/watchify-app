//
//  PriceHistorySection.swift
//  watchify
//

import SwiftData
import SwiftUI

struct PriceHistorySection: View {
    let variant: Variant

    private var sortedSnapshots: [VariantSnapshot] {
        variant.snapshots.sorted { $0.capturedAt > $1.capturedAt }
    }

    // MARK: - Body

    // Empty state is separate from the content VStack so it can be centered on the page
    // rather than left-aligned with the content sections.
    var body: some View {
        if variant.snapshots.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 20) {
                chartSection
                listSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Chart

    // Chart and table each get their own bordered container rather than wrapping
    // everything in one gray material background. This keeps section headers on the
    // page background while giving data areas visual distinction.
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Price Chart")
                .font(.headline)

            PriceHistoryChart(
                snapshots: variant.priceHistory,
                currentPrice: variant.price,
                currentDate: Date()
            )
            .padding()
            .background(Color.primary.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
        }
    }

    // MARK: - History List

    // Alternating row backgrounds + border matches the variants table styling
    // in ProductDetailView for visual consistency across the app.
    private var listSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Price History")
                    .font(.headline)

                Badge(text: "\(variant.snapshots.count)", color: .blue)
            }
            .padding(.bottom, 12)

            VStack(spacing: 1) {
                ForEach(Array(sortedSnapshots.enumerated()), id: \.element.capturedAt) { index, snapshot in
                    let previousPrice = index + 1 < sortedSnapshots.count ? sortedSnapshots[index + 1].price : nil
                    PriceHistoryRow(snapshot: snapshot, previousPrice: previousPrice)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(index.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.03))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
        }
    }

    // MARK: - Empty State

    // Centered with generous height so it doesn't look cramped at the bottom of the page.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Price History", systemImage: "chart.line.downtrend.xyaxis")
        } description: {
            Text("Price changes will appear here after syncing.")
        }
        .frame(maxWidth: .infinity, minHeight: 250)
    }
}

// MARK: - Previews

#Preview("With History") {
    let container = makePreviewContainer()
    let variant = Variant(
        shopifyId: 1,
        title: "Size 10 / Black",
        price: 95,
        available: true,
        position: 0
    )
    container.mainContext.insert(variant)

    let dates: [TimeInterval] = [-86400, -86400 * 3, -86400 * 5, -86400 * 7]
    let prices: [Decimal] = [98, 100, 105, 110]

    for (offset, price) in zip(dates, prices) {
        let snapshot = VariantSnapshot(
            capturedAt: Date().addingTimeInterval(offset),
            price: price,
            available: true
        )
        snapshot.variant = variant
        container.mainContext.insert(snapshot)
    }

    return ScrollView {
        PriceHistorySection(variant: variant)
            .padding()
    }
    .modelContainer(container)
}

#Preview("No History") {
    let container = makePreviewContainer()
    let variant = Variant(
        shopifyId: 2,
        title: "Size 9 / White",
        price: 110,
        available: true,
        position: 0
    )
    container.mainContext.insert(variant)

    return ScrollView {
        PriceHistorySection(variant: variant)
            .padding()
    }
    .modelContainer(container)
}

#Preview("Single Entry") {
    let container = makePreviewContainer()
    let variant = Variant(
        shopifyId: 3,
        title: "Size 8 / Gray",
        price: 95,
        available: true,
        position: 0
    )
    container.mainContext.insert(variant)

    let snapshot = VariantSnapshot(
        capturedAt: Date().addingTimeInterval(-86400),
        price: 100,
        available: true
    )
    snapshot.variant = variant
    container.mainContext.insert(snapshot)

    return ScrollView {
        PriceHistorySection(variant: variant)
            .padding()
    }
    .modelContainer(container)
}

#Preview("Many Entries") {
    let container = makePreviewContainer()
    let variant = Variant(
        shopifyId: 4,
        title: "Size 10 / Black",
        price: 85,
        available: true,
        position: 0
    )
    container.mainContext.insert(variant)

    // Generate 10 snapshots over the past month
    for idx in 1...10 {
        let snapshot = VariantSnapshot(
            capturedAt: Date().addingTimeInterval(TimeInterval(-86400 * idx * 3)),
            price: Decimal(100 + idx * 2),
            available: true
        )
        snapshot.variant = variant
        container.mainContext.insert(snapshot)
    }

    return ScrollView {
        PriceHistorySection(variant: variant)
            .padding()
    }
    .modelContainer(container)
}
