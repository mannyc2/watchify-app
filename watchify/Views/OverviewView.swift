//
//  OverviewView.swift
//  watchify
//

import SwiftUI

struct OverviewView: View {
    var viewModel: StoreListViewModel
    @Binding var selection: SidebarSelection?
    var onAddStore: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
    ]

    private var isOffline: Bool {
        !NetworkMonitor.shared.isConnected
    }

    private var hasBackgroundErrors: Bool {
        BackgroundSyncState.shared.hasErrors
    }

    private var errorSummary: String? {
        BackgroundSyncState.shared.errorSummary
    }

    var body: some View {
        Group {
            if viewModel.stores.isEmpty {
                ContentUnavailableView {
                    Label("No Stores", systemImage: "storefront")
                } description: {
                    Text("Add a Shopify store to start tracking prices and stock changes.")
                        .foregroundStyle(.secondary)
                } actions: {
                    Button("Add Store") { onAddStore() }
                        .help("Add a Shopify store to monitor")
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        if hasBackgroundErrors, let summary = errorSummary {
                            CompactErrorBannerView(
                                message: summary,
                                onDismiss: { BackgroundSyncState.shared.clearAllErrors() }
                            )
                            .padding(.horizontal, 20)
                        }

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.stores) { store in
                                StoreCard(store: store) {
                                    selection = .store(store.id)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle("Overview")
        .navigationSubtitle(isOffline ? "Offline" : "")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Overview, \(viewModel.stores.count) stores")
    }
}

#Preview("No Stores") {
    @Previewable @State var viewModel = StoreListViewModel(previewStores: [])

    NavigationStack {
        OverviewView(viewModel: viewModel, selection: .constant(.overview), onAddStore: {})
    }
}

#Preview("With Stores") {
    @Previewable @State var selection: SidebarSelection? = .overview
    @Previewable @State var viewModel = StoreListViewModel(previewStores: [
        StoreDTO(
            name: "Allbirds",
            domain: "allbirds.com",
            cachedProductCount: 42,
            cachedPreviewImageURLs: [
                "https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Runner.png",
                "https://cdn.shopify.com/s/files/1/1104/4168/products/Tree_Dasher.png",
                "https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Lounger.png"
            ]
        ),
        StoreDTO(name: "Gymshark", domain: "gymshark.com", cachedProductCount: 128, cachedPreviewImageURLs: []),
        StoreDTO(
            name: "MVMT Watches",
            domain: "mvmt.com",
            cachedProductCount: 15,
            cachedPreviewImageURLs: [
                "https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Runner.png",
                "https://cdn.shopify.com/s/files/1/1104/4168/products/Tree_Dasher.png"
            ]
        )
    ])

    NavigationStack {
        OverviewView(viewModel: viewModel, selection: $selection, onAddStore: {})
    }
}
