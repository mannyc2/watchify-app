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
    @State private var rateLimitRetryAfter: TimeInterval?
    @State private var otherError: Error?

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
        .alert("Sync Failed", isPresented: .constant(otherError != nil)) {
            Button("OK") { otherError = nil }
        } message: {
            if let error = otherError {
                Text(error.localizedDescription)
            }
        }
    }

    private func sync() async {
        rateLimitRetryAfter = nil
        isSyncing = true
        defer { isSyncing = false }

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

#Preview {
    StoreDetailView(store: Store(name: "Test Store", domain: "test.myshopify.com"))
        .modelContainer(for: [Store.self, Product.self, Variant.self], inMemory: true)
}
