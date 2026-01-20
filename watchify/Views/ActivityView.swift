//
//  ActivityView.swift
//  watchify
//

import SwiftData
import SwiftUI

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
    @Query(sort: \ChangeEvent.occurredAt, order: .reverse)
    private var allEvents: [ChangeEvent]

    @Query(sort: \Store.name)
    private var stores: [Store]

    @State private var selectedStore: Store?
    @State private var selectedType: TypeFilter = .all
    @State private var dateRange: DateRange = .all

    private var filteredEvents: [ChangeEvent] {
        allEvents.filter { event in
            // Store filter
            if let store = selectedStore, event.store?.id != store.id {
                return false
            }

            // Type filter
            if let types = selectedType.changeTypes, !types.contains(event.changeType) {
                return false
            }

            // Date filter
            if let startDate = dateRange.startDate, event.occurredAt < startDate {
                return false
            }

            return true
        }
    }

    private var groupedEvents: [(date: Date, events: [ChangeEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.occurredAt)
        }
        return grouped
            .map { (date: $0.key, events: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)

            Divider()

            Group {
                if filteredEvents.isEmpty {
                    ContentUnavailableView(
                        "No Activity",
                        systemImage: "clock.badge.exclamationmark",
                        description: Text(emptyStateMessage)
                    )
                } else {
                    List {
                        ForEach(groupedEvents, id: \.date) { group in
                            Section {
                                ForEach(group.events) { event in
                                    ActivityRow(event: event)
                                }
                            } header: {
                                Text(sectionHeader(for: group.date))
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .navigationTitle("Activity")
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Picker("Store", selection: $selectedStore) {
                Text("All Stores").tag(nil as Store?)
                ForEach(stores) { store in
                    Text(store.name).tag(store as Store?)
                }
            }
            .pickerStyle(.menu)

            Picker("Type", selection: $selectedType) {
                ForEach(TypeFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.menu)

            Picker("Date", selection: $dateRange) {
                ForEach(DateRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.menu)

            Spacer()

            if hasActiveFilters {
                Button("Clear") {
                    selectedStore = nil
                    selectedType = .all
                    dateRange = .all
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var hasActiveFilters: Bool {
        selectedStore != nil || selectedType != .all || dateRange != .all
    }

    private var emptyStateMessage: String {
        if hasActiveFilters {
            return "No events match your filters"
        } else {
            return "Changes to products will appear here"
        }
    }

    private func sectionHeader(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.month(.wide).day().year())
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
        store: store
    )
    event3.occurredAt = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    container.mainContext.insert(event3)

    return NavigationStack {
        ActivityView()
    }
    .modelContainer(container)
}
