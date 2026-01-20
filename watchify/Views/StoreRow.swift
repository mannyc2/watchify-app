//
//  StoreRow.swift
//  watchify
//

import SwiftData
import SwiftUI

struct StoreRow: View {
    @Environment(\.modelContext) private var modelContext
    let store: Store
    var onDelete: (() -> Void)?

    var body: some View {
        Text(store.name)
            .contextMenu {
                Button(role: .destructive) {
                    onDelete?()
                    modelContext.delete(store)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}

#Preview {
    StoreRow(store: Store(name: "Allbirds", domain: "allbirds.com"))
        .modelContainer(for: Store.self, inMemory: true)
}
