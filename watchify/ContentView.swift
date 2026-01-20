//
//  ContentView.swift
//  watchify
//
//  Created by cjpher on 1/19/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var stores: [Store]
    @State private var showingAddStore = false
    @State private var selection: SidebarSelection? = .overview

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, onAddStore: { showingAddStore = true })
        } detail: {
            switch selection {
            case .overview:
                OverviewView(
                    selection: $selection,
                    onAddStore: { showingAddStore = true }
                )
            case .activity:
                ActivityView()
            case .store(let id):
                if let store = stores.first(where: { $0.id == id }) {
                    NavigationStack {
                        StoreDetailView(store: store)
                    }
                } else {
                    ContentUnavailableView(
                        "Store Not Found",
                        systemImage: "storefront",
                        description: Text("The selected store could not be found")
                    )
                }
            case nil:
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "sidebar.left",
                    description: Text("Select an item from the sidebar")
                )
            }
        }
        .sheet(isPresented: $showingAddStore) {
            AddStoreSheet(selection: $selection)
        }
    }
}

#Preview {
    ContentView()
        .environment(SyncScheduler.shared)
        .modelContainer(for: [Store.self, Product.self, Variant.self, ChangeEvent.self], inMemory: true)
}
