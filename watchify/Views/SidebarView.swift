//
//  SidebarView.swift
//  watchify
//

import SwiftData
import SwiftUI

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Store.addedAt, order: .reverse) private var stores: [Store]
    @Binding var selection: Store?

    var body: some View {
        List(selection: $selection) {
            ForEach(stores) { store in
                StoreRow(store: store) {
                    if selection?.id == store.id {
                        selection = nil
                    }
                }
                .tag(store)
            }
            .onDelete(perform: deleteStores)
        }
        .navigationTitle("Stores")
    }

    private func deleteStores(at offsets: IndexSet) {
        for index in offsets {
            let store = stores[index]
            if selection?.id == store.id {
                selection = nil
            }
            modelContext.delete(store)
        }
    }
}

#Preview {
    @Previewable @State var selection: Store?
    SidebarView(selection: $selection)
        .modelContainer(for: Store.self, inMemory: true)
}
