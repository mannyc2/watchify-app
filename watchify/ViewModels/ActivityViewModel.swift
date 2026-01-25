//
//  ActivityViewModel.swift
//  watchify
//

import Foundation
import OSLog
import SwiftUI

// MARK: - Event Grouping Types

/// Display mode for grouped events in the activity feed.
enum EventGroupDisplayMode: String, CaseIterable, Sendable {
    case collapsible
    case summary
    case inline

    var displayName: String {
        switch self {
        case .collapsible: "Collapsible sections"
        case .summary: "Summary rows"
        case .inline: "Inline expansion"
        }
    }
}

/// Category for grouping related change types together.
enum ChangeCategory: Hashable, Sendable {
    case price
    case stock
    case product
    case images

    init(from type: ChangeType) {
        switch type {
        case .priceDropped, .priceIncreased:
            self = .price
        case .backInStock, .outOfStock:
            self = .stock
        case .newProduct, .productRemoved:
            self = .product
        case .imagesChanged:
            self = .images
        }
    }
}

/// Key for grouping events by product, store, and change category.
struct EventGroupKey: Hashable {
    let productShopifyId: Int64
    let storeId: UUID
    let changeCategory: ChangeCategory
}

/// A group of related events for the same product.
struct EventGroup: Identifiable, Sendable {
    let id: UUID
    let productTitle: String
    let productShopifyId: Int64?
    let productImageURL: String?
    let storeName: String?
    let dominantChangeType: ChangeType
    let events: [ChangeEventDTO]
    let latestDate: Date

    var variantCount: Int { events.count }

    var hasUnread: Bool { events.contains { !$0.isRead } }

    var summaryText: String {
        let count = variantCount
        switch dominantChangeType {
        case .priceDropped:
            return "\(count) variant\(count == 1 ? "" : "s") price dropped"
        case .priceIncreased:
            return "\(count) variant\(count == 1 ? "" : "s") price increased"
        case .backInStock:
            return "\(count) variant\(count == 1 ? "" : "s") back in stock"
        case .outOfStock:
            return "\(count) variant\(count == 1 ? "" : "s") out of stock"
        case .newProduct:
            return "\(count) new variant\(count == 1 ? "" : "s")"
        case .productRemoved:
            return "\(count) variant\(count == 1 ? "" : "s") removed"
        case .imagesChanged:
            return "\(count) image\(count == 1 ? "" : "s") changed"
        }
    }

    /// All event IDs in this group, for marking as read.
    var eventIds: [UUID] { events.map(\.id) }
}

/// Flattened list item for efficient single-ForEach rendering.
enum ActivityListItem: Identifiable {
    case header(date: Date, title: String)
    case event(ChangeEventDTO, showDivider: Bool)
    case group(EventGroup, showDivider: Bool)

    var id: String {
        switch self {
        case .header(let date, _):
            return "header-\(date.timeIntervalSince1970)"
        case .event(let event, _):
            return "event-\(event.id.uuidString)"
        case .group(let group, _):
            return "group-\(group.id.uuidString)"
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

    // MARK: - Grouping State

    /// IDs of groups that are currently expanded (for collapsible and inline modes).
    var expandedGroupIds: Set<UUID> = []

    /// Display mode for grouped events.
    @ObservationIgnored
    @AppStorage("activityGroupDisplayMode")
    var groupDisplayMode: EventGroupDisplayMode = .collapsible

    /// Time window in minutes for grouping events.
    @ObservationIgnored
    @AppStorage("activityGroupingWindowMinutes")
    var groupingWindowMinutes: Int = 5

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
                productShopifyId: event.productShopifyId,
                productImageURL: event.productImageURL,
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
                productShopifyId: event.productShopifyId,
                productImageURL: event.productImageURL,
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

    /// Marks all events in a group as read.
    func markGroupRead(group: EventGroup) {
        let eventIds = Set(group.eventIds)

        // Update local state immediately
        events = events.map { event in
            guard eventIds.contains(event.id) && !event.isRead else { return event }
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
                productShopifyId: event.productShopifyId,
                productImageURL: event.productImageURL,
                storeId: event.storeId,
                storeName: event.storeName
            )
        }

        // Persist in background
        Task.detached {
            for id in eventIds {
                await StoreService.shared.markEventRead(id: id)
            }
        }
    }

    /// Toggles expansion state for a group.
    func toggleGroupExpanded(_ groupId: UUID) {
        if expandedGroupIds.contains(groupId) {
            expandedGroupIds.remove(groupId)
        } else {
            expandedGroupIds.insert(groupId)
        }
    }

    /// Returns whether a group is currently expanded.
    func isGroupExpanded(_ groupId: UUID) -> Bool {
        expandedGroupIds.contains(groupId)
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

    /// Rebuilds the flattened list items with grouping. Called when `events` changes.
    private func rebuildListItems() {
        lastEventId = events.last?.id

        let calendar = Calendar.current
        let groupingWindow = TimeInterval(groupingWindowMinutes * 60)

        // Group by date
        let groupedByDate = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.occurredAt)
        }

        // Sort date groups
        let sortedDates = groupedByDate.sorted { $0.key > $1.key }

        // Flatten into list items
        var items: [ActivityListItem] = []
        items.reserveCapacity(events.count + sortedDates.count)

        for (date, dayEvents) in sortedDates {
            items.append(.header(date: date, title: sectionTitle(for: date, calendar: calendar)))

            // Group events within this day
            let groupedItems = groupEventsWithinDay(dayEvents, window: groupingWindow)

            for (index, item) in groupedItems.enumerated() {
                let isLast = index == groupedItems.count - 1
                switch item {
                case .single(let event):
                    items.append(.event(event, showDivider: !isLast))
                case .grouped(let group):
                    items.append(.group(group, showDivider: !isLast))
                }
            }
        }

        listItems = items
    }

    /// Groups events within a single day by product, store, and change category.
    private func groupEventsWithinDay(
        _ events: [ChangeEventDTO],
        window: TimeInterval
    ) -> [GroupedItem] {
        // Build grouping key -> events dictionary
        var keyedEvents: [EventGroupKey: [ChangeEventDTO]] = [:]
        var ungroupableEvents: [ChangeEventDTO] = []

        for event in events {
            // Must have productShopifyId and storeId to be groupable
            guard let productId = event.productShopifyId,
                  let storeId = event.storeId else {
                ungroupableEvents.append(event)
                continue
            }

            let key = EventGroupKey(
                productShopifyId: productId,
                storeId: storeId,
                changeCategory: ChangeCategory(from: event.changeType)
            )
            keyedEvents[key, default: []].append(event)
        }

        var result: [GroupedItem] = []

        // Process each key's events
        for (_, groupEvents) in keyedEvents {
            // Cluster by time window
            let clusters = clusterByTimeWindow(groupEvents, window: window)

            for cluster in clusters {
                if cluster.count >= 2 {
                    // Create a group
                    let group = createEventGroup(from: cluster)
                    result.append(.grouped(group))
                } else {
                    // Single event, no grouping
                    result.append(.single(cluster[0]))
                }
            }
        }

        // Add ungroupable events as singles
        for event in ungroupableEvents {
            result.append(.single(event))
        }

        // Sort by most recent first
        result.sort { item1, item2 in
            item1.latestDate > item2.latestDate
        }

        return result
    }

    /// Clusters events by time window.
    private func clusterByTimeWindow(
        _ events: [ChangeEventDTO],
        window: TimeInterval
    ) -> [[ChangeEventDTO]] {
        guard !events.isEmpty else { return [] }

        // Sort by time
        let sorted = events.sorted { $0.occurredAt > $1.occurredAt }

        var clusters: [[ChangeEventDTO]] = []
        var currentCluster: [ChangeEventDTO] = [sorted[0]]

        for event in sorted.dropFirst() {
            // Check if event is within window of the newest event in current cluster
            let clusterNewest = currentCluster[0].occurredAt
            if clusterNewest.timeIntervalSince(event.occurredAt) <= window {
                currentCluster.append(event)
            } else {
                clusters.append(currentCluster)
                currentCluster = [event]
            }
        }

        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }

        return clusters
    }

    /// Creates an EventGroup from a cluster of events.
    private func createEventGroup(from events: [ChangeEventDTO]) -> EventGroup {
        // Use the first event (most recent) for product info
        let firstEvent = events[0]

        // Find dominant change type (most frequent)
        let typeCounts = Dictionary(grouping: events, by: \.changeType)
        let dominantType = typeCounts.max { $0.value.count < $1.value.count }?.key ?? firstEvent.changeType

        return EventGroup(
            id: UUID(),
            productTitle: firstEvent.productTitle,
            productShopifyId: firstEvent.productShopifyId,
            productImageURL: firstEvent.productImageURL,
            storeName: firstEvent.storeName,
            dominantChangeType: dominantType,
            events: events,
            latestDate: firstEvent.occurredAt
        )
    }

    /// Helper enum for grouping results.
    private enum GroupedItem {
        case single(ChangeEventDTO)
        case grouped(EventGroup)

        var latestDate: Date {
            switch self {
            case .single(let event): event.occurredAt
            case .grouped(let group): group.latestDate
            }
        }
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

        if reset {
            events = fetched
        } else {
            events.append(contentsOf: fetched)
        }

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
        productShopifyId: Int64?,
        productImageURL: String?,
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
        self.productShopifyId = productShopifyId
        self.productImageURL = productImageURL
        self.storeId = storeId
        self.storeName = storeName
    }
}
