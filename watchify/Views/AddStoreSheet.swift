//
//  AddStoreSheet.swift
//  watchify
//

import SwiftData
import SwiftUI

struct AddStoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var selection: Store?

    @State private var domain = ""
    @State private var name = ""
    @State private var isAdding = false
    @State private var error: String?

    private let storeService = StoreService()

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
            TextField("Name (optional)", text: $name, prompt: Text("Allbirds"))

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
                Button("Cancel") { dismiss() }
                    .disabled(isAdding)
            }
            ToolbarItem(placement: .confirmationAction) {
                if isAdding {
                    ProgressView()
                        .controlSize(.small)
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
            let store = try await storeService.addStore(
                name: name,
                domain: normalizedDomain,
                context: modelContext
            )
            selection = store
            dismiss()
        } catch {
            self.error = "Not a valid Shopify store: \(error.localizedDescription)"
        }
    }
}

#Preview {
    AddStoreSheet(selection: .constant(nil))
        .modelContainer(for: Store.self, inMemory: true)
}
