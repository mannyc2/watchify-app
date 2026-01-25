//
//  ActivityGroupRow.swift
//  watchify
//

import SwiftUI

// MARK: - Collapsible Group Row

/// A group row that expands/collapses to show child events.
struct CollapsibleGroupRow: View {
    let group: EventGroup
    let isExpanded: Bool
    let onToggle: () -> Void
    let onMarkRead: (UUID) -> Void

    @State private var isHovering = false
    private let cornerRadius: CGFloat = 12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        VStack(spacing: 0) {
            // Header row
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.snappy(duration: 0.2), value: isExpanded)
                        .accessibilityHidden(true)

                    // Product thumbnail
                    groupImage
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        // Product title with unread indicator
                        HStack(spacing: 6) {
                            Text(group.productTitle)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)

                            if group.hasUnread {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 6, height: 6)
                            }
                        }

                        // Summary text
                        HStack(spacing: 4) {
                            Image(systemName: group.dominantChangeType.icon)
                                .font(.caption2.weight(.semibold))
                                .accessibilityHidden(true)
                            Text(group.summaryText)
                                .font(.caption)
                        }
                        .foregroundStyle(group.dominantChangeType.color)
                    }

                    Spacer()

                    // Time
                    Text(group.latestDate, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
            }
            .buttonStyle(.plain)
            .contentShape(shape)
            .background {
                Color.clear.glassEffect(.regular.interactive())
                    .opacity(isHovering ? 1 : 0)
                    .clipShape(shape)
            }
            .onHover { isHovering = $0 }
            .animation(.snappy(duration: 0.15), value: isHovering)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(isExpanded ? "Double-tap to collapse" : "Double-tap to expand")
            .accessibilityAddTraits(.isButton)

            // Expanded children
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(group.events.enumerated()), id: \.element.id) { index, event in
                        VStack(spacing: 0) {
                            ChildEventRow(event: event) {
                                onMarkRead(event.id)
                            }

                            if index < group.events.count - 1 {
                                Divider()
                                    .padding(.leading, 64)
                            }
                        }
                    }
                }
                .padding(.leading, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy(duration: 0.25), value: isExpanded)
    }

    @ViewBuilder
    private var groupImage: some View {
        if let urlString = group.productImageURL, let url = URL(string: urlString) {
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

    private var accessibilityLabel: String {
        var parts = [group.productTitle, group.summaryText]
        parts.append(group.latestDate.formatted(.relative(presentation: .named)))
        if group.hasUnread { parts.insert("Unread", at: 0) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Summary Group Row

/// A compact summary row that navigates to product detail on tap.
struct SummaryGroupRow: View {
    let group: EventGroup
    let onAppear: () -> Void

    @State private var isHovering = false
    private let cornerRadius: CGFloat = 12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if let shopifyId = group.productShopifyId {
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
            if group.hasUnread { onAppear() }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            // Stacked image effect
            stackedImage
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                // Product title with unread indicator
                HStack(spacing: 6) {
                    Text(group.productTitle)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    if group.hasUnread {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                    }
                }

                // Summary text
                HStack(spacing: 4) {
                    Image(systemName: group.dominantChangeType.icon)
                        .font(.caption2.weight(.semibold))
                        .accessibilityHidden(true)
                    Text(group.summaryText)
                        .font(.caption)
                }
                .foregroundStyle(group.dominantChangeType.color)
            }

            Spacer()

            // Time + chevron
            VStack(alignment: .trailing, spacing: 4) {
                Text(group.latestDate, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if group.productShopifyId != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.quaternary)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var stackedImage: some View {
        ZStack {
            // Background layers for stacked effect
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.fill.tertiary)
                .frame(width: 40, height: 40)
                .offset(x: 4, y: 4)
                .opacity(0.5)

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.fill.tertiary)
                .frame(width: 42, height: 42)
                .offset(x: 2, y: 2)
                .opacity(0.7)

            // Main image
            if let urlString = group.productImageURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    imagePlaceholder
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                imagePlaceholder
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
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

    private var accessibilityLabel: String {
        var parts = [group.productTitle, group.summaryText]
        parts.append(group.latestDate.formatted(.relative(presentation: .named)))
        if group.hasUnread { parts.insert("Unread", at: 0) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Inline Expandable Group Row

/// A group row with an inline Show/Hide pill button.
struct InlineExpandableGroupRow: View {
    let group: EventGroup
    let isExpanded: Bool
    let onToggle: () -> Void
    let onMarkRead: (UUID) -> Void

    @State private var isHovering = false
    private let cornerRadius: CGFloat = 12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                // Product thumbnail
                groupImage
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    // Product title with unread indicator
                    HStack(spacing: 6) {
                        Text(group.productTitle)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)

                        if group.hasUnread {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 6, height: 6)
                        }
                    }

                    // Summary text
                    HStack(spacing: 4) {
                        Image(systemName: group.dominantChangeType.icon)
                            .font(.caption2.weight(.semibold))
                            .accessibilityHidden(true)
                        Text(group.summaryText)
                            .font(.caption)
                    }
                    .foregroundStyle(group.dominantChangeType.color)
                }

                Spacer()

                // Show/Hide pill button
                Button(action: onToggle) {
                    HStack(spacing: 2) {
                        Text(isExpanded ? "Hide" : "Show")
                            .font(.caption.weight(.medium))
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.fill.tertiary, in: Capsule())
                }
                .buttonStyle(.plain)
                .animation(.snappy(duration: 0.2), value: isExpanded)

                // Time
                Text(group.latestDate, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .contentShape(shape)
            .background {
                Color.clear.glassEffect(.regular.interactive())
                    .opacity(isHovering ? 1 : 0)
                    .clipShape(shape)
            }
            .onHover { isHovering = $0 }
            .animation(.snappy(duration: 0.15), value: isHovering)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)

            // Inline expanded content (compact variant list)
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(group.events, id: \.id) { event in
                        HStack(spacing: 8) {
                            Text("\u{2022}")
                                .foregroundStyle(.secondary)

                            if let variant = event.variantTitle {
                                Text(variant)
                                    .font(.caption)
                                    .lineLimit(1)
                            } else {
                                Text("Default")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let newValue = event.newValue {
                                Text(newValue)
                                    .font(.caption.weight(.semibold))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .onAppear {
                            if !event.isRead { onMarkRead(event.id) }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy(duration: 0.25), value: isExpanded)
    }

    @ViewBuilder
    private var groupImage: some View {
        if let urlString = group.productImageURL, let url = URL(string: urlString) {
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

    private var accessibilityLabel: String {
        var parts = [group.productTitle, group.summaryText]
        parts.append(group.latestDate.formatted(.relative(presentation: .named)))
        if group.hasUnread { parts.insert("Unread", at: 0) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Child Event Row (for collapsible mode)

/// A compact row for showing a single event within a collapsed group.
private struct ChildEventRow: View {
    let event: ChangeEventDTO
    let onAppear: () -> Void

    @State private var isHovering = false
    private let cornerRadius: CGFloat = 8

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

    private var rowContent: some View {
        HStack(spacing: 10) {
            // Change type indicator
            HStack(spacing: 4) {
                Image(systemName: event.changeType.icon)
                    .accessibilityHidden(true)
                Text(changeTypeLabel)
                if !event.isRead {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 5, height: 5)
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(event.changeType.color)
            .frame(width: 90, alignment: .leading)

            // Variant title
            if let variant = event.variantTitle {
                Text(variant)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Value
            if let newValue = event.newValue {
                HStack(spacing: 4) {
                    Text(newValue)
                        .font(.caption.weight(.semibold))
                    if let oldValue = event.oldValue {
                        Text(oldValue)
                            .font(.caption2)
                            .strikethrough()
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Time
            Text(event.occurredAt, format: .relative(presentation: .named))
                .font(.caption2)
                .foregroundStyle(.tertiary)

            // Chevron
            if event.productShopifyId != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.quaternary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var changeTypeLabel: String {
        switch event.changeType {
        case .priceDropped: "Price Drop"
        case .priceIncreased: "Price Up"
        case .backInStock: "In Stock"
        case .outOfStock: "Out"
        case .newProduct: "New"
        case .productRemoved: "Removed"
        case .imagesChanged: "Images"
        }
    }

    private var accessibilityLabel: String {
        var parts = [changeTypeLabel]
        if let variant = event.variantTitle { parts.append(variant) }
        if let newValue = event.newValue { parts.append(newValue) }
        parts.append(event.occurredAt.formatted(.relative(presentation: .named)))
        if !event.isRead { parts.insert("Unread", at: 0) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Previews

private enum SampleGroups {
    static let priceDropGroup = EventGroup(
        id: UUID(),
        productTitle: "Wool Runners",
        productShopifyId: 123456789,
        productImageURL: nil,
        storeName: "Allbirds",
        dominantChangeType: .priceDropped,
        events: [
            ChangeEventDTO(
                changeType: .priceDropped,
                productTitle: "Wool Runners",
                variantTitle: "Size 8 / Natural White",
                oldValue: "$110",
                newValue: "$89",
                priceChange: -21,
                productShopifyId: 123456789,
                storeId: UUID(),
                storeName: "Allbirds"
            ),
            ChangeEventDTO(
                changeType: .priceDropped,
                productTitle: "Wool Runners",
                variantTitle: "Size 9 / Natural Grey",
                oldValue: "$110",
                newValue: "$89",
                priceChange: -21,
                productShopifyId: 123456789,
                storeId: UUID(),
                storeName: "Allbirds"
            ),
            ChangeEventDTO(
                changeType: .priceDropped,
                productTitle: "Wool Runners",
                variantTitle: "Size 10 / Thunder",
                oldValue: "$110",
                newValue: "$89",
                priceChange: -21,
                productShopifyId: 123456789,
                storeId: UUID(),
                storeName: "Allbirds"
            )
        ],
        latestDate: Date()
    )

    static let backInStockGroup = EventGroup(
        id: UUID(),
        productTitle: "Tree Dashers",
        productShopifyId: 234567890,
        productImageURL: nil,
        storeName: "Allbirds",
        dominantChangeType: .backInStock,
        events: [
            ChangeEventDTO(
                changeType: .backInStock,
                productTitle: "Tree Dashers",
                variantTitle: "Size 9 / Thunder",
                productShopifyId: 234567890,
                storeId: UUID(),
                storeName: "Allbirds"
            ),
            ChangeEventDTO(
                changeType: .backInStock,
                productTitle: "Tree Dashers",
                variantTitle: "Size 10 / Natural Black",
                productShopifyId: 234567890,
                storeId: UUID(),
                storeName: "Allbirds"
            )
        ],
        latestDate: Date().addingTimeInterval(-3600)
    )
}

#Preview("Collapsible - Collapsed") {
    VStack(spacing: 0) {
        CollapsibleGroupRow(
            group: SampleGroups.priceDropGroup,
            isExpanded: false,
            onToggle: {},
            onMarkRead: { _ in }
        )
        Divider()
        CollapsibleGroupRow(
            group: SampleGroups.backInStockGroup,
            isExpanded: false,
            onToggle: {},
            onMarkRead: { _ in }
        )
    }
    .padding()
    .frame(width: 400)
}

#Preview("Collapsible - Expanded") {
    CollapsibleGroupRow(
        group: SampleGroups.priceDropGroup,
        isExpanded: true,
        onToggle: {},
        onMarkRead: { _ in }
    )
    .padding()
    .frame(width: 400)
}

#Preview("Summary") {
    VStack(spacing: 0) {
        SummaryGroupRow(
            group: SampleGroups.priceDropGroup,
            onAppear: {}
        )
        Divider()
        SummaryGroupRow(
            group: SampleGroups.backInStockGroup,
            onAppear: {}
        )
    }
    .padding()
    .frame(width: 400)
}

#Preview("Inline - Collapsed") {
    VStack(spacing: 0) {
        InlineExpandableGroupRow(
            group: SampleGroups.priceDropGroup,
            isExpanded: false,
            onToggle: {},
            onMarkRead: { _ in }
        )
        Divider()
        InlineExpandableGroupRow(
            group: SampleGroups.backInStockGroup,
            isExpanded: false,
            onToggle: {},
            onMarkRead: { _ in }
        )
    }
    .padding()
    .frame(width: 400)
}

#Preview("Inline - Expanded") {
    InlineExpandableGroupRow(
        group: SampleGroups.priceDropGroup,
        isExpanded: true,
        onToggle: {},
        onMarkRead: { _ in }
    )
    .padding()
    .frame(width: 400)
}
