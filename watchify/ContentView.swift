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
    @State private var showingActivity = false
    @State private var selection: Store.ID?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingActivity = true
                        } label: {
                            Label("Activity", systemImage: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.glass)
                    }
                    ToolbarItem {
                        Button {
                            showingAddStore = true
                        } label: {
                            Label("Add Store", systemImage: "plus")
                        }
                    }
                }
        } detail: {
            if let storeId = selection,
               let store = stores.first(where: { $0.id == storeId }) {
                StoreDetailView(store: store)
            } else {
                ContentUnavailableView(
                    "No Store Selected",
                    systemImage: "storefront",
                    description: Text("Select a store from the sidebar to view its products")
                )
            }
        }
        .sheet(isPresented: $showingAddStore) {
            AddStoreSheet(selection: $selection)
        }
        .sheet(isPresented: $showingActivity) {
            NavigationStack {
                ActivityView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingActivity = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Store.self, Product.self, Variant.self, ChangeEvent.self], inMemory: true)
}
