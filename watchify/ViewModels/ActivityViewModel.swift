//
//  ActivityViewModel.swift
//  watchify
//

import Foundation
import OSLog

/// Flattened list item for efficient single-ForEach rendering.
enum ActivityListItem: Identifiable {
    case header(date: Date, title: String)
    case event(ChangeEventDTO, showDivider: Bool)

    var id: String {
        switch self {
        case .header(let date, _):
            return "header-\(date.timeIntervalSince1970)"
        case .event(let event, _):
            return "event-\(event.id.uuidString)"
        }
    }
}

/// ViewModel for ActivityView. Runs on MainActor, communicates with
/// StoreService via Sendable DTOs for background data fetching.
@MainActor @Observable
final class ActivityViewModel {
    // MARK: - Published State

    private(set) var events: [ChangeEventDTO] = [] {
        didSet { rebuildListItems() }
    }
    private(set) var stores: [StoreDTO] = []
    private(set) var isLoading = false
    private(set) var hasMore = true

    /// Flattened list items for efficient single-ForEach rendering.
    private(set) var listItems: [ActivityListItem] = []

    /// ID of the last event, cached for infinite scroll check.
    private(set) var lastEventId: UUID?

    // MARK: - Filters

    var selectedStoreId: UUID? {
        didSet {
            if oldValue != selectedStoreId {
                Task { await fetchEvents(reset: true) }
            }
        }
    }

    var selectedType: TypeFilter = .all {
        didSet {
            if oldValue != selectedType {
                Task { await fetchEvents(reset: true) }
            }
        }
    }

    var dateRange: DateRange = .all {
        didSet {
            if oldValue != dateRange {
                Task { await fetchEvents(reset: true) }
            }
        }
    }

    // MARK: - Private

    private let pageSize = 50
    private var currentOffset = 0

    // MARK: - Public Methods

    /// Loads initial data: stores for picker and first page of events.
    func loadInitial() async {
        // CRITICAL: Use Task.detached for StoreService calls to avoid deadlock.
        // SwiftData's ModelActor uses performBlockAndWait which blocks if main
        // thread awaits while actor is mid-save.
        let fetchedStores = await Task.detached {
            await StoreService.shared.fetchStores()
        }.value

        stores = fetchedStores
        await fetchEventsInternal(reset: true)
    }

    /// Fetches events with current filters.
    func fetchEvents(reset: Bool) async {
        await fetchEventsInternal(reset: reset)
    }

    /// Marks a single event as read (called when row appears).
    func markEventRead(id: UUID) {
        // Update local state immediately for responsive UI
        if let index = events.firstIndex(where: { $0.id == id && !$0.isRead }) {
            let event = events[index]
            events[index] = ChangeEventDTO(
                id: event.id,
                occurredAt: event.occurredAt,
                changeType: event.changeType,
                productTitle: event.productTitle,
                variantTitle: event.variantTitle,
                oldValue: event.oldValue,
                newValue: event.newValue,
                priceChange: event.priceChange,
                isRead: true,
                magnitude: event.magnitude,
                storeId: event.storeId,
                storeName: event.storeName
            )
        }

        // Persist in background (detached to avoid deadlock)
        Task.detached {
            await StoreService.shared.markEventRead(id: id)
        }
    }

    /// Marks all visible events as read.
    func markAllRead() {
        // Update local state immediately
        events = events.map { event in
            guard !event.isRead else { return event }
            return ChangeEventDTO(
                id: event.id,
                occurredAt: event.occurredAt,
                changeType: event.changeType,
                productTitle: event.productTitle,
                variantTitle: event.variantTitle,
                oldValue: event.oldValue,
                newValue: event.newValue,
                priceChange: event.priceChange,
                isRead: true,
                magnitude: event.magnitude,
                storeId: event.storeId,
                storeName: event.storeName
            )
        }

        // Persist in background (detached to avoid deadlock)
        let storeId = selectedStoreId
        let changeTypes = selectedType.changeTypes
        let startDate = dateRange.startDate
        Task.detached {
            await StoreService.shared.markAllEventsRead(
                storeId: storeId,
                changeTypes: changeTypes,
                startDate: startDate
            )
        }
    }

    // MARK: - Computed Properties

    var hasUnreadEvents: Bool {
        events.contains { !$0.isRead }
    }

    var hasActiveFilters: Bool {
        selectedStoreId != nil || selectedType != .all || dateRange != .all
    }

    var subtitleText: String {
        var parts: [String] = []

        if let storeId = selectedStoreId,
           let store = stores.first(where: { $0.id == storeId }) {
            parts.append(store.name)
        }

        if dateRange != .all {
            parts.append(dateRange.rawValue)
        }

        if selectedType != .all {
            parts.append(selectedType.rawValue)
        }

        return parts.isEmpty ? "All events" : parts.joined(separator: " · ")
    }

    // MARK: - Private Methods

    /// Rebuilds the flattened list items. Called when `events` changes.
    private func rebuildListItems() {
        let start = CFAbsoluteTimeGetCurrent()
        lastEventId = events.last?.id

        let calendar = Calendar.current

        // Group by date
        let groupStart = CFAbsoluteTimeGetCurrent()
        let grouped = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.occurredAt)
        }
        let groupTime = CFAbsoluteTimeGetCurrent() - groupStart

        // Sort groups
        let sortStart = CFAbsoluteTimeGetCurrent()
        let sorted = grouped.sorted { $0.key > $1.key }
        let sortTime = CFAbsoluteTimeGetCurrent() - sortStart

        // Flatten into list items
        let flattenStart = CFAbsoluteTimeGetCurrent()
        var items: [ActivityListItem] = []
        items.reserveCapacity(events.count + sorted.count)
        for (date, groupEvents) in sorted {
            items.append(.header(date: date, title: sectionTitle(for: date, calendar: calendar)))
            for (index, event) in groupEvents.enumerated() {
                let isLast = index == groupEvents.count - 1
                items.append(.event(event, showDivider: !isLast))
            }
        }
        let flattenTime = CFAbsoluteTimeGetCurrent() - flattenStart

        listItems = items

        let totalTime = CFAbsoluteTimeGetCurrent() - start
        let eventCount = events.count
        let itemCount = items.count
        // swiftlint:disable:next line_length
        Log.ui.info("rebuildListItems: events=\(eventCount) items=\(itemCount) total=\(totalTime)s group=\(groupTime)s sort=\(sortTime)s flatten=\(flattenTime)s")
    }

    private func sectionTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.month(.wide).day().year())
        }
    }

    @discardableResult
    private func fetchEventsInternal(reset: Bool) async -> [ChangeEventDTO] {
        if reset {
            currentOffset = 0
        }

        isLoading = true
        defer { isLoading = false }

        // Capture filter state for background task
        let storeId = selectedStoreId
        let changeTypes = selectedType.changeTypes
        let startDate = dateRange.startDate
        let offset = currentOffset
        let limit = pageSize

        let fetchStart = CFAbsoluteTimeGetCurrent()

        // CRITICAL: Use Task.detached for StoreService calls to avoid deadlock.
        let fetched = await Task.detached {
            await StoreService.shared.fetchActivityEvents(
                storeId: storeId,
                changeTypes: changeTypes,
                startDate: startDate,
                offset: offset,
                limit: limit
            )
        }.value

        let fetchTime = CFAbsoluteTimeGetCurrent() - fetchStart

        if reset {
            events = fetched
        } else {
            events.append(contentsOf: fetched)
        }

        Log.db.debug("fetchEventsInternal: reset=\(reset) fetched=\(fetched.count) time=\(fetchTime)s")

        currentOffset += fetched.count
        hasMore = fetched.count == pageSize

        return fetched
    }
}

// MARK: - ChangeEventDTO Extension for Direct Initialization

extension ChangeEventDTO {
    init(
        id: UUID,
        occurredAt: Date,
        changeType: ChangeType,
        productTitle: String,
        variantTitle: String?,
        oldValue: String?,
        newValue: String?,
        priceChange: Decimal?,
        isRead: Bool,
        magnitude: ChangeMagnitude,
        storeId: UUID?,
        storeName: String?
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.changeType = changeType
        self.productTitle = productTitle
        self.variantTitle = variantTitle
        self.oldValue = oldValue
        self.newValue = newValue
        self.priceChange = priceChange
        self.isRead = isRead
        self.magnitude = magnitude
        self.storeId = storeId
        self.storeName = storeName
    }
}
