//
//  MenuBarView.swift
//  watchify
//

import SwiftData
import SwiftUI

struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @Query(
        filter: #Predicate<ChangeEvent> { !$0.isRead },
        sort: \ChangeEvent.occurredAt,
        order: .reverse
    )
    private var unreadEvents: [ChangeEvent]

    @Query(sort: \ChangeEvent.occurredAt, order: .reverse)
    private var allEvents: [ChangeEvent]

    // Show unread if any, otherwise recent
    private var displayEvents: [ChangeEvent] {
        let events = unreadEvents.isEmpty ? Array(allEvents.prefix(10)) : Array(unreadEvents.prefix(10))
        return events
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recent Changes")
                    .font(.headline)
                Spacer()
                if !unreadEvents.isEmpty {
                    Button("Mark All Read") {
                        markAllRead()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Event list
            if displayEvents.isEmpty {
                ContentUnavailableView(
                    "No Changes Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Changes will appear here as they're detected")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayEvents) { event in
                            MenuBarEventRow(event: event)
                            if event.id != displayEvents.last?.id {
                                Divider()
                                    .padding(.leading, 44)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()

            // Action buttons
            HStack(spacing: 8) {
                Spacer()

                Button("Open Watchify") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.bordered)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
        .frame(width: 340, height: 400)
    }

    private func markAllRead() {
        for event in unreadEvents {
            event.isRead = true
        }
    }
}

// MARK: - Previews

#Preview("With Events") {
    let container = makePreviewContainer()

    let events = [
        ChangeEvent(
            changeType: .priceDropped,
            productTitle: "Wool Runners",
            variantTitle: "Size 10 / Natural White",
            oldValue: "$110",
            newValue: "$89",
            priceChange: -21
        ),
        ChangeEvent(
            changeType: .backInStock,
            productTitle: "Tree Dashers",
            variantTitle: "Size 9 / Thunder"
        ),
        ChangeEvent(
            changeType: .priceIncreased,
            productTitle: "Wool Loungers",
            variantTitle: "Size 11",
            oldValue: "$95",
            newValue: "$105",
            priceChange: 10
        )
    ]

    for event in events {
        container.mainContext.insert(event)
    }

    return MenuBarView()
        .modelContainer(container)
}

#Preview("Empty") {
    let container = makePreviewContainer()
    return MenuBarView()
        .modelContainer(container)
}

#Preview("All Read") {
    let container = makePreviewContainer()

    let event = ChangeEvent(
        changeType: .priceDropped,
        productTitle: "Wool Runners",
        newValue: "$89",
        priceChange: -21
    )
    event.isRead = true
    container.mainContext.insert(event)

    return MenuBarView()
        .modelContainer(container)
}
