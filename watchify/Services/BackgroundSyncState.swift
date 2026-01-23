//
//  BackgroundSyncState.swift
//  watchify
//
//  Tracks background sync errors for surfacing in the UI.
//

import Foundation

@MainActor @Observable
final class BackgroundSyncState {
    static let shared = BackgroundSyncState()

    private(set) var storeErrors: [UUID: SyncError] = [:]

    var hasErrors: Bool {
        !storeErrors.isEmpty
    }

    var errorSummary: String? {
        guard hasErrors else { return nil }

        let count = storeErrors.count
        if count == 1 {
            return "1 store failed to sync"
        } else {
            return "\(count) stores failed to sync"
        }
    }

    private init() {}

    func recordError(_ error: SyncError, forStore storeId: UUID) {
        storeErrors[storeId] = error
    }

    func recordSuccess(forStore storeId: UUID) {
        storeErrors.removeValue(forKey: storeId)
    }

    func clearAllErrors() {
        storeErrors.removeAll()
    }
}
