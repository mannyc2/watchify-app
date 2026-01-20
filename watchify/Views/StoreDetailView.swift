//
//  StoreDetailView.swift
//  watchify
//

import SwiftData
import SwiftUI

struct StoreDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let store: Store

    @Query private var products: [Product]
    @State private var isSyncing = false
    @State private var syncError: Error?

    private let storeService = StoreService()

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
        .navigationTitle(store.name)
        .toolbar {
            ToolbarItem {
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
        }
        .alert("Sync Failed", isPresented: .constant(syncError != nil)) {
            Button("OK") { syncError = nil }
        } message: {
            if let error = syncError {
                Text(error.localizedDescription)
            }
        }
    }

    private func sync() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await storeService.syncStore(store, context: modelContext)
        } catch {
            syncError = error
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

#Preview {
    StoreDetailView(store: Store(name: "Test Store", domain: "test.myshopify.com"))
        .modelContainer(for: [Store.self, Product.self, Variant.self], inMemory: true)
}
