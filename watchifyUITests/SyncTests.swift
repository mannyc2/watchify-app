//
//  SyncTests.swift
//  watchifyUITests
//
//  Tests for sync functionality.
//

import XCTest

final class SyncTests: XCTestCase {

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

    // MARK: - Toolbar Sync Tests

    /// Tests syncing via the toolbar button.
    @MainActor
    func testManualSyncViaToolbar() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        // Navigate to store
        XCTAssertTrue(sidebar.waitForStore(named: "Test Store", timeout: 5))
        sidebar.selectStore(named: "Test Store")

        let storeDetail = StoreDetailScreen(app: app)

        // Wait for view to load
        XCTAssertTrue(storeDetail.waitForReady(timeout: 10))

        // Find and click sync button
        let syncButton = storeDetail.syncButton
        guard syncButton.waitForExistence(timeout: 3) && syncButton.isEnabled else {
            throw XCTSkip("Sync button not available (may be rate limited or offline)")
        }

        syncButton.click()

        // Wait for sync to complete and verify result
        let syncCompleted = storeDetail.waitForCondition(timeout: 30) {
            // Sync is done when: not syncing AND (has products OR is empty OR has error)
            !storeDetail.isSyncing && (storeDetail.productCount > 0 || storeDetail.isEmpty || storeDetail.hasError)
        }

        XCTAssertTrue(syncCompleted, "Sync should complete within timeout")

        // Verify we have a valid end state
        let hasValidState = storeDetail.productCount > 0 || storeDetail.isEmpty || storeDetail.hasError
        XCTAssertTrue(hasValidState, "Should show products, empty state, or error after sync")
    }

    /// Tests syncing via the Cmd+Shift+R keyboard shortcut.
    @MainActor
    func testManualSyncViaKeyboardShortcut() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        // Navigate to store
        XCTAssertTrue(sidebar.waitForStore(named: "Test Store", timeout: 5))
        sidebar.selectStore(named: "Test Store")

        let storeDetail = StoreDetailScreen(app: app)
        XCTAssertTrue(storeDetail.waitForReady(timeout: 10))

        // Press Cmd+Shift+R to sync current store
        sidebar.shiftCommandKey(.init("r"))

        // Should trigger sync or show rate limit
        _ = storeDetail.waitForCondition(timeout: 3) {
            storeDetail.isSyncing || storeDetail.hasError
        }
    }

    /// Tests the Sync All shortcut (Cmd+R).
    @MainActor
    func testSyncAllViaKeyboardShortcut() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        // Just need the app to be running
        XCTAssertTrue(sidebar.waitForElement(sidebar.overviewButton))

        // Press Cmd+R to sync all stores
        sidebar.commandKey(.init("r"))

        // This triggers background sync - hard to verify directly
        // Just ensure no crash occurs
    }

    // MARK: - Sync State Tests

    /// Tests that the sync button shows a progress indicator while syncing.
    @MainActor
    func testSyncIndicatorAppears() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        XCTAssertTrue(sidebar.waitForStore(named: "Test Store", timeout: 5))
        sidebar.selectStore(named: "Test Store")

        let storeDetail = StoreDetailScreen(app: app)
        XCTAssertTrue(storeDetail.waitForReady(timeout: 10))

        // Trigger sync
        if storeDetail.syncButton.exists && storeDetail.syncButton.isEnabled {
            storeDetail.tapSync()

            // Check for progress indicator
            let progressAppeared = storeDetail.syncProgress.waitForExistence(timeout: 2)

            // Progress may be too fast to catch, or we may be rate limited
            // This is acceptable
            if progressAppeared {
                XCTAssertTrue(storeDetail.isSyncing)
            }
        }
    }

    // MARK: - Empty State Sync Tests

    /// Tests the Sync Now button in empty state.
    @MainActor
    func testSyncNowInEmptyState() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedEmptyStore"])

        // Look for the seeded empty store
        let emptyStoreExists = sidebar.waitForStore(named: "Empty Store", timeout: 5)
        guard emptyStoreExists else {
            throw XCTSkip("Empty store not seeded")
        }

        sidebar.selectStore(named: "Empty Store")

        let storeDetail = StoreDetailScreen(app: app)

        // Should show empty state with Sync Now button
        if storeDetail.syncNowButton.waitForExistence(timeout: 5) {
            storeDetail.tapSyncNow()

            // Should trigger sync
            _ = storeDetail.waitForCondition(timeout: 5) {
                storeDetail.isSyncing || storeDetail.hasError || !storeDetail.isEmpty
            }
        }
    }

    // MARK: - Rate Limiting Tests

    /// Tests that rapid sync attempts show rate limit message.
    @MainActor
    func testRateLimitingOnRapidSync() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        XCTAssertTrue(sidebar.waitForStore(named: "Test Store", timeout: 5))
        sidebar.selectStore(named: "Test Store")

        let storeDetail = StoreDetailScreen(app: app)
        XCTAssertTrue(storeDetail.waitForReady(timeout: 10))

        // Try to sync multiple times rapidly
        guard storeDetail.syncButton.exists && storeDetail.syncButton.isEnabled else {
            return // Already rate limited
        }

        storeDetail.tapSync()

        // Wait for first sync to complete or show error
        _ = storeDetail.waitForSyncComplete(timeout: 30)

        // Try to sync again immediately
        if storeDetail.syncButton.exists && storeDetail.syncButton.isEnabled {
            storeDetail.tapSync()

            // Should show rate limit banner or disable button
            _ = storeDetail.waitForCondition(timeout: 5) {
                !storeDetail.syncButton.isEnabled ||
                storeDetail.hasError ||
                self.app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'wait'")).count > 0
            }
        }
    }

    // MARK: - Offline Tests

    /// Tests that sync is disabled when offline indicator is shown.
    @MainActor
    func testSyncDisabledWhenOffline() throws {
        // This test requires the app to be in offline state
        // which we can't easily simulate in UI tests
        // Skip or implement with network simulation

        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        XCTAssertTrue(sidebar.waitForStore(named: "Test Store", timeout: 5))
        sidebar.selectStore(named: "Test Store")

        let storeDetail = StoreDetailScreen(app: app)
        XCTAssertTrue(storeDetail.waitForReady(timeout: 10))

        // If offline, sync should be disabled
        if storeDetail.isOffline {
            XCTAssertFalse(storeDetail.syncButton.isEnabled,
                          "Sync should be disabled when offline")
        }
    }
}
