//
//  DataSettingsTab.swift
//  watchify
//

import AppKit
import SwiftUI

struct DataSettingsTab: View {
    @AppStorage("autoDeleteEvents") private var autoDeleteEvents = false
    @AppStorage("eventRetentionDays") private var eventRetentionDays = 90
    @AppStorage("autoDeleteSnapshots") private var autoDeleteSnapshots = false
    @AppStorage("snapshotRetentionDays") private var snapshotRetentionDays = 90
    @State private var showingClearConfirmation = false
    @State private var showingClearCacheConfirmation = false
    @State private var cacheSize = 0
    @State private var cacheCount = 0
    @State private var cacheSizeLimitMB = ImageService.defaultCacheSizeMB

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

            Section("Image Cache") {
                LabeledContent("Cache Size") {
                    Text("\(cacheSize.formatted(.byteCount(style: .file))) (\(cacheCount) images)")
                        .foregroundStyle(.secondary)
                }

                Picker("Maximum Size", selection: $cacheSizeLimitMB) {
                    Text("100 MB").tag(100)
                    Text("250 MB").tag(250)
                    Text("500 MB").tag(500)
                    Text("1 GB").tag(1000)
                }
                .onChange(of: cacheSizeLimitMB) { _, newValue in
                    ImageService.cacheSizeLimitMB = newValue
                }

                Button("Clear Image Cache...", role: .destructive) {
                    showingClearCacheConfirmation = true
                }

                Button("Reveal in Finder") {
                    if let url = ImageService.cacheURL {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                    }
                }
                .disabled(ImageService.cacheURL == nil)
            }
            .onAppear {
                cacheSizeLimitMB = ImageService.cacheSizeLimitMB
                refreshCacheStats()
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
        .confirmationDialog("Clear image cache?", isPresented: $showingClearCacheConfirmation) {
            Button("Clear Cache", role: .destructive) {
                ImageService.clearCache()
                refreshCacheStats()
            }
        } message: {
            Text("This will delete all cached images. They will be re-downloaded as needed.")
        }
    }

    private func clearAllEvents() {
        Task {
            await StoreService.shared.deleteAllEvents()
        }
    }

    private func refreshCacheStats() {
        cacheSize = ImageService.cacheSize
        cacheCount = ImageService.cacheCount
    }
}

#Preview {
    DataSettingsTab()
}
