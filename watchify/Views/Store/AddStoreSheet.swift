//
//  AddStoreSheet.swift
//  watchify
//

import SwiftUI
import TipKit

struct AddStoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: SidebarSelection?

    @State private var domain = ""
    @State private var name = ""
    @State private var isAdding = false
    @State private var error: String?

    private var normalizedDomain: String {
        var result = domain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        for prefix in ["https://", "http://", "www."] where result.hasPrefix(prefix) {
            result.removeFirst(prefix.count)
        }
        while result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }

    private var canAdd: Bool {
        !normalizedDomain.isEmpty && !isAdding
    }

    var body: some View {
        Form {
            TextField("Domain", text: $domain, prompt: Text("allbirds.com"))
                .autocorrectionDisabled()
                .accessibilityLabel("Store domain")
                .accessibilityHint("Enter the Shopify store domain, for example allbirds.com")
            TextField("Name (optional)", text: $name, prompt: Text("Allbirds"))
                .accessibilityLabel("Store name")
                .accessibilityHint("Optional display name for the store")

            if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .accessibilityIdentifier("AddStoreError")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 300)
        .disabled(isAdding)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(isAdding)
            }
            ToolbarItem(placement: .confirmationAction) {
                if isAdding {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Adding store")
                } else {
                    Button("Add") { Task { await addStore() } }
                        .disabled(!canAdd)
                }
            }
        }
        .onChange(of: domain) { error = nil }
    }

    private func addStore() async {
        isAdding = true
        defer { isAdding = false }

        do {
            let storeId = try await StoreService.shared.addStore(
                name: name,
                domain: normalizedDomain
            )

            // Update tip state - user has added their first store
            AddStoreTip.hasAddedStore = true
            SyncTip.hasAddedStore = true

            selection = .store(storeId)
            dismiss()
        } catch {
            self.error = "Not a valid Shopify store: \(error.localizedDescription)"
        }
    }
}

#Preview("Empty Form") {
    AddStoreSheet(selection: .constant(nil))
}

#Preview("Loading State") {
    AddStoreSheetPreview(isAdding: true, error: nil)
}

#Preview("Error State") {
    AddStoreSheetPreview(isAdding: false, error: "Not a valid Shopify store: Connection failed")
}

/// Internal view for previewing AddStoreSheet states that require @State manipulation
private struct AddStoreSheetPreview: View {
    let isAdding: Bool
    let error: String?

    var body: some View {
        Form {
            TextField("Domain", text: .constant("invalid-store.com"), prompt: Text("allbirds.com"))
                .autocorrectionDisabled()
            TextField("Name (optional)", text: .constant("My Store"), prompt: Text("Allbirds"))

            if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 300)
        .disabled(isAdding)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {}
                    .disabled(isAdding)
            }
            ToolbarItem(placement: .confirmationAction) {
                if isAdding {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Add") {}
                }
            }
        }
    }
}
