//
//  ActivityView.swift
//  watchify
//

import OSLog
import SwiftData
import SwiftUI
import TipKit

enum DateRange: String, CaseIterable {
    case today = "Today"
    case week = "7 Days"
    case month = "30 Days"
    case all = "All Time"

    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .month:
            return calendar.date(byAdding: .day, value: -30, to: now)
        case .all:
            return nil
        }
    }
}

enum TypeFilter: String, CaseIterable {
    case all = "All Types"
    case price = "Price"
    case stock = "Stock"
    case product = "Product"

    var changeTypes: [ChangeType]? {
        switch self {
        case .all:
            return nil
        case .price:
            return [.priceDropped, .priceIncreased]
        case .stock:
            return [.backInStock, .outOfStock]
        case .product:
            return [.newProduct, .productRemoved]
        }
    }
}

struct ActivityView: View {
    @State private var viewModel: ActivityViewModel?

    var body: some View {
        Group {
            if let viewModel {
                ActivityContentView(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if viewModel == nil {
                let activityVM = ActivityViewModel()
                viewModel = activityVM
                await activityVM.loadInitial()
            }
        }
    }
}

/// Inner view that displays activity content once ViewModel is ready.
private struct ActivityContentView: View {
    @Bindable var viewModel: ActivityViewModel

    private var isOffline: Bool {
        !NetworkMonitor.shared.isConnected
    }

    private var hasBackgroundErrors: Bool {
        BackgroundSyncState.shared.hasErrors
    }

    private var errorSummary: String? {
        BackgroundSyncState.shared.errorSummary
    }

    var body: some View {
        Group {
            if viewModel.events.isEmpty && !viewModel.hasMore {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "clock.badge.exclamationmark",
                    description: Text(emptyStateMessage)
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        TipView(ActivityTip())
                            .padding(.horizontal)
                            .padding(.top, 8)

                        if hasBackgroundErrors, let summary = errorSummary {
                            CompactErrorBannerView(
                                message: summary,
                                onDismiss: { BackgroundSyncState.shared.clearAllErrors() }
                            )
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }

                        ForEach(viewModel.listItems) { item in
                            ActivityListItemView(
                                item: item,
                                lastEventId: viewModel.lastEventId,
                                hasMore: viewModel.hasMore,
                                onMarkRead: { viewModel.markEventRead(id: $0) },
                                onLoadMore: { Task { await viewModel.fetchEvents(reset: false) } }
                            )
                        }

                        if viewModel.hasMore {
                            ProgressView()
                                .padding()
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Activity")
        .navigationSubtitle(isOffline ? "Offline" : viewModel.subtitleText)
        .toolbar { toolbarContent }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Activity feed")
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if viewModel.hasUnreadEvents {
                Button("Mark All Read") {
                    viewModel.markAllRead()
                }
                .help("Mark all events as read")
                .accessibilityLabel("Mark all events as read")
            }
        }

        ToolbarItemGroup(placement: .secondaryAction) {
            Picker("Store", selection: $viewModel.selectedStoreId) {
                Text("All Stores").tag(nil as UUID?)
                ForEach(viewModel.stores) { store in
                    Text(store.name).tag(store.id as UUID?)
                }
            }
            .help("Filter by store")
            .accessibilityLabel("Filter by store")

            Picker("Type", selection: $viewModel.selectedType) {
                ForEach(TypeFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .help("Filter by change type")
            .accessibilityLabel("Filter by change type")

            Picker("Date", selection: $viewModel.dateRange) {
                ForEach(DateRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .help("Filter by date range")
            .accessibilityLabel("Filter by date range")

            if viewModel.hasActiveFilters {
                Button("Clear Filters") {
                    viewModel.selectedStoreId = nil
                    viewModel.selectedType = .all
                    viewModel.dateRange = .all
                }
                .help("Reset all filters")
            }
        }
    }

    // MARK: - Helpers

    private var emptyStateMessage: String {
        if viewModel.hasActiveFilters {
            return "No events match your filters. Try adjusting your filters."
        } else {
            return "Price drops, restocks, and new products will appear here as stores sync."
        }
    }
}

// MARK: - Activity List Item View

/// Renders a single item in the flattened activity list.
private struct ActivityListItemView: View {
    let item: ActivityListItem
    let lastEventId: UUID?
    let hasMore: Bool
    let onMarkRead: (UUID) -> Void
    let onLoadMore: () -> Void

    var body: some View {
        switch item {
        case .header(_, let title):
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassPill()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 16)
                .padding(.bottom, 8)

        case .event(let event, let showDivider):
            VStack(spacing: 0) {
                ActivityRowDTO(event: event) {
                    onMarkRead(event.id)
                }
                .onAppear {
                    if event.id == lastEventId && hasMore {
                        onLoadMore()
                    }
                }

                if showDivider {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Empty - No Events") {
    NavigationStack {
        ActivityView()
    }
    .modelContainer(makePreviewContainer())
}

#Preview("Empty - Filtered") {
    let container = makePreviewContainer()

    // Add a store and event that won't match "Today" filter
    let store = Store(name: "Test Store", domain: "test.com")
    container.mainContext.insert(store)

    let event = ChangeEvent(
        changeType: .priceDropped,
        productTitle: "Test Product",
        oldValue: "$100",
        newValue: "$80",
        priceChange: -20,
        store: store
    )
    event.occurredAt = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    container.mainContext.insert(event)

    return NavigationStack {
        ActivityView()
    }
    .modelContainer(container)
}

#Preview("With Events") {
    let container = makePreviewContainer()

    let store = Store(name: "Allbirds", domain: "allbirds.com")
    container.mainContext.insert(store)

    // Today's events
    let event1 = ChangeEvent(
        changeType: .priceDropped,
        productTitle: "Wool Runners",
        variantTitle: "Size 10",
        oldValue: "$110",
        newValue: "$89",
        priceChange: -21,
        store: store
    )
    container.mainContext.insert(event1)

    let event2 = ChangeEvent(
        changeType: .backInStock,
        productTitle: "Tree Dashers",
        store: store
    )
    container.mainContext.insert(event2)

    // Yesterday's event
    let event3 = ChangeEvent(
        changeType: .priceIncreased,
        productTitle: "Wool Loungers",
        oldValue: "$95",
        newValue: "$105",
        priceChange: 10,
        store: store
    )
    event3.occurredAt = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    container.mainContext.insert(event3)

    return NavigationStack {
        ActivityView()
    }
    .modelContainer(container)
}
