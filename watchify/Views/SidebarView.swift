//
//  SidebarView.swift
//  watchify
//

import SwiftData
import SwiftUI

enum SidebarSelection: Hashable {
    case overview
    case activity
    case store(Store.ID)
}

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Store.addedAt, order: .reverse) private var stores: [Store]
    @Query(filter: #Predicate<ChangeEvent> { !$0.isRead })
    private var unreadEvents: [ChangeEvent]
    @Binding var selection: SidebarSelection?
    var onAddStore: () -> Void

    var body: some View {
        List(selection: $selection) {
            Label("Overview", systemImage: "square.grid.2x2")
                .tag(SidebarSelection.overview)

            Label("Activity", systemImage: "clock.arrow.circlepath")
                .badge(unreadEvents.count)
                .tag(SidebarSelection.activity)

            Section("Stores") {
                ForEach(stores) { store in
                    StoreRow(store: store) {
                        if case .store(store.id) = selection {
                            selection = nil
                        }
                    }
                    .tag(SidebarSelection.store(store.id))
                }
                .onDelete(perform: deleteStores)

                Button { onAddStore() } label: {
                    Label("Add Store", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Watchify")
    }

    private func deleteStores(at offsets: IndexSet) {
        for index in offsets {
            let store = stores[index]
            if case .store(store.id) = selection {
                selection = nil
            }
            modelContext.delete(store)
        }
    }
}

// MARK: - Previews

#Preview("Empty Stores") {
    @Previewable @State var selection: SidebarSelection? = .overview
    SidebarView(selection: $selection, onAddStore: {})
        .modelContainer(for: Store.self, inMemory: true)
}

#Preview("With Stores") {
    @Previewable @State var selection: SidebarSelection? = .overview
    SidebarPreviewWithStores(selection: $selection)
}

#Preview("With Store Selected") {
    @Previewable @State var selection: SidebarSelection? = .overview
    SidebarPreviewWithSelectedStore(selection: $selection)
}

/// Helper view to set up stores before rendering the sidebar
private struct SidebarPreviewWithStores: View {
    @Binding var selection: SidebarSelection?

    var body: some View {
        let container = makePreviewContainer()

        let storeData = [
            ("Allbirds", "allbirds.com"),
            ("Gymshark", "gymshark.com"),
            ("MVMT Watches", "mvmt.com")
        ]

        for (name, domain) in storeData {
            let store = Store(name: name, domain: domain)
            container.mainContext.insert(store)
        }

        return SidebarView(selection: $selection, onAddStore: {})
            .modelContainer(container)
    }
}

/// Helper view to set up a selected store before rendering the sidebar
private struct SidebarPreviewWithSelectedStore: View {
    @Binding var selection: SidebarSelection?

    var body: some View {
        let container = makePreviewContainer()
        let store = Store(name: "Allbirds", domain: "allbirds.com")
        container.mainContext.insert(store)

        return SidebarView(selection: .constant(.store(store.id)), onAddStore: {})
            .modelContainer(container)
    }
}
