//
//  MenuBarView.swift
//  watchify
//

import SwiftData
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    @State private var viewModel: MenuBarViewModel?

    var body: some View {
        Group {
            if let viewModel {
                MenuBarContentView(viewModel: viewModel, openWindow: openWindow)
            } else {
                ProgressView()
                    .frame(width: 340, height: 400)
            }
        }
        .task {
            if viewModel == nil {
                let menuBarVM = MenuBarViewModel()
                viewModel = menuBarVM
                await menuBarVM.loadEvents()
            }
        }
    }
}

/// Inner view that displays menu bar content once ViewModel is ready.
private struct MenuBarContentView: View {
    @Bindable var viewModel: MenuBarViewModel
    let openWindow: OpenWindowAction

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recent Changes")
                    .font(.headline)
                Spacer()
                if viewModel.hasUnreadEvents {
                    Button("Mark All Read") {
                        viewModel.markAllRead()
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .accessibilityLabel("Mark all events as read")
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Event list
            if viewModel.events.isEmpty {
                ContentUnavailableView(
                    "No Changes Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Changes will appear here as they're detected")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.events) { event in
                            MenuBarEventRowDTO(event: event) {
                                viewModel.markEventRead(id: event.id)
                            }
                            if event.id != viewModel.events.last?.id {
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
                .buttonStyle(.glass)
                .accessibilityLabel("Open Watchify main window")

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Quit Watchify")
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .frame(width: 340, height: 400)
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
