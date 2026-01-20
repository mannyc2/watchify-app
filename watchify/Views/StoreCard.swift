import SwiftData
import SwiftUI

struct StoreCard: View {
    let store: Store

    private var productCount: Int {
        store.products.filter { !$0.isRemoved }.count
    }

    private var previewImages: [URL] {
        store.products
            .filter { !$0.isRemoved && $0.imageURL != nil }
            .prefix(3)
            .compactMap { $0.imageURL }
    }

    private var recentEvents: [ChangeType: Int] {
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        return Dictionary(grouping: store.changeEvents.filter { $0.occurredAt > cutoff }) { $0.changeType }
            .mapValues { $0.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Side-by-side images
            HStack(spacing: 4) {
                if previewImages.isEmpty {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.fill.tertiary)
                        .aspectRatio(3, contentMode: .fit)
                        .overlay {
                            Image(systemName: "photo.on.rectangle")
                                .font(.largeTitle)
                                .foregroundStyle(.quaternary)
                        }
                } else {
                    ForEach(previewImages, id: \.self) { url in
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Rectangle()
                                .fill(.fill.tertiary)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipped()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Store info + badges
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text("\(productCount) products")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Badges for recent events (last 24h)
                HStack(spacing: 6) {
                    if let drops = recentEvents[.priceDropped], drops > 0 {
                        EventBadge(
                            icon: ChangeType.priceDropped.icon,
                            count: drops,
                            color: ChangeType.priceDropped.color
                        )
                    }
                    if let stock = recentEvents[.backInStock], stock > 0 {
                        EventBadge(icon: ChangeType.backInStock.icon, count: stock, color: ChangeType.backInStock.color)
                    }
                    if let new = recentEvents[.newProduct], new > 0 {
                        EventBadge(icon: ChangeType.newProduct.icon, count: new, color: ChangeType.newProduct.color)
                    }
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct EventBadge: View {
    let icon: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15), in: Capsule())
    }
}

// MARK: - Previews

#Preview("Empty Store") {
    let container = makePreviewContainer()
    let store = Store(name: "New Store", domain: "newstore.com")
    container.mainContext.insert(store)

    return StoreCard(store: store)
        .padding()
        .frame(width: 280)
        .modelContainer(container)
}

#Preview("With Products") {
    let container = makePreviewContainer()
    let store = Store(name: "Allbirds", domain: "allbirds.com")
    container.mainContext.insert(store)

    let products = [
        ("Wool Runners", "https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Runner_Natural_White_Profile.png"),
        ("Tree Dashers", "https://cdn.shopify.com/s/files/1/1104/4168/products/Tree_Dasher_Blizzard.png"),
        ("Wool Loungers", "https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Lounger_Natural_Grey.png")
    ]

    for (index, (title, imageURL)) in products.enumerated() {
        let product = Product(
            shopifyId: Int64(index + 1),
            handle: title.lowercased().replacingOccurrences(of: " ", with: "-"),
            title: title,
            imageURL: URL(string: imageURL)
        )
        product.store = store
        container.mainContext.insert(product)
    }

    return StoreCard(store: store)
        .padding()
        .frame(width: 280)
        .modelContainer(container)
}

#Preview("With Price Drop Badge") {
    let container = makePreviewContainer()
    let store = Store(name: "Allbirds", domain: "allbirds.com")
    container.mainContext.insert(store)

    // Add a product
    let product = Product(
        shopifyId: 1,
        handle: "wool-runners",
        title: "Wool Runners"
    )
    product.store = store
    container.mainContext.insert(product)

    // Add recent price drop events (within 24h)
    for idx in 0..<3 {
        let event = ChangeEvent(
            changeType: .priceDropped,
            productTitle: "Product \(idx + 1)",
            oldValue: "$100",
            newValue: "$80",
            store: store
        )
        container.mainContext.insert(event)
    }

    return StoreCard(store: store)
        .padding()
        .frame(width: 280)
        .modelContainer(container)
}

#Preview("With Back In Stock Badge") {
    let container = makePreviewContainer()
    let store = Store(name: "Allbirds", domain: "allbirds.com")
    container.mainContext.insert(store)

    // Add products
    for idx in 0..<2 {
        let product = Product(
            shopifyId: Int64(idx + 1),
            handle: "product-\(idx)",
            title: "Product \(idx + 1)"
        )
        product.store = store
        container.mainContext.insert(product)
    }

    // Add recent back in stock events
    for idx in 0..<2 {
        let event = ChangeEvent(
            changeType: .backInStock,
            productTitle: "Product \(idx + 1)",
            store: store
        )
        container.mainContext.insert(event)
    }

    // Also add a new product event
    let newProductEvent = ChangeEvent(
        changeType: .newProduct,
        productTitle: "New Item",
        store: store
    )
    container.mainContext.insert(newProductEvent)

    return StoreCard(store: store)
        .padding()
        .frame(width: 280)
        .modelContainer(container)
}
