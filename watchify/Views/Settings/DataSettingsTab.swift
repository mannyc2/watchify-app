//
//  DataSettingsTab.swift
//  watchify
//

import SwiftData
import SwiftUI

struct DataSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("autoDeleteEvents") private var autoDelete = false
    @AppStorage("eventRetentionDays") private var retentionDays = 90
    @State private var showingClearConfirmation = false

    var body: some View {
        Form {
            Section("Data Retention") {
                Toggle("Auto-delete old events", isOn: $autoDelete)
                if autoDelete {
                    HStack {
                        Text("Keep events for")
                        TextField("", value: $retentionDays, format: .number)
                            .frame(width: 60)
                        Text("days")
                    }
                }
            }

            Section("Manual Cleanup") {
                Button("Clear All Events...", role: .destructive) {
                    showingClearConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Clear all events?", isPresented: $showingClearConfirmation) {
            Button("Clear All Events", role: .destructive) {
                clearAllEvents()
            }
        } message: {
            Text("This will permanently delete all activity history.")
        }
    }

    private func clearAllEvents() {
        try? modelContext.delete(model: ChangeEvent.self)
    }
}

#Preview {
    DataSettingsTab()
        .modelContainer(for: ChangeEvent.self, inMemory: true)
}
