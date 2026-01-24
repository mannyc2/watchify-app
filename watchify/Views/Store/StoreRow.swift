//
//  StoreRow.swift
//  watchify
//

import SwiftUI

struct StoreRow: View {
    let store: StoreDTO
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "storefront")
                .foregroundStyle(.secondary)
                .imageScale(.medium)
                .frame(width: 18)
                .accessibilityHidden(true)

            Text(store.name)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(store.name)
        .accessibilityIdentifier("StoreRow-\(store.name)")
        .contextMenu {
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    List {
        StoreRow(store: StoreDTO(name: "Allbirds", domain: "allbirds.com"))
    }
}
