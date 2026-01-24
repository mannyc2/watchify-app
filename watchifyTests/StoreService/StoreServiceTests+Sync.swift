//
//  StoreServiceTests+Sync.swift
//  watchifyTests
//

import Foundation
import SwiftData
import Testing
@testable import watchify

extension StoreServiceTests {

    @Suite("Sync")
    struct Sync {

        // MARK: - Error Handling Tests

        @Test("Syncing handles API errors gracefully", .tags(.errorHandling))
        @MainActor
        func syncHandlesAPIErrors() async throws {
            let ctx = try await StoreServiceTestContext()

            let store = try await ctx.addStore(products: [.mock(id: 1)])

            // Clear rate limit and simulate API error on next sync
            ctx.clearRateLimit(for: store)
            await ctx.mockAPI.setShouldThrow(true)

            await #expect(throws: URLError.self) {
                _ = try await ctx.service.syncStore(storeId: store.id)
            }

            // Verify no partial changes were saved
            try expectEventCount(0, in: ctx.context)
        }

        @Test("Adding store handles API errors", .tags(.errorHandling))
        @MainActor
        func addStoreHandlesAPIErrors() async throws {
            let ctx = try await StoreServiceTestContext()

            await ctx.mockAPI.setShouldThrow(true, error: ShopifyAPIError.httpError(statusCode: 404))

            await #expect(throws: ShopifyAPIError.self) {
                _ = try await ctx.service.addStore(
                    name: "Invalid Store",
                    domain: "non-existent.myshopify.com"
                )
            }
        }

        // MARK: - Rate Limiting Tests

        @Test("Rate limiting prevents sync within 60 seconds", .tags(.rateLimiting, .errorHandling))
        @MainActor
        func rateLimitingPreventsSyncWithin60Seconds() async throws {
            let ctx = try await StoreServiceTestContext()

            // addStore sets lastFetchedAt to now
            let store = try await ctx.addStore(products: [.mock(id: 1)])

            // Immediate sync should be rate limited
            await #expect(throws: SyncError.self) {
                _ = try await ctx.service.syncStore(storeId: store.id)
            }
        }

        @Test("Rate limiting allows sync after 60 seconds", .tags(.rateLimiting))
        @MainActor
        func rateLimitingAllowsSyncAfter60Seconds() async throws {
            let ctx = try await StoreServiceTestContext()

            let store = try await ctx.addStore(products: [.mock(id: 1)])

            // Manually set lastFetchedAt to 61 seconds ago
            ctx.setLastFetchedAt(Date().addingTimeInterval(-61), for: store)

            // Sync should succeed
            let changes = try await ctx.service.syncStore(storeId: store.id)
            #expect(changes.isEmpty)  // No changes since products unchanged
        }

        @Test("Rate limit error includes retry time", .tags(.rateLimiting, .errorHandling))
        @MainActor
        func rateLimitErrorIncludesRetryTime() async throws {
            let ctx = try await StoreServiceTestContext()

            let store = try await ctx.addStore(products: [.mock(id: 1)])

            // Set lastFetchedAt to 30 seconds ago (should need to wait ~30 more seconds)
            ctx.setLastFetchedAt(Date().addingTimeInterval(-30), for: store)

            do {
                _ = try await ctx.service.syncStore(storeId: store.id)
                Issue.record("Expected SyncError.rateLimited to be thrown")
            } catch let error as SyncError {
                if case .rateLimited(let retryAfter) = error {
                    // Should be approximately 30 seconds (allowing some timing variance)
                    #expect(retryAfter > 25 && retryAfter <= 30)
                    #expect(error.failureReason?.contains("wait") == true)
                } else {
                    Issue.record("Expected SyncError.rateLimited, got \(error)")
                }
            }
        }

        @Test("SyncError.rateLimited has correct LocalizedError properties", .tags(.rateLimiting))
        @MainActor
        func rateLimitedErrorHasLocalizedProperties() async throws {
            let error = SyncError.rateLimited(retryAfter: 45)

            #expect(error.errorDescription == "Sync limited")
            #expect(error.failureReason == "Please wait 45 seconds before syncing again.")
            #expect(error.recoverySuggestion == "Try again after the countdown completes.")
        }

        @Test("SyncError.storeNotFound has correct LocalizedError properties", .tags(.errorHandling))
        @MainActor
        func storeNotFoundErrorHasLocalizedProperties() async throws {
            let error = SyncError.storeNotFound

            #expect(error.errorDescription == "Store not found")
            #expect(error.failureReason == "We couldn't find a store with that address.")
            #expect(error.recoverySuggestion == "Check the domain and try again.")
        }

        @Test("First sync after addStore is rate limited", .tags(.rateLimiting))
        @MainActor
        func firstSyncAfterAddStoreIsRateLimited() async throws {
            let ctx = try await StoreServiceTestContext()

            // This is the expected behavior: addStore sets lastFetchedAt,
            // so subsequent manual sync should wait
            let store = try await ctx.addStore(products: [.mock(id: 1)])
            #expect(store.lastFetchedAt != nil)

            do {
                _ = try await ctx.service.syncStore(storeId: store.id)
                Issue.record("Expected rate limit error")
            } catch let error as SyncError {
                if case .rateLimited(let retryAfter) = error {
                    // Should be close to 60 seconds
                    #expect(retryAfter > 55 && retryAfter <= 60)
                } else {
                    Issue.record("Expected SyncError.rateLimited")
                }
            }
        }
    }
}
