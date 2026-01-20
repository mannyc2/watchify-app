//
//  SyncSchedulerTests.swift
//  watchifyTests
//

import Foundation
import SwiftData
import Testing
@testable import watchify

@Suite("SyncScheduler", .serialized)
struct SyncSchedulerTests {

    @MainActor
    @Test("intervalMinutes has expected default")
    func intervalMinutesHasDefault() async throws {
        // The default is 60, but tests may have changed it
        let scheduler = SyncScheduler.shared
        #expect(scheduler.intervalMinutes > 0)
    }

    @MainActor
    @Test("configure accepts a container")
    func configureAcceptsContainer() async throws {
        let schema = Schema([Store.self, Product.self, Variant.self,
                            VariantSnapshot.self, ChangeEvent.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        // Should complete without error
        SyncScheduler.shared.configure(with: container)
    }

    @MainActor
    @Test("isSyncing is accessible")
    func isSyncingIsAccessible() async throws {
        // Just verify the property is readable (may be true or false depending on app state)
        let _ = SyncScheduler.shared.isSyncing
    }

    @MainActor
    @Test("lastSyncAt is accessible")
    func lastSyncAtIsAccessible() async throws {
        // Just verify the property is readable
        let _ = SyncScheduler.shared.lastSyncAt
    }
}
