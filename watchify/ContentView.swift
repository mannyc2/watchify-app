//
//  ContentView.swift
//  watchify
//
//  Created by cjpher on 1/19/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var showingAddStore = false
    @State private var selectedStore: Store?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedStore)
                .toolbar {
                    ToolbarItem {
                        Button {
                            showingAddStore = true
                        } label: {
                            Label("Add Store", systemImage: "plus")
                        }
                    }
                }
        } detail: {
            if let store = selectedStore {
                StoreDetailView(store: store)
            } else {
                Text("Select a store")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingAddStore) {
            AddStoreSheet(selection: $selectedStore)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Store.self, Product.self, Variant.self], inMemory: true)
}
