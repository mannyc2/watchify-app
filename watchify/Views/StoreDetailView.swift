//
//  StoreDetailView.swift
//  watchify
//

import SwiftData
import SwiftUI

struct StoreDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncScheduler.self) private var syncScheduler
    let store: Store

    @Query private var products: [Product]
    @State private var isLocalSyncing = false
    @State private var rateLimitRetryAfter: TimeInterval?
    @State private var otherError: Error?

    private let storeService = StoreService()

    private var isSyncing: Bool {
        isLocalSyncing || syncScheduler.isSyncing(store)
    }

    init(store: Store) {
        self.store = store
        let storeId = store.id
        _products = Query(
            filter: #Predicate<Product> { product in
                product.store?.id == storeId && !product.isRemoved
            },
            sort: \Product.title
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let retryAfter = rateLimitRetryAfter {
                SyncStatusView(
                    retryAfter: retryAfter,
                    onRetry: { Task { await sync() } },
                    onDismiss: { rateLimitRetryAfter = nil }
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()

            Group {
                if products.isEmpty {
                    ContentUnavailableView {
                        Label("No Products", systemImage: "tray")
                    } description: {
                        Text("This store has no products, or they haven't been synced yet.")
                    } actions: {
                        Button("Sync Now") {
                            Task { await sync() }
                        }
                        .disabled(isSyncing)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 160, maximum: 200))],
                            spacing: 12
                        ) {
                            ForEach(products) { product in
                                ProductCard(product: product)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .alert("Sync Failed", isPresented: .constant(otherError != nil)) {
            Button("OK") { otherError = nil }
        } message: {
            if let error = otherError {
                Text(error.localizedDescription)
            }
        }
        .navigationDestination(for: Product.self) { product in
            ProductDetailView(product: product)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(store.name)
                    .font(.title.bold())
                Spacer()
                syncButton
            }

            HStack(spacing: 4) {
                Text(store.domain)
                Text("·")
                Text("\(products.count) products")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let lastFetched = store.lastFetchedAt {
                Text("Last synced \(lastFetched, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Never synced")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    private var syncButton: some View {
        Button {
            Task { await sync() }
        } label: {
            if isSyncing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("Sync", systemImage: "arrow.trianglehead.2.clockwise")
            }
        }
        .disabled(isSyncing)
    }

    private func sync() async {
        rateLimitRetryAfter = nil
        isLocalSyncing = true
        defer { isLocalSyncing = false }

        do {
            let changes = try await storeService.syncStore(store, context: modelContext)
            await NotificationService.shared.send(for: changes)
        } catch let error as SyncError {
            if case .rateLimited(let retryAfter) = error {
                withAnimation { rateLimitRetryAfter = retryAfter }
            }
        } catch {
            otherError = error
        }
    }
}

struct ProductRow: View {
    let product: Product

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(product.title)
                if let variant = product.variants.first {
                    Text(variant.price, format: .currency(code: "USD"))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if product.isAvailable {
                Text("In Stock")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Text("Out of Stock")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Previews

#Preview("Empty Products") {
    StoreDetailView(store: Store(name: "Test Store", domain: "test.myshopify.com"))
        .environment(SyncScheduler.shared)
        .modelContainer(
            for: [Store.self, Product.self, Variant.self, VariantSnapshot.self, ChangeEvent.self],
            inMemory: true
        )
}

#Preview("With Products") {
    let container = makePreviewContainer()
    let store = Store(name: "Allbirds", domain: "allbirds.com")
    store.lastFetchedAt = Date().addingTimeInterval(-3600)
    container.mainContext.insert(store)

    let imageBase = "https://cdn.shopify.com/s/files/1/1104/4168/products"
    let titles = ["Wool Runners", "Tree Dashers", "Wool Loungers", "Tree Breezers"]
    let prices: [Decimal] = [110, 125, 95, 100]
    let availability = [true, true, false, true]
    let images = ["Wool_Runner.png", "Tree_Dasher.png", nil, "Tree_Breezer.png"]

    for idx in titles.indices {
        let product = Product(
            shopifyId: Int64(idx + 1),
            handle: titles[idx].lowercased().replacingOccurrences(of: " ", with: "-"),
            title: titles[idx]
        )
        product.store = store
        if let imageName = images[idx] {
            product.imageURLs = ["\(imageBase)/\(imageName)"]
        }
        container.mainContext.insert(product)

        let variant = Variant(
            shopifyId: Int64(idx + 100),
            title: "Default",
            price: prices[idx],
            available: availability[idx],
            position: 0
        )
        variant.product = product
        container.mainContext.insert(variant)
    }

    return StoreDetailView(store: store)
        .environment(SyncScheduler.shared)
        .modelContainer(container)
}

#Preview("Rate Limited") {
    let container = makePreviewContainer()
    let store = Store(name: "Busy Store", domain: "busy.myshopify.com")
    container.mainContext.insert(store)

    return VStack(spacing: 0) {
        SyncStatusView(
            retryAfter: 30,
            onRetry: {},
            onDismiss: {}
        )
        .padding(.horizontal)
        .padding(.vertical, 8)

        Divider()

        ContentUnavailableView {
            Label("No Products", systemImage: "tray")
        } description: {
            Text("This store has no products, or they haven't been synced yet.")
        }
    }
    .modelContainer(container)
}

#Preview("ProductRow - In Stock") {
    let container = makePreviewContainer()
    let product = Product(
        shopifyId: 1,
        handle: "wool-runners",
        title: "Wool Runners"
    )
    container.mainContext.insert(product)

    let variant = Variant(
        shopifyId: 100,
        title: "Size 10",
        price: Decimal(110),
        available: true,
        position: 0
    )
    variant.product = product
    container.mainContext.insert(variant)

    return List {
        ProductRow(product: product)
    }
    .modelContainer(container)
}

#Preview("ProductRow - Out of Stock") {
    let container = makePreviewContainer()
    let product = Product(
        shopifyId: 2,
        handle: "tree-dashers",
        title: "Tree Dashers"
    )
    container.mainContext.insert(product)

    let variant = Variant(
        shopifyId: 200,
        title: "Size 9",
        price: Decimal(125),
        available: false,
        position: 0
    )
    variant.product = product
    container.mainContext.insert(variant)

    return List {
        ProductRow(product: product)
    }
    .modelContainer(container)
}
