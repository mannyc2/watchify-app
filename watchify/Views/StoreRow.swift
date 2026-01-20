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
        HStack(spacing: 8) {
            Image(systemName: "storefront")
                .foregroundStyle(.secondary)
                .imageScale(.medium)
                .frame(width: 18)

            Text(store.name)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button(role: .destructive) {
                onDelete?()
                modelContext.delete(store)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
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
