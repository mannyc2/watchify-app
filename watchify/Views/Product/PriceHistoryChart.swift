//
//  PriceHistoryChart.swift
//  watchify
//

import Charts
import SwiftData
import SwiftUI

struct PriceHistoryChart: View {
    let snapshots: [VariantSnapshot]
    let currentPrice: Decimal
    let currentDate: Date

    @State private var selectedDate: Date?

    private var chartData: [(date: Date, price: Decimal)] {
        var data = snapshots.map { (date: $0.capturedAt, price: $0.price) }
        data.append((date: currentDate, price: currentPrice))
        return data.sorted { $0.date < $1.date }
    }

    private var priceRange: ClosedRange<Double> {
        let prices = chartData.map { NSDecimalNumber(decimal: $0.price).doubleValue }
        guard let min = prices.min(), let max = prices.max() else {
            return 0...100
        }
        let padding = (max - min) * 0.1
        return (min - padding)...(max + padding)
    }

    private var selectedDataPoint: (date: Date, price: Decimal)? {
        guard let selectedDate else { return nil }
        return chartData.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    var body: some View {
        if chartData.count < 2 {
            emptyState
        } else {
            chart
        }
    }

    // Uses accentColor for theme consistency. Grid lines are tertiary to stay subtle.
    // Simple line + points without area fill keeps the chart clean.
    private var chart: some View {
        Chart(chartData, id: \.date) { dataPoint in
            LineMark(
                x: .value("Date", dataPoint.date),
                y: .value("Price", NSDecimalNumber(decimal: dataPoint.price).doubleValue)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.accentColor)
            .lineStyle(StrokeStyle(lineWidth: 2))

            PointMark(
                x: .value("Date", dataPoint.date),
                y: .value("Price", NSDecimalNumber(decimal: dataPoint.price).doubleValue)
            )
            .foregroundStyle(Color.accentColor)
            .symbolSize(30)

            if let selected = selectedDataPoint, selected.date == dataPoint.date {
                RuleMark(x: .value("Date", selected.date))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .center) {
                        tooltipView(date: selected.date, price: selected.price)
                    }
            }
        }
        .chartYScale(domain: priceRange)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                    .foregroundStyle(.tertiary)
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(Decimal(price), format: .currency(code: "USD"))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                    .foregroundStyle(.tertiary)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .frame(height: 220)
    }

    private func tooltipView(date: Date, price: Decimal) -> some View {
        VStack(spacing: 2) {
            Text(price, format: .currency(code: "USD"))
                .font(.caption.weight(.semibold))
            Text(date, format: .dateTime.month(.abbreviated).day())
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // Centered with generous height to match chart dimensions.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Price History", systemImage: "chart.line.downtrend.xyaxis")
        } description: {
            Text("Price changes will appear here after syncing.")
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

// MARK: - Previews

#Preview("With History") {
    let container = makePreviewContainer()
    let variant = Variant(
        shopifyId: 1,
        title: "Size 10",
        price: 95,
        available: true,
        position: 0
    )
    container.mainContext.insert(variant)

    // Add historical snapshots
    let dates: [TimeInterval] = [-86400 * 7, -86400 * 5, -86400 * 3, -86400]
    let prices: [Decimal] = [110, 105, 100, 98]

    for (offset, price) in zip(dates, prices) {
        let snapshot = VariantSnapshot(
            capturedAt: Date().addingTimeInterval(offset),
            price: price,
            available: true
        )
        snapshot.variant = variant
        container.mainContext.insert(snapshot)
    }

    return PriceHistoryChart(
        snapshots: variant.priceHistory,
        currentPrice: variant.price,
        currentDate: Date()
    )
    .padding()
    .modelContainer(container)
}

#Preview("Price Increased") {
    let container = makePreviewContainer()
    let variant = Variant(
        shopifyId: 2,
        title: "Size 9",
        price: 125,
        available: true,
        position: 0
    )
    container.mainContext.insert(variant)

    let dates: [TimeInterval] = [-86400 * 5, -86400 * 3, -86400]
    let prices: [Decimal] = [100, 110, 120]

    for (offset, price) in zip(dates, prices) {
        let snapshot = VariantSnapshot(
            capturedAt: Date().addingTimeInterval(offset),
            price: price,
            available: true
        )
        snapshot.variant = variant
        container.mainContext.insert(snapshot)
    }

    return PriceHistoryChart(
        snapshots: variant.priceHistory,
        currentPrice: variant.price,
        currentDate: Date()
    )
    .padding()
    .modelContainer(container)
}

#Preview("No History") {
    PriceHistoryChart(
        snapshots: [],
        currentPrice: 110,
        currentDate: Date()
    )
    .padding()
}

#Preview("Single Snapshot") {
    let container = makePreviewContainer()
    let variant = Variant(
        shopifyId: 3,
        title: "Size 8",
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

    return PriceHistoryChart(
        snapshots: variant.priceHistory,
        currentPrice: variant.price,
        currentDate: Date()
    )
    .padding()
    .modelContainer(container)
}
