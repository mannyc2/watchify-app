//
//  NotificationService.swift
//  watchify
//

import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("[NotificationService] Permission request failed: \(error)")
            return false
        }
    }

    /// Checks current authorization status without prompting
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Request permission only if not yet determined
    func requestPermissionIfNeeded() async -> Bool {
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
    func sendIfAuthorized(for changes: [ChangeEvent]) async {
        guard !changes.isEmpty else { return }
        let authorized = await requestPermissionIfNeeded()
        if authorized {
            await send(for: changes)
        }
    }

    func send(for changes: [ChangeEvent]) async {
        guard !changes.isEmpty else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            print("[NotificationService] Not authorized to send notifications")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Watchify"
        content.body = formatBody(for: changes)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
            print("[NotificationService] Notification sent for \(changes.count) changes")
        } catch {
            print("[NotificationService] Failed to send notification: \(error)")
        }
    }

    private func formatBody(for changes: [ChangeEvent]) -> String {
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

    private func countByType(_ changes: [ChangeEvent]) -> [ChangeType: Int] {
        var counts: [ChangeType: Int] = [:]
        for change in changes {
            counts[change.changeType, default: 0] += 1
        }
        return counts
    }
}
