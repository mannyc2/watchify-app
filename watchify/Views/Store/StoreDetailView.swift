//
//  StoreDetailView.swift
//  watchify
//

import OSLog
import SwiftData
import SwiftUI

// MARK: - Enums

enum StockScope: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case inStock = "In Stock"
    case outOfStock = "Out of Stock"

    var id: String { rawValue }
}

enum ProductSort: String, CaseIterable, Identifiable, Sendable {
    case name = "Name"
    case priceLowHigh = "Price: Low to High"
    case priceHighLow = "Price: High to Low"
    case recentlyAdded = "Recently Added"

    var id: String { rawValue }
}

// MARK: - StoreDetailView

struct StoreDetailView: View {
    let storeDTO: StoreDTO
    let container: ModelContainer

    @State private var viewModel: StoreDetailViewModel?

    var body: some View {
        Group {
            if let viewModel {
                StoreDetailContentView(viewModel: viewModel, container: container)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if viewModel == nil {
                let storeVM = StoreDetailViewModel(
                    storeId: storeDTO.id,
                    name: storeDTO.name,
                    domain: storeDTO.domain,
                    lastFetchedAt: storeDTO.lastFetchedAt,
                    isSyncing: storeDTO.isSyncing,
                    cachedProductCount: storeDTO.cachedProductCount
                )
                viewModel = storeVM
                await storeVM.loadInitial()
            }
        }
    }
}

// MARK: - Content View

private struct StoreDetailContentView: View {
    @Bindable var viewModel: StoreDetailViewModel
    let container: ModelContainer

    var body: some View {
        VStack(spacing: 0) {
            if let retryAfter = viewModel.rateLimitRetryAfter {
                SyncStatusView(
                    retryAfter: retryAfter,
                    onRetry: { Task { await viewModel.sync() } },
                    onDismiss: { viewModel.dismissRateLimitBanner() }
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                .transition(.move(edge: .top).combined(with: .opacity))

                Divider()
            }

            Group {
                if viewModel.totalCount == 0 && !viewModel.isLoading {
                    ContentUnavailableView {
                        Label("No Products", systemImage: "tray")
                    } description: {
                        Text("This store has no products, or they haven't been synced yet.")
                    } actions: {
                        Button("Sync Now") {
                            Task { await viewModel.sync() }
                        }
                        .disabled(viewModel.isSyncing)
                    }
                } else if viewModel.products.isEmpty && !viewModel.searchText.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else if viewModel.isLoading && viewModel.products.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 160, maximum: 200))],
                            spacing: 12
                        ) {
                            ForEach(viewModel.products) { product in
                                ProductCardDTO(product: product)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle(viewModel.storeName)
        .navigationSubtitle(viewModel.subtitleText)
        .alert("Sync Failed", isPresented: .constant(viewModel.syncError != nil)) {
            Button("OK") { viewModel.dismissSyncError() }
        } message: {
            if let error = viewModel.syncError {
                Text(error.localizedDescription)
            }
        }
        .navigationDestination(for: Int64.self) { shopifyId in
            ProductDetailViewByShopifyId(shopifyId: shopifyId)
                .modelContainer(container)
        }
        .searchable(
            text: $viewModel.searchText,
            placement: .automatic,
            prompt: "Search products"
        )
        .searchScopes($viewModel.stockScope, activation: .onSearchPresentation) {
            ForEach(StockScope.allCases) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .toolbar { toolbarContent }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                Task { await viewModel.sync() }
            } label: {
                if viewModel.isSyncing {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Sync", systemImage: "arrow.trianglehead.2.clockwise")
                }
            }
            .disabled(viewModel.isSyncing)
        }

        ToolbarItem(placement: .primaryAction) {
            Picker("Sort", selection: $viewModel.sortOrder) {
                ForEach(ProductSort.allCases) { sort in
                    Text(sort.rawValue).tag(sort)
                }
            }
        }
    }
}

// MARK: - Product Detail Lookup

/// Fetches a Product by shopifyId for the detail view.
///
/// Uses `@Environment(\.modelContext)` (main-thread) instead of StoreService because:
/// - Single row fetch by indexed column is trivial (microseconds)
/// - Read-only operation (no deadlock risk with ModelActor)
/// - Avoids unnecessary ViewModel complexity for simple detail lookup
///
/// For list views or writes, use StoreService with `Task.detached` pattern instead.
/// See: https://developer.apple.com/documentation/swiftdata/modelcontext
private struct ProductDetailViewByShopifyId: View {
    @Environment(\.modelContext) private var modelContext
    let shopifyId: Int64

    @State private var product: Product?

    var body: some View {
        Group {
            if let product {
                ProductDetailView(product: product)
            } else {
                ContentUnavailableView(
                    "Product Not Found",
                    systemImage: "cube",
                    description: Text("The selected product could not be found")
                )
            }
        }
        .onAppear {
            let id = shopifyId
            let predicate = #Predicate<Product> { $0.shopifyId == id }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            product = try? modelContext.fetch(descriptor).first
        }
    }
}

// MARK: - Previews

#Preview("Empty Products") {
    let container = makePreviewContainer()
    return StoreDetailView(
        storeDTO: StoreDTO(name: "Test Store", domain: "test.myshopify.com"),
        container: container
    )
}

#Preview("With Last Fetched") {
    let container = makePreviewContainer()
    return StoreDetailView(
        storeDTO: StoreDTO(
            name: "Allbirds",
            domain: "allbirds.com",
            lastFetchedAt: Date().addingTimeInterval(-3600),
            cachedProductCount: 42
        ),
        container: container
    )
}

#Preview("Rate Limited") {
    VStack(spacing: 0) {
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
}
