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

    // MARK: - Known Issue: NSTableView Reentrancy Warning
    //
    // When navigating to this view, macOS may log:
    //   "WARNING: Application performed a reentrant operation in its NSTableView delegate"
    //
    // Root cause: SwiftUI's List uses NSOutlineView internally. During initial setup,
    // OutlineListCoordinator.configTableView() calls setDataSource:, which triggers
    // reloadData → _tileAndRedisplayAll → setFrameSize: → tile() while reloadData
    // is still on the call stack. This is an internal SwiftUI/AppKit issue.
    //
    // The warning is cosmetic and doesn't affect functionality. Apple may fix this
    // in a future SwiftUI update.

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
                    List(products) { product in
                        ProductRow(product: product)
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
        .modelContainer(for: [Store.self, Product.self, Variant.self, VariantSnapshot.self], inMemory: true)
}

#Preview("With Products") {
    let container = makePreviewContainer()
    let store = Store(name: "Allbirds", domain: "allbirds.com")
    store.lastFetchedAt = Date().addingTimeInterval(-3600)
    container.mainContext.insert(store)

    let productData = [
        ("Wool Runners", Decimal(110), true),
        ("Tree Dashers", Decimal(125), true),
        ("Wool Loungers", Decimal(95), false),
        ("Tree Breezers", Decimal(100), true)
    ]

    for (idx, (title, price, available)) in productData.enumerated() {
        let product = Product(
            shopifyId: Int64(idx + 1),
            handle: title.lowercased().replacingOccurrences(of: " ", with: "-"),
            title: title
        )
        product.store = store

        let variant = Variant(
            shopifyId: Int64(idx + 100),
            title: "Default",
            price: price,
            available: available,
            position: 0
        )
        variant.product = product
        container.mainContext.insert(product)
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
