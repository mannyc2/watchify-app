//
//  TestAssertions.swift
//  watchifyTests
//

import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import watchify

// MARK: - Event Assertion Helpers

@MainActor
func fetchEvents(from context: ModelContext) throws -> [ChangeEvent] {
    let descriptor = FetchDescriptor<ChangeEvent>(
        sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
    )
    return try context.fetch(descriptor)
}

@MainActor
func expectEventCount(
    _ count: Int,
    in context: ModelContext,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let events = try fetchEvents(from: context)
    #expect(events.count == count, sourceLocation: sourceLocation)
}

@MainActor
func expectEvent(
    type: ChangeType,
    count: Int = 1,
    in context: ModelContext,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let events = try fetchEvents(from: context)
    let matching = events.filter { $0.changeType == type }
    #expect(matching.count == count, sourceLocation: sourceLocation)
}

// MARK: - Fake Notification Center

final class FakeNotificationCenter: NotificationCenterProtocol {
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var requestAuthorizationCalls = 0
    var requestAuthorizationResult = true
    var currentAuthorizationStatus: UNAuthorizationStatus = .authorized

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCalls += 1
        if requestAuthorizationResult {
            currentAuthorizationStatus = .authorized
        } else {
            currentAuthorizationStatus = .denied
        }
        return requestAuthorizationResult
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        currentAuthorizationStatus
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }
}

// MARK: - Notification Test Helpers

@MainActor
func withNotificationDefaults<T>(
    _ body: () async throws -> T
) async rethrows -> T {
    let keys = [
        "notificationsEnabled",
        "notifyPriceDropped",
        "notifyPriceIncreased",
        "notifyBackInStock",
        "notifyOutOfStock",
        "notifyNewProduct",
        "notifyProductRemoved",
        "notifyImagesChanged",
        "priceDropThreshold",
        "priceIncreaseThreshold"
    ]
    let stored = keys.map { UserDefaults.standard.object(forKey: $0) }
    defer {
        for (idx, key) in keys.enumerated() {
            if let value = stored[idx] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
    for key in keys {
        UserDefaults.standard.removeObject(forKey: key)
    }
    return try await body()
}
