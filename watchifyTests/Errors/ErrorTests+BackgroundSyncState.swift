//
//  ErrorTests+BackgroundSyncState.swift
//  watchifyTests
//

import Foundation
import Testing
@testable import watchify

extension ErrorTests {

    @Suite("BackgroundSyncState")
    struct BackgroundSyncState {

        @Test("starts with no errors")
        @MainActor
        func startsEmpty() {
            let state = watchify.BackgroundSyncState.shared
            state.clearAllErrors()

            #expect(state.storeErrors.isEmpty)
            #expect(state.hasErrors == false)
            #expect(state.errorSummary == nil)
        }

        @Test("records error for store")
        @MainActor
        func recordsError() {
            let state = watchify.BackgroundSyncState.shared
            state.clearAllErrors()

            let storeId = UUID()
            state.recordError(.networkUnavailable, forStore: storeId)

            #expect(state.storeErrors.count == 1)
            #expect(state.hasErrors == true)
            if case .networkUnavailable = state.storeErrors[storeId] {
                // Success
            } else {
                Issue.record("Expected .networkUnavailable")
            }
        }

        @Test("records success clears error for store")
        @MainActor
        func recordSuccessClearsError() {
            let state = watchify.BackgroundSyncState.shared
            state.clearAllErrors()

            let storeId = UUID()
            state.recordError(.networkUnavailable, forStore: storeId)
            #expect(state.hasErrors == true)

            state.recordSuccess(forStore: storeId)
            #expect(state.hasErrors == false)
            #expect(state.storeErrors[storeId] == nil)
        }

        @Test("errorSummary shows singular for one store")
        @MainActor
        func errorSummarySingular() {
            let state = watchify.BackgroundSyncState.shared
            state.clearAllErrors()

            state.recordError(.networkTimeout, forStore: UUID())

            #expect(state.errorSummary == "1 store failed to sync")
        }

        @Test("errorSummary shows plural for multiple stores")
        @MainActor
        func errorSummaryPlural() {
            let state = watchify.BackgroundSyncState.shared
            state.clearAllErrors()

            state.recordError(.networkTimeout, forStore: UUID())
            state.recordError(.serverError(statusCode: 500), forStore: UUID())
            state.recordError(.invalidResponse, forStore: UUID())

            #expect(state.errorSummary == "3 stores failed to sync")
        }

        @Test("clearAllErrors removes all errors")
        @MainActor
        func clearAllErrorsWorks() {
            let state = watchify.BackgroundSyncState.shared

            state.recordError(.networkTimeout, forStore: UUID())
            state.recordError(.serverError(statusCode: 500), forStore: UUID())
            #expect(state.hasErrors == true)

            state.clearAllErrors()

            #expect(state.hasErrors == false)
            #expect(state.storeErrors.isEmpty)
            #expect(state.errorSummary == nil)
        }

        @Test("recording new error replaces existing error for same store")
        @MainActor
        func replacesExistingError() {
            let state = watchify.BackgroundSyncState.shared
            state.clearAllErrors()

            let storeId = UUID()
            state.recordError(.networkUnavailable, forStore: storeId)
            state.recordError(.serverError(statusCode: 503), forStore: storeId)

            #expect(state.storeErrors.count == 1)
            if case .serverError(let code) = state.storeErrors[storeId] {
                #expect(code == 503)
            } else {
                Issue.record("Expected .serverError(503)")
            }
        }
    }
}
