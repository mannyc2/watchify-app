import SwiftData
import SwiftUI

struct StoreCard: View {
    let store: Store
    let onSelect: () -> Void

    @State private var isHovering = false

    private let cornerRadius: CGFloat = 16

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
        return Dictionary(grouping: store.changeEvents.filter { $0.occurredAt > cutoff }) {
            $0.changeType
        }
        .mapValues { $0.count }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Button(action: onSelect) {
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
                            Badge(
                                text: "\(drops)",
                                icon: ChangeType.priceDropped.icon,
                                color: ChangeType.priceDropped.color
                            )
                        }
                        if let stock = recentEvents[.backInStock], stock > 0 {
                            Badge(
                                text: "\(stock)",
                                icon: ChangeType.backInStock.icon,
                                color: ChangeType.backInStock.color
                            )
                        }
                        if let new = recentEvents[.newProduct], new > 0 {
                            Badge(
                                text: "\(new)",
                                icon: ChangeType.newProduct.icon,
                                color: ChangeType.newProduct.color
                            )
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contentShape(shape)
        .interactiveGlassCard(isHovering: isHovering, cornerRadius: cornerRadius)
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.18), value: isHovering)
    }
}

// MARK: - Previews

#Preview("Empty Store") {
    let container = makePreviewContainer()
    let store = Store(name: "New Store", domain: "newstore.com")
    container.mainContext.insert(store)

    return StoreCard(store: store) {}
        .padding()
        .frame(width: 280)
        .modelContainer(container)
}

#Preview("With Products") {
    let container = makePreviewContainer()
    let store = Store(name: "Allbirds", domain: "allbirds.com")
    container.mainContext.insert(store)

    let products = [
        (
            "Wool Runners",
            "https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Runner_Natural_White_Profile.png"
        ),
        (
            "Tree Dashers",
            "https://cdn.shopify.com/s/files/1/1104/4168/products/Tree_Dasher_Blizzard.png"
        ),
        (
            "Wool Loungers",
            "https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Lounger_Natural_Grey.png"
        )
    ]

    for (index, (title, imageURLString)) in products.enumerated() {
        let product = Product(
            shopifyId: Int64(index + 1),
            handle: title.lowercased().replacingOccurrences(of: " ", with: "-"),
            title: title
        )
        product.store = store
        product.imageURLs = [imageURLString]
        container.mainContext.insert(product)
    }

    return StoreCard(store: store) {}
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
            priceChange: -20,
            store: store
        )
        container.mainContext.insert(event)
    }

    return StoreCard(store: store) {}
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

    return StoreCard(store: store) {}
        .padding()
        .frame(width: 280)
        .modelContainer(container)
}
