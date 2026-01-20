//
//  OverviewView.swift
//  watchify
//

import SwiftData
import SwiftUI

struct OverviewView: View {
    @Binding var selection: SidebarSelection?
    @Query(sort: \Store.addedAt, order: .reverse) private var stores: [Store]
    var onAddStore: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
    ]

    var body: some View {
        Group {
            if stores.isEmpty {
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
                        ForEach(stores) { store in
                            StoreCard(store: store)
                                .onTapGesture {
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
    NavigationStack {
        OverviewView(selection: .constant(.overview), onAddStore: {})
    }
    .modelContainer(for: Store.self, inMemory: true)
}

#Preview("With Stores") {
    @Previewable @State var selection: SidebarSelection? = .overview

    NavigationStack {
        OverviewView(selection: $selection, onAddStore: {})
    }
    .modelContainer(for: Store.self, inMemory: true)
}
