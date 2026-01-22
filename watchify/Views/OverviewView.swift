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

    var body: some View {
        Group {
            if viewModel.stores.isEmpty {
                ContentUnavailableView {
                    Label("No Stores", systemImage: "storefront")
                } description: {
                    Text("Add a store to start monitoring products")
                } actions: {
                    Button("Add Store") { onAddStore() }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.stores) { store in
                            StoreCard(store: store) {
                                selection = .store(store.id)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Overview")
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
