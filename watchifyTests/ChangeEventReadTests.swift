//
//  ChangeEventReadTests.swift
//  watchifyTests
//

import Foundation
import SwiftData
import Testing
@testable import watchify

@Suite("ChangeEvent Read/Unread")
struct ChangeEventReadTests {

    // MARK: - Default State

    @Test("new events are created with isRead = false")
    func newEventsAreUnread() {
        let event = ChangeEvent(
            changeType: .priceDropped,
            productTitle: "Test Product"
        )

        #expect(event.isRead == false)
    }

    @Test("events can be marked as read")
    func eventsCanBeMarkedRead() {
        let event = ChangeEvent(
            changeType: .priceDropped,
            productTitle: "Test Product"
        )

        #expect(event.isRead == false)
        event.isRead = true
        #expect(event.isRead == true)
    }

    // MARK: - Persistence

    @Test("isRead state persists in SwiftData")
    @MainActor
    func isReadStatePersists() throws {
        let schema = Schema([Store.self, Product.self, Variant.self, VariantSnapshot.self, ChangeEvent.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = container.mainContext

        // Create and insert event
        let event = ChangeEvent(
            changeType: .backInStock,
            productTitle: "Test Product"
        )
        context.insert(event)
        try context.save()

        // Verify initial state
        let descriptor = FetchDescriptor<ChangeEvent>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched.first?.isRead == false)

        // Mark as read and save
        fetched.first?.isRead = true
        try context.save()

        // Fetch again and verify
        let refetched = try context.fetch(descriptor)
        #expect(refetched.first?.isRead == true)
    }

    // MARK: - Unread Query

    @Test("unread predicate filters correctly")
    @MainActor
    func unreadPredicateFilters() throws {
        let schema = Schema([Store.self, Product.self, Variant.self, VariantSnapshot.self, ChangeEvent.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = container.mainContext

        // Create 3 events: 2 unread, 1 read
        let event1 = ChangeEvent(changeType: .priceDropped, productTitle: "Product 1")
        let event2 = ChangeEvent(changeType: .backInStock, productTitle: "Product 2")
        let event3 = ChangeEvent(changeType: .newProduct, productTitle: "Product 3")
        event3.isRead = true

        context.insert(event1)
        context.insert(event2)
        context.insert(event3)
        try context.save()

        // Query all events
        let allDescriptor = FetchDescriptor<ChangeEvent>()
        let allEvents = try context.fetch(allDescriptor)
        #expect(allEvents.count == 3)

        // Query unread events using the same predicate as SidebarView
        let unreadPredicate = #Predicate<ChangeEvent> { !$0.isRead }
        let unreadDescriptor = FetchDescriptor<ChangeEvent>(predicate: unreadPredicate)
        let unreadEvents = try context.fetch(unreadDescriptor)
        #expect(unreadEvents.count == 2)
    }

    @Test("marking all events read empties unread query")
    @MainActor
    func markingAllReadEmptiesQuery() throws {
        let schema = Schema([Store.self, Product.self, Variant.self, VariantSnapshot.self, ChangeEvent.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = container.mainContext

        // Create 3 unread events
        for index in 1...3 {
            let event = ChangeEvent(changeType: .priceDropped, productTitle: "Product \(index)")
            context.insert(event)
        }
        try context.save()

        // Verify 3 unread
        let unreadPredicate = #Predicate<ChangeEvent> { !$0.isRead }
        var unreadDescriptor = FetchDescriptor<ChangeEvent>(predicate: unreadPredicate)
        var unreadEvents = try context.fetch(unreadDescriptor)
        #expect(unreadEvents.count == 3)

        // Mark all as read
        let allDescriptor = FetchDescriptor<ChangeEvent>()
        let allEvents = try context.fetch(allDescriptor)
        for event in allEvents {
            event.isRead = true
        }
        try context.save()

        // Verify 0 unread
        unreadDescriptor = FetchDescriptor<ChangeEvent>(predicate: unreadPredicate)
        unreadEvents = try context.fetch(unreadDescriptor)
        #expect(unreadEvents.count == 0)
    }
}
