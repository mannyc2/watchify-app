//
//  SidebarView.swift
//  watchify
//

import SwiftData
import SwiftUI

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Store.addedAt, order: .reverse) private var stores: [Store]
    @Binding var selection: Store.ID?

    var body: some View {
        List(selection: $selection) {
            Section("Stores") {
                if stores.isEmpty {
                    ContentUnavailableView {
                        Label("No Stores", systemImage: "storefront")
                    } description: {
                        Text("Add a store to start monitoring products")
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(stores) { store in
                        StoreRow(store: store) {
                            if selection == store.id {
                                selection = nil
                            }
                        }
                        .tag(store.id)
                    }
                    .onDelete(perform: deleteStores)
                }
            }
        }
        .navigationTitle("Watchify")
    }

    private func deleteStores(at offsets: IndexSet) {
        for index in offsets {
            let store = stores[index]
            if selection == store.id {
                selection = nil
            }
            modelContext.delete(store)
        }
    }
}

#Preview {
    @Previewable @State var selection: Store.ID?
    SidebarView(selection: $selection)
        .modelContainer(for: Store.self, inMemory: true)
}
