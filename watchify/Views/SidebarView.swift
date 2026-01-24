//
//  SidebarView.swift
//  watchify
//

import SwiftUI
import TipKit

enum SidebarSelection: Hashable {
    case overview
    case activity
    case store(UUID)
}

struct SidebarView: View {
    var viewModel: StoreListViewModel
    @Binding var selection: SidebarSelection?
    var onAddStore: () -> Void

    var body: some View {
        List(selection: $selection) {
            Label("Overview", systemImage: "square.grid.2x2")
                .tag(SidebarSelection.overview)
                .accessibilityIdentifier("SidebarItem-Overview")

            Label("Activity", systemImage: "clock.arrow.circlepath")
                .badge(viewModel.unreadCount)
                .tag(SidebarSelection.activity)
                .accessibilityLabel("Activity, \(viewModel.unreadCount) unread")
                .accessibilityIdentifier("SidebarItem-Activity")

            Section("Stores") {
                ForEach(viewModel.stores) { store in
                    StoreRow(store: store) {
                        if case .store(store.id) = selection {
                            selection = nil
                        }
                        Task { await viewModel.deleteStore(id: store.id) }
                    }
                    .tag(SidebarSelection.store(store.id))
                }
            }
        }
        .navigationTitle("Watchify")
        .safeAreaInset(edge: .bottom) {
            Button { onAddStore() } label: {
                Label("Add Store", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("AddStoreButton")
            .popoverTip(AddStoreTip())
            .help("Add a Shopify store to monitor")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sidebar navigation")
    }
}

// MARK: - Previews

#Preview("Empty Stores") {
    @Previewable @State var selection: SidebarSelection? = .overview
    @Previewable @State var viewModel = StoreListViewModel(previewStores: [])

    SidebarView(viewModel: viewModel, selection: $selection, onAddStore: {})
}

#Preview("With Stores") {
    @Previewable @State var selection: SidebarSelection? = .overview
    @Previewable @State var viewModel = StoreListViewModel(previewStores: [
        StoreDTO(name: "Allbirds", domain: "allbirds.com"),
        StoreDTO(name: "Gymshark", domain: "gymshark.com"),
        StoreDTO(name: "MVMT Watches", domain: "mvmt.com")
    ])

    SidebarView(viewModel: viewModel, selection: $selection, onAddStore: {})
}

#Preview("With Unread Badge") {
    @Previewable @State var selection: SidebarSelection? = .overview
    @Previewable @State var viewModel = StoreListViewModel(
        previewStores: [StoreDTO(name: "Allbirds", domain: "allbirds.com")],
        previewUnreadCount: 5
    )

    SidebarView(viewModel: viewModel, selection: $selection, onAddStore: {})
}
