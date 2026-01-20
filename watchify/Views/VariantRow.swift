//
//  VariantRow.swift
//  watchify
//

import SwiftData
import SwiftUI

struct VariantRow: View {
    let variant: Variant

    private var savings: Decimal? {
        guard let compareAt = variant.compareAtPrice, compareAt > variant.price else { return nil }
        return compareAt - variant.price
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(variant.title)
                    .font(.body.weight(.medium))

                if let sku = variant.sku {
                    Text("SKU: \(sku)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    if let compareAt = variant.compareAtPrice, compareAt > variant.price {
                        Text(compareAt, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .strikethrough()
                    }

                    Text(variant.price, format: .currency(code: "USD"))
                        .font(.subheadline.weight(.semibold))
                }

                HStack(spacing: 6) {
                    if let savings {
                        Badge(text: "Save \(savings.formatted(.currency(code: "USD")))", color: .green)
                    }

                    Badge(
                        text: variant.available ? "In Stock" : "Out",
                        color: variant.available ? .green : .red
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var label = variant.title
        label += ", \(variant.price.formatted(.currency(code: "USD")))"

        if let compareAt = variant.compareAtPrice, compareAt > variant.price {
            label += ", was \(compareAt.formatted(.currency(code: "USD")))"
            if let savings {
                label += ", save \(savings.formatted(.currency(code: "USD")))"
            }
        }

        label += ", \(variant.available ? "in stock" : "out of stock")"

        if let sku = variant.sku {
            label += ", SKU \(sku)"
        }

        return label
    }
}

// MARK: - Previews

#Preview("Basic Variant") {
    let container = makePreviewContainer()
    let variant = Variant(
        shopifyId: 1,
        title: "Size 10 / Black",
        price: Decimal(110),
        available: true,
        position: 0
    )
    container.mainContext.insert(variant)

    return List {
        VariantRow(variant: variant)
    }
    .modelContainer(container)
}

#Preview("With Compare Price") {
    let container = makePreviewContainer()
    let variant = Variant(
        shopifyId: 2,
        title: "Size 9 / White",
        sku: "WR-9-WHT",
        price: Decimal(85),
        compareAtPrice: Decimal(110),
        available: true,
        position: 0
    )
    container.mainContext.insert(variant)

    return List {
        VariantRow(variant: variant)
    }
    .modelContainer(container)
}

#Preview("Out of Stock") {
    let container = makePreviewContainer()
    let variant = Variant(
        shopifyId: 3,
        title: "Size 11 / Gray",
        sku: "WR-11-GRY",
        price: Decimal(110),
        available: false,
        position: 0
    )
    container.mainContext.insert(variant)

    return List {
        VariantRow(variant: variant)
    }
    .modelContainer(container)
}

#Preview("Multiple Variants") {
    let container = makePreviewContainer()

    let variants = [
        Variant(shopifyId: 1, title: "Size 8 / Black", price: 110, available: true, position: 0),
        Variant(shopifyId: 2, title: "Size 9 / Black", sku: "WR-9-BLK", price: 85, compareAtPrice: 110,
                available: true, position: 1),
        Variant(shopifyId: 3, title: "Size 10 / Black", price: 110, available: false, position: 2),
        Variant(shopifyId: 4, title: "Size 11 / Black", sku: "WR-11-BLK", price: 110, available: true, position: 3)
    ]

    variants.forEach { container.mainContext.insert($0) }

    return List {
        ForEach(variants) { variant in
            VariantRow(variant: variant)
        }
    }
    .modelContainer(container)
}
