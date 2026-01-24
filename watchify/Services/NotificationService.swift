//
//  NotificationService.swift
//  watchify
//

import Foundation
import os
import UserNotifications

@MainActor
protocol NotificationCenterProtocol {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func add(_ request: UNNotificationRequest) async throws
}

private struct LiveNotificationCenter: NotificationCenterProtocol {
    let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }
}

@MainActor
final class NotificationService {
    static let shared = NotificationService(center: LiveNotificationCenter())

    private let center: any NotificationCenterProtocol

    init(center: any NotificationCenterProtocol) {
        self.center = center
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            Log.sync.error("NotificationService permission request failed: \(error)")
            return false
        }
    }

    /// Checks current authorization status without prompting
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.authorizationStatus()
    }

    /// Request permission only if not yet determined
    private func requestPermissionIfNeeded() async -> Bool {
        let status = await authorizationStatus()
        switch status {
        case .notDetermined:
            return await requestPermission()
        case .authorized:
            return true
        default:
            return false
        }
    }

    /// Sends notification, requesting permission first if needed (contextual)
    func sendIfAuthorized(for changes: [ChangeEventDTO]) async {
        guard !changes.isEmpty else { return }
        let authorized = await requestPermissionIfNeeded()
        if authorized {
            await send(for: changes)
        }
    }

    func send(for changes: [ChangeEventDTO]) async {
        guard !changes.isEmpty else { return }

        // Check master toggle - default to true if not set
        if UserDefaults.standard.object(forKey: "notificationsEnabled") != nil,
           !UserDefaults.standard.bool(forKey: "notificationsEnabled") {
            return
        }

        let status = await center.authorizationStatus()
        guard status == .authorized else { return }

        // Group changes by store
        let groupedByStore = Dictionary(grouping: changes) { $0.storeId }

        for (_, storeChanges) in groupedByStore {
            // Filter by enabled change types and threshold
            let filteredChanges = storeChanges.filter {
                isChangeTypeEnabled($0.changeType) && meetsThreshold($0)
            }
            guard !filteredChanges.isEmpty else { continue }
            let content = UNMutableNotificationContent()

            if let storeName = filteredChanges.first?.storeName,
               let storeId = filteredChanges.first?.storeId {
                content.title = storeName
                content.threadIdentifier = storeId.uuidString
            }
            // If no store, leave title empty - system shows app name per HIG

            content.body = formatBody(for: filteredChanges)
            content.interruptionLevel = determinePriority(for: filteredChanges)
            content.sound = content.interruptionLevel == .passive ? nil : .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            do {
                try await center.add(request)
                Log.sync.info("NotificationService sent \(filteredChanges.count) changes (\(content.title))")
            } catch {
                Log.sync.error("NotificationService failed: \(error)")
            }
        }
    }

    private func formatBody(for changes: [ChangeEventDTO]) -> String {
        let counts = countByType(changes)
        var parts: [String] = []

        if let count = counts[.priceDropped], count > 0 {
            parts.append("\(count) price \(count == 1 ? "drop" : "drops")")
        }
        if let count = counts[.priceIncreased], count > 0 {
            parts.append("\(count) price \(count == 1 ? "increase" : "increases")")
        }
        if let count = counts[.backInStock], count > 0 {
            parts.append("\(count) back in stock")
        }
        if let count = counts[.outOfStock], count > 0 {
            parts.append("\(count) out of stock")
        }
        if let count = counts[.newProduct], count > 0 {
            parts.append("\(count) new \(count == 1 ? "product" : "products")")
        }
        if let count = counts[.productRemoved], count > 0 {
            parts.append("\(count) \(count == 1 ? "product" : "products") removed")
        }

        if parts.isEmpty {
            return "\(changes.count) \(changes.count == 1 ? "change" : "changes") detected"
        }

        return parts.joined(separator: ", ")
    }

    private func countByType(_ changes: [ChangeEventDTO]) -> [ChangeType: Int] {
        var counts: [ChangeType: Int] = [:]
        for change in changes {
            counts[change.changeType, default: 0] += 1
        }
        return counts
    }

    /// Returns priority level for a single change (2 = high, 1 = normal, 0 = low).
    private func priorityLevel(for change: ChangeEventDTO) -> Int {
        switch change.changeType {
        case .backInStock:
            return 2
        case .priceDropped:
            return change.magnitude == .large ? 2 : (change.magnitude == .medium ? 1 : 0)
        case .priceIncreased, .outOfStock, .newProduct, .productRemoved:
            return 1
        case .imagesChanged:
            return 0
        }
    }

    /// Determines the interruption level for a group of changes.
    /// Uses highest priority: timeSensitive > active > passive
    func determinePriority(for changes: [ChangeEventDTO]) -> UNNotificationInterruptionLevel {
        let maxPriority = changes.map { priorityLevel(for: $0) }.max() ?? 0
        switch maxPriority {
        case 2: return .timeSensitive
        case 1: return .active
        default: return .passive
        }
    }

    private func isChangeTypeEnabled(_ type: ChangeType) -> Bool {
        let key: String
        switch type {
        case .priceDropped: key = "notifyPriceDropped"
        case .priceIncreased: key = "notifyPriceIncreased"
        case .backInStock: key = "notifyBackInStock"
        case .outOfStock: key = "notifyOutOfStock"
        case .newProduct: key = "notifyNewProduct"
        case .productRemoved: key = "notifyProductRemoved"
        case .imagesChanged: key = "notifyImagesChanged"
        }
        // Default to true for all except imagesChanged (default false)
        if UserDefaults.standard.object(forKey: key) == nil {
            return type != .imagesChanged
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func meetsThreshold(_ change: ChangeEventDTO) -> Bool {
        // Non-price changes always pass
        guard change.changeType == .priceDropped || change.changeType == .priceIncreased else {
            return true
        }

        let thresholdKey = change.changeType == .priceDropped ? "priceDropThreshold" : "priceIncreaseThreshold"
        let thresholdRaw = UserDefaults.standard.string(forKey: thresholdKey) ?? PriceThreshold.any.rawValue

        guard let threshold = PriceThreshold(rawValue: thresholdRaw) else {
            return true
        }

        return threshold.isSatisfied(by: change)
    }
}
