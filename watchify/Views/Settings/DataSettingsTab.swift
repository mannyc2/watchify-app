//
//  DataSettingsTab.swift
//  watchify
//

import SwiftUI

struct DataSettingsTab: View {
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
        Task {
            await StoreService.shared.deleteAllEvents()
        }
    }
}

#Preview {
    DataSettingsTab()
}
