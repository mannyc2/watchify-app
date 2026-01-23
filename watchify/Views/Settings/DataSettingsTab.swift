//
//  DataSettingsTab.swift
//  watchify
//

import SwiftUI

struct DataSettingsTab: View {
    @AppStorage("autoDeleteEvents") private var autoDeleteEvents = false
    @AppStorage("eventRetentionDays") private var eventRetentionDays = 90
    @AppStorage("autoDeleteSnapshots") private var autoDeleteSnapshots = false
    @AppStorage("snapshotRetentionDays") private var snapshotRetentionDays = 90
    @State private var showingClearConfirmation = false

    var body: some View {
        Form {
            Section("Event Retention") {
                Toggle("Auto-delete old events", isOn: $autoDeleteEvents)
                if autoDeleteEvents {
                    HStack {
                        Text("Keep events for")
                        TextField("", value: $eventRetentionDays, format: .number)
                            .frame(width: 60)
                            .accessibilityLabel("Event retention days")
                        Text("days")
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Section("Price History Retention") {
                Toggle("Auto-delete old price history", isOn: $autoDeleteSnapshots)
                if autoDeleteSnapshots {
                    HStack {
                        Text("Keep snapshots for")
                        TextField("", value: $snapshotRetentionDays, format: .number)
                            .frame(width: 60)
                            .accessibilityLabel("Snapshot retention days")
                        Text("days")
                    }
                    .accessibilityElement(children: .combine)
                    Text("Snapshots older than \(snapshotRetentionDays) days will be deleted during sync")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Manual Cleanup") {
                Button("Clear All Events...", role: .destructive) {
                    showingClearConfirmation = true
                }
                .accessibilityLabel("Clear all events")
                .accessibilityHint("This cannot be undone")
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
