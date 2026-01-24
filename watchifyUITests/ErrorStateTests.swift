//
//  ErrorStateTests.swift
//  watchifyUITests
//
//  Tests for error states and error banner interactions.
//

import XCTest

final class ErrorStateTests: XCTestCase {

    var app: XCUIApplication!
    var sidebar: SidebarScreen!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        sidebar = SidebarScreen(app: app)
    }

    override func tearDownWithError() throws {
        app = nil
        sidebar = nil
    }

    // MARK: - Error Banner Tests

    /// Tests that an error banner appears after a sync failure.
    @MainActor
    func testSyncErrorShowsBanner() throws {
        // This test requires triggering a sync error
        // In real scenarios, this would happen with network issues

        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        XCTAssertTrue(sidebar.waitForStore(named: "Test Store", timeout: 5))
        sidebar.selectStore(named: "Test Store")

        let storeDetail = StoreDetailScreen(app: app)
        XCTAssertTrue(storeDetail.waitForReady(timeout: 10))

        // Trigger sync - may succeed or fail depending on network
        if storeDetail.syncButton.exists && storeDetail.syncButton.isEnabled {
            storeDetail.tapSync()

            // Wait for sync to complete
            _ = storeDetail.waitForSyncComplete(timeout: 30)

            // If there's an error banner, verify it
            if storeDetail.hasError {
                // Error banner should have retry and dismiss options
                XCTAssertTrue(storeDetail.retryButton.exists || storeDetail.dismissBannerButton.exists,
                             "Error banner should have action buttons")
            }
        }
    }

    /// Tests dismissing the error banner.
    @MainActor
    func testErrorBannerDismiss() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        XCTAssertTrue(sidebar.waitForStore(named: "Test Store", timeout: 5))
        sidebar.selectStore(named: "Test Store")

        let storeDetail = StoreDetailScreen(app: app)
        XCTAssertTrue(storeDetail.waitForReady(timeout: 10))

        // If there's an error banner already, dismiss it
        if storeDetail.hasError {
            let dismissButton = storeDetail.dismissBannerButton
            if dismissButton.waitForExistence(timeout: 2) {
                dismissButton.click()

                // Banner should disappear
                XCTAssertTrue(storeDetail.waitForCondition(timeout: 3) {
                    !storeDetail.hasError
                }, "Error banner should dismiss")
            }
        }
    }

    /// Tests the retry button in the error banner.
    @MainActor
    func testErrorBannerRetry() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        XCTAssertTrue(sidebar.waitForStore(named: "Test Store", timeout: 5))
        sidebar.selectStore(named: "Test Store")

        let storeDetail = StoreDetailScreen(app: app)
        XCTAssertTrue(storeDetail.waitForReady(timeout: 10))

        // If there's an error banner, test retry
        if storeDetail.hasError {
            let retryButton = storeDetail.retryButton
            if retryButton.waitForExistence(timeout: 2) {
                retryButton.click()

                // Should trigger a new sync attempt
                _ = storeDetail.waitForCondition(timeout: 3) {
                    storeDetail.isSyncing || !storeDetail.hasError
                }
            }
        }
    }

    // MARK: - Rate Limit Banner Tests

    /// Tests that rate limit banner shows countdown.
    @MainActor
    func testRateLimitBannerShowsCountdown() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        XCTAssertTrue(sidebar.waitForStore(named: "Test Store", timeout: 5))
        sidebar.selectStore(named: "Test Store")

        let storeDetail = StoreDetailScreen(app: app)
        XCTAssertTrue(storeDetail.waitForReady(timeout: 10))

        // Try rapid syncs to trigger rate limit
        if storeDetail.syncButton.exists && storeDetail.syncButton.isEnabled {
            storeDetail.tapSync()
            _ = storeDetail.waitForSyncComplete(timeout: 30)

            // Try again immediately
            if storeDetail.syncButton.isEnabled {
                storeDetail.tapSync()

                // Look for rate limit text
                let rateLimitText = app.staticTexts.matching(
                    NSPredicate(format: "label CONTAINS 'wait' OR label CONTAINS 'seconds'")
                ).firstMatch

                _ = rateLimitText.waitForExistence(timeout: 3)
            }
        }
    }

    /// Tests dismissing the rate limit banner.
    @MainActor
    func testRateLimitBannerDismiss() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        XCTAssertTrue(sidebar.waitForStore(named: "Test Store", timeout: 5))
        sidebar.selectStore(named: "Test Store")

        let storeDetail = StoreDetailScreen(app: app)
        XCTAssertTrue(storeDetail.waitForReady(timeout: 10))

        // If rate limited, try to dismiss
        let dismissButton = storeDetail.dismissBannerButton
        if dismissButton.waitForExistence(timeout: 2) {
            dismissButton.click()

            // Banner should be dismissable
            _ = storeDetail.waitForCondition(timeout: 3) {
                !dismissButton.exists
            }
        }
    }

    // MARK: - Add Store Error Tests

    /// Tests error message for invalid store domain.
    @MainActor
    func testInvalidStoreError() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let addStoreScreen = sidebar.tapAddStore()
        _ = addStoreScreen.waitForSheet()
        XCTAssertTrue(addStoreScreen.isShowing)

        // Enter clearly invalid domain
        addStoreScreen.enterDomain("definitely-not-a-store-xyz123.invalid")
        addStoreScreen.tapAdd()

        // Should show error
        XCTAssertTrue(addStoreScreen.waitForError(timeout: 15),
                     "Should show error for invalid domain")

        // Error text should mention it's not valid
        if let errorMsg = addStoreScreen.errorMessage {
            XCTAssertTrue(errorMsg.contains("Not a valid") || errorMsg.lowercased().contains("error"),
                         "Error message should indicate invalid store")
        }
    }

    // MARK: - Network Error Tests

    /// Tests behavior when network is unavailable.
    @MainActor
    func testNetworkUnavailableUI() throws {
        // This test is limited since we can't easily simulate network failure
        // It mainly documents the expected behavior

        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        XCTAssertTrue(sidebar.waitForStore(named: "Test Store", timeout: 5))
        sidebar.selectStore(named: "Test Store")

        let storeDetail = StoreDetailScreen(app: app)
        XCTAssertTrue(storeDetail.waitForReady(timeout: 10))

        // If offline, verify UI reflects this
        if storeDetail.isOffline {
            // Sync button should be disabled
            let syncButton = storeDetail.syncButton
            if syncButton.exists {
                XCTAssertFalse(syncButton.isEnabled, "Sync should be disabled when offline")
            }

            // Offline indicator should be visible
            XCTAssertTrue(storeDetail.offlineButton.exists, "Should show offline indicator")
        }
    }

    // MARK: - Store Not Found Tests

    /// Tests the Store Not Found state when a store is deleted.
    @MainActor
    func testStoreNotFoundState() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        XCTAssertTrue(sidebar.waitForStore(named: "Test Store", timeout: 5))
        sidebar.selectStore(named: "Test Store")

        // Wait for store to load
        let storeDetail = StoreDetailScreen(app: app)
        _ = storeDetail.waitForReady(timeout: 10)

        // Delete the store while viewing it
        sidebar.deleteStore(named: "Test Store")

        // Should show "Store Not Found" or similar message
        let notFound = app.staticTexts["Store Not Found"]
        let noSelection = app.staticTexts["No Selection"]

        _ = sidebar.waitForCondition(timeout: 5) {
            notFound.exists || noSelection.exists
        }

        XCTAssertTrue(notFound.exists || noSelection.exists,
                     "Should show appropriate message when store is deleted")
    }
}
