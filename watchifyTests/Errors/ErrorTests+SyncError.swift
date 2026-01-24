//
//  ErrorTests+SyncError.swift
//  watchifyTests
//

import Foundation
import Testing
@testable import watchify

extension ErrorTests {

    @Suite("SyncError")
    struct SyncError {

        // MARK: - Network Unavailable

        @Test("networkUnavailable has correct error description")
        func networkUnavailableErrorDescription() {
            let error = watchify.SyncError.networkUnavailable
            #expect(error.errorDescription == "No connection")
        }

        @Test("networkUnavailable has correct failure reason")
        func networkUnavailableFailureReason() {
            let error = watchify.SyncError.networkUnavailable
            #expect(error.failureReason == "Your device appears to be offline.")
        }

        @Test("networkUnavailable has correct recovery suggestion")
        func networkUnavailableRecoverySuggestion() {
            let error = watchify.SyncError.networkUnavailable
            #expect(error.recoverySuggestion == "Check your internet connection and try again.")
        }

        @Test("networkUnavailable has correct icon")
        func networkUnavailableIcon() {
            let error = watchify.SyncError.networkUnavailable
            #expect(error.iconName == "wifi.slash")
        }

        // MARK: - Network Timeout

        @Test("networkTimeout has correct error description")
        func networkTimeoutErrorDescription() {
            let error = watchify.SyncError.networkTimeout
            #expect(error.errorDescription == "Connection timed out")
        }

        @Test("networkTimeout has correct failure reason")
        func networkTimeoutFailureReason() {
            let error = watchify.SyncError.networkTimeout
            #expect(error.failureReason == "The request took too long to complete.")
        }

        @Test("networkTimeout has correct recovery suggestion")
        func networkTimeoutRecoverySuggestion() {
            let error = watchify.SyncError.networkTimeout
            #expect(error.recoverySuggestion == "Try again when your connection improves.")
        }

        @Test("networkTimeout has correct icon")
        func networkTimeoutIcon() {
            let error = watchify.SyncError.networkTimeout
            #expect(error.iconName == "clock.badge.exclamationmark")
        }

        // MARK: - Server Error

        @Test("serverError has correct error description")
        func serverErrorErrorDescription() {
            let error = watchify.SyncError.serverError(statusCode: 503)
            #expect(error.errorDescription == "Server error")
        }

        @Test("serverError has correct failure reason with status code")
        func serverErrorFailureReason() {
            let error = watchify.SyncError.serverError(statusCode: 503)
            #expect(error.failureReason == "The server returned an error (503).")
        }

        @Test("serverError has correct recovery suggestion")
        func serverErrorRecoverySuggestion() {
            let error = watchify.SyncError.serverError(statusCode: 500)
            #expect(error.recoverySuggestion == "The store may be temporarily unavailable. Try again later.")
        }

        @Test("serverError has correct icon")
        func serverErrorIcon() {
            let error = watchify.SyncError.serverError(statusCode: 502)
            #expect(error.iconName == "exclamationmark.icloud")
        }

        // MARK: - Invalid Response

        @Test("invalidResponse has correct error description")
        func invalidResponseErrorDescription() {
            let error = watchify.SyncError.invalidResponse
            #expect(error.errorDescription == "Invalid response")
        }

        @Test("invalidResponse has correct failure reason")
        func invalidResponseFailureReason() {
            let error = watchify.SyncError.invalidResponse
            #expect(error.failureReason == "The server returned unexpected data.")
        }

        @Test("invalidResponse has correct recovery suggestion")
        func invalidResponseRecoverySuggestion() {
            let error = watchify.SyncError.invalidResponse
            #expect(error.recoverySuggestion == "The store may have changed its product feed format.")
        }

        @Test("invalidResponse has correct icon")
        func invalidResponseIcon() {
            let error = watchify.SyncError.invalidResponse
            #expect(error.iconName == "exclamationmark.triangle")
        }

        // MARK: - Existing Cases Icons

        @Test("storeNotFound has correct icon")
        func storeNotFoundIcon() {
            let error = watchify.SyncError.storeNotFound
            #expect(error.iconName == "storefront.circle")
        }

        @Test("rateLimited has correct icon")
        func rateLimitedIcon() {
            let error = watchify.SyncError.rateLimited(retryAfter: 30)
            #expect(error.iconName == "clock")
        }

        // MARK: - Converter Tests

        @Test("converts URLError.notConnectedToInternet to networkUnavailable")
        func convertsNotConnectedToInternet() {
            let urlError = URLError(.notConnectedToInternet)
            let result = watchify.SyncError.from(urlError)

            if case .networkUnavailable = result {
                // Success
            } else {
                Issue.record("Expected .networkUnavailable, got \(result)")
            }
        }

        @Test("converts URLError.networkConnectionLost to networkUnavailable")
        func convertsNetworkConnectionLost() {
            let urlError = URLError(.networkConnectionLost)
            let result = watchify.SyncError.from(urlError)

            if case .networkUnavailable = result {
                // Success
            } else {
                Issue.record("Expected .networkUnavailable, got \(result)")
            }
        }

        @Test("converts URLError.timedOut to networkTimeout")
        func convertsTimedOut() {
            let urlError = URLError(.timedOut)
            let result = watchify.SyncError.from(urlError)

            if case .networkTimeout = result {
                // Success
            } else {
                Issue.record("Expected .networkTimeout, got \(result)")
            }
        }

        @Test("converts other URLError to invalidResponse")
        func convertsOtherURLError() {
            let urlError = URLError(.badServerResponse)
            let result = watchify.SyncError.from(urlError)

            if case .invalidResponse = result {
                // Success
            } else {
                Issue.record("Expected .invalidResponse, got \(result)")
            }
        }

        @Test("converts ShopifyAPIError.invalidResponse to invalidResponse")
        func convertsShopifyInvalidResponse() {
            let apiError = ShopifyAPIError.invalidResponse
            let result = watchify.SyncError.from(apiError)

            if case .invalidResponse = result {
                // Success
            } else {
                Issue.record("Expected .invalidResponse, got \(result)")
            }
        }

        @Test("converts ShopifyAPIError.httpError(5xx) to serverError")
        func convertsShopify5xxError() {
            let apiError = ShopifyAPIError.httpError(statusCode: 503)
            let result = watchify.SyncError.from(apiError)

            if case .serverError(let code) = result {
                #expect(code == 503)
            } else {
                Issue.record("Expected .serverError(503), got \(result)")
            }
        }

        @Test("converts ShopifyAPIError.httpError(4xx) to invalidResponse")
        func convertsShopify4xxError() {
            let apiError = ShopifyAPIError.httpError(statusCode: 404)
            let result = watchify.SyncError.from(apiError)

            if case .invalidResponse = result {
                // Success
            } else {
                Issue.record("Expected .invalidResponse, got \(result)")
            }
        }

        @Test("passes through existing SyncError unchanged")
        func passesThroughSyncError() {
            let original = watchify.SyncError.rateLimited(retryAfter: 45)
            let result = watchify.SyncError.from(original)

            if case .rateLimited(let retryAfter) = result {
                #expect(retryAfter == 45)
            } else {
                Issue.record("Expected .rateLimited(45), got \(result)")
            }
        }

        @Test("converts unknown error to invalidResponse")
        func convertsUnknownError() {
            let unknownError = NSError(domain: "test", code: 0)
            let result = watchify.SyncError.from(unknownError)

            if case .invalidResponse = result {
                // Success
            } else {
                Issue.record("Expected .invalidResponse, got \(result)")
            }
        }
    }
}
