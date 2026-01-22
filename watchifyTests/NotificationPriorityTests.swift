//
//  NotificationPriorityTests.swift
//  watchifyTests
//

import Foundation
import Testing
import UserNotifications
@testable import watchify

// MARK: - Test Suite

@Suite("Notification Priority")
struct NotificationPriorityTests {

    // MARK: - High Priority (timeSensitive)

    @Test("back in stock triggers timeSensitive priority")
    @MainActor
    func backInStockTriggersTimeSensitive() {
        let change = ChangeEventDTO(
            changeType: .backInStock,
            productTitle: "Test Product",
            variantTitle: "Default"
        )

        let priority = NotificationService.shared.determinePriority(for: [change])
        #expect(priority == .timeSensitive)
    }

    @Test("large price drop triggers timeSensitive priority")
    @MainActor
    func largePriceDropTriggersTimeSensitive() {
        let change = ChangeEventDTO(
            changeType: .priceDropped,
            productTitle: "Test Product",
            variantTitle: "Default",
            oldValue: "$100.00",
            newValue: "$70.00",
            priceChange: -30,
            magnitude: .large
        )

        let priority = NotificationService.shared.determinePriority(for: [change])
        #expect(priority == .timeSensitive)
    }

    // MARK: - Normal Priority (active)

    @Test("medium price drop triggers active priority")
    @MainActor
    func mediumPriceDropTriggersActive() {
        let change = ChangeEventDTO(
            changeType: .priceDropped,
            productTitle: "Test Product",
            variantTitle: "Default",
            oldValue: "$100.00",
            newValue: "$85.00",
            priceChange: -15,
            magnitude: .medium
        )

        let priority = NotificationService.shared.determinePriority(for: [change])
        #expect(priority == .active)
    }

    @Test("out of stock triggers active priority")
    @MainActor
    func outOfStockTriggersActive() {
        let change = ChangeEventDTO(
            changeType: .outOfStock,
            productTitle: "Test Product",
            variantTitle: "Default"
        )

        let priority = NotificationService.shared.determinePriority(for: [change])
        #expect(priority == .active)
    }

    @Test("new product triggers active priority")
    @MainActor
    func newProductTriggersActive() {
        let change = ChangeEventDTO(
            changeType: .newProduct,
            productTitle: "New Product"
        )

        let priority = NotificationService.shared.determinePriority(for: [change])
        #expect(priority == .active)
    }

    @Test("price increase triggers active priority")
    @MainActor
    func priceIncreaseTriggersActive() {
        let change = ChangeEventDTO(
            changeType: .priceIncreased,
            productTitle: "Test Product",
            variantTitle: "Default",
            magnitude: .medium
        )

        let priority = NotificationService.shared.determinePriority(for: [change])
        #expect(priority == .active)
    }

    @Test("product removed triggers active priority")
    @MainActor
    func productRemovedTriggersActive() {
        let change = ChangeEventDTO(
            changeType: .productRemoved,
            productTitle: "Removed Product"
        )

        let priority = NotificationService.shared.determinePriority(for: [change])
        #expect(priority == .active)
    }

    // MARK: - Low Priority (passive)

    @Test("small price drop triggers passive priority")
    @MainActor
    func smallPriceDropTriggersPassive() {
        let change = ChangeEventDTO(
            changeType: .priceDropped,
            productTitle: "Test Product",
            variantTitle: "Default",
            oldValue: "$100.00",
            newValue: "$95.00",
            priceChange: -5,
            magnitude: .small
        )

        let priority = NotificationService.shared.determinePriority(for: [change])
        #expect(priority == .passive)
    }

    @Test("image change triggers passive priority")
    @MainActor
    func imageChangeTriggersPassive() {
        let change = ChangeEventDTO(
            changeType: .imagesChanged,
            productTitle: "Test Product"
        )

        let priority = NotificationService.shared.determinePriority(for: [change])
        #expect(priority == .passive)
    }

    // MARK: - Mixed Priority

    @Test("mixed changes use highest priority")
    @MainActor
    func mixedChangesUseHighestPriority() {
        let smallPriceDrop = ChangeEventDTO(
            changeType: .priceDropped,
            productTitle: "Product 1",
            variantTitle: "Default",
            magnitude: .small
        )
        let backInStock = ChangeEventDTO(
            changeType: .backInStock,
            productTitle: "Product 2",
            variantTitle: "Default"
        )

        // Small price drop alone = passive
        let lowPriority = NotificationService.shared.determinePriority(for: [smallPriceDrop])
        #expect(lowPriority == .passive)

        // Mixed with back in stock = timeSensitive (highest wins)
        let highPriority = NotificationService.shared.determinePriority(
            for: [smallPriceDrop, backInStock]
        )
        #expect(highPriority == .timeSensitive)
    }

    @Test("normal and low priority changes use normal priority")
    @MainActor
    func normalAndLowPriorityUsesNormal() {
        let smallPriceDrop = ChangeEventDTO(
            changeType: .priceDropped,
            productTitle: "Product 1",
            magnitude: .small
        )
        let outOfStock = ChangeEventDTO(
            changeType: .outOfStock,
            productTitle: "Product 2",
            variantTitle: "Default"
        )

        let priority = NotificationService.shared.determinePriority(
            for: [smallPriceDrop, outOfStock]
        )
        #expect(priority == .active)
    }
}
