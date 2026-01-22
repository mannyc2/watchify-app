//
//  MenuBarViewModel.swift
//  watchify
//

import Foundation

/// ViewModel for MenuBarView. Fetches events on background actor,
/// updates UI state on MainActor.
@MainActor @Observable
final class MenuBarViewModel {
    // MARK: - Published State

    private(set) var events: [ChangeEventDTO] = []
    private(set) var unreadCount: Int = 0
    private(set) var isLoading = false

    // MARK: - Private

    private let displayLimit = 10

    // MARK: - Computed Properties

    var hasUnreadEvents: Bool {
        unreadCount > 0
    }

    // MARK: - Public Methods

    /// Loads events and unread count for display.
    func loadEvents() async {
        isLoading = true
        defer { isLoading = false }

        let limit = displayLimit

        // CRITICAL: Use Task.detached for StoreService calls to avoid deadlock.
        // SwiftData's ModelActor uses performBlockAndWait which blocks if main
        // thread awaits while actor is mid-save.
        let (fetchedEvents, fetchedCount) = await Task.detached {
            async let eventsTask = StoreService.shared.fetchMenuBarEvents(limit: limit)
            async let countTask = StoreService.shared.fetchUnreadCount()
            return await (eventsTask, countTask)
        }.value

        events = fetchedEvents
        unreadCount = fetchedCount
    }

    /// Marks a single event as read (called when row appears).
    func markEventRead(id: UUID) {
        // Update local state immediately
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
            unreadCount = max(0, unreadCount - 1)
        }

        // Persist in background (detached to avoid deadlock)
        Task.detached {
            await StoreService.shared.markEventRead(id: id)
        }
    }

    /// Marks all unread events as read.
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
        unreadCount = 0

        // Persist in background (detached to avoid deadlock)
        Task.detached {
            await StoreService.shared.markAllUnreadEventsRead()
        }
    }
}
