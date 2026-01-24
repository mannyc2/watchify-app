//
//  DeleteStoreTests.swift
//  watchifyUITests
//
//  Tests for the delete store workflow.
//

import XCTest

final class DeleteStoreTests: XCTestCase {

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

    // MARK: - Context Menu Delete Tests

    /// Tests deleting a store via the context menu (right-click).
    @MainActor
    func testDeleteStoreViaContextMenu() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        // Wait for test store to appear
        XCTAssertTrue(sidebar.waitForStore(named: "Test Store", timeout: 5))

        // Verify store exists before delete
        XCTAssertTrue(sidebar.hasStore(named: "Test Store"))

        // Delete via context menu
        sidebar.deleteStore(named: "Test Store")

        // Wait for store to disappear
        XCTAssertTrue(sidebar.waitForStoreToDisappear(named: "Test Store", timeout: 5),
                     "Store should be removed after delete")
    }

    /// Tests that deleting the currently selected store clears the selection.
    @MainActor
    func testDeleteStoreUpdatesSelection() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        // Wait for and select the test store
        XCTAssertTrue(sidebar.waitForStore(named: "Test Store", timeout: 5))
        sidebar.selectStore(named: "Test Store")

        // Verify we're on the store detail
        let storeNav = app.navigationBars["Test Store"]
        _ = storeNav.waitForExistence(timeout: 3)

        // Delete the store
        sidebar.deleteStore(named: "Test Store")

        // Wait for store to disappear
        XCTAssertTrue(sidebar.waitForStoreToDisappear(named: "Test Store", timeout: 5))

        // Selection should be cleared - we should see empty state or Overview
        let noSelection = app.staticTexts["No Selection"]
        let storeNotFound = app.staticTexts["Store Not Found"]
        let overview = app.staticTexts["Overview"]

        _ = sidebar.waitForCondition(timeout: 3) {
            noSelection.exists || storeNotFound.exists || overview.exists
        }

        XCTAssertTrue(noSelection.exists || storeNotFound.exists || overview.exists,
                     "Should show empty state after deleting selected store")
    }

    // MARK: - Multiple Store Tests

    /// Tests that deleting one store doesn't affect other stores.
    @MainActor
    func testDeleteOneOfMultipleStores() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedMultipleStores"])

        // Wait for stores to load
        _ = sidebar.waitForCondition(timeout: 5) { sidebar.storeCount >= 2 }

        let initialCount = sidebar.storeCount
        guard initialCount >= 2 else {
            throw XCTSkip("Need at least 2 stores for this test")
        }

        let storeNames = sidebar.storeNames
        guard let firstStore = storeNames.first else {
            throw XCTSkip("No stores found")
        }

        // Delete the first store
        sidebar.deleteStore(named: firstStore)

        // Wait for delete
        XCTAssertTrue(sidebar.waitForStoreToDisappear(named: firstStore, timeout: 5))

        // Other stores should still exist
        XCTAssertEqual(sidebar.storeCount, initialCount - 1,
                      "Store count should decrease by 1")
    }

    /// Tests selecting another store after deleting one.
    @MainActor
    func testSelectAnotherStoreAfterDelete() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedMultipleStores"])

        // Wait for at least 2 stores
        _ = sidebar.waitForCondition(timeout: 5) { sidebar.storeCount >= 2 }

        let storeNames = sidebar.storeNames
        guard storeNames.count >= 2 else {
            throw XCTSkip("Need at least 2 stores for this test")
        }

        let storeToDelete = storeNames[0]
        let storeToSelect = storeNames[1]

        // Select first store
        sidebar.selectStore(named: storeToDelete)

        // Delete it
        sidebar.deleteStore(named: storeToDelete)
        XCTAssertTrue(sidebar.waitForStoreToDisappear(named: storeToDelete, timeout: 5))

        // Select remaining store
        sidebar.selectStore(named: storeToSelect)

        // Should successfully navigate to that store
        let storeNav = app.navigationBars[storeToSelect]
        let storeLabel = app.staticTexts[storeToSelect]
        XCTAssertTrue(storeNav.waitForExistence(timeout: 3) || storeLabel.exists,
                     "Should be able to select remaining store")
    }

    // MARK: - Edge Cases

    /// Tests deleting the last store.
    @MainActor
    func testDeleteLastStore() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        // Should have exactly 1 store from seed data
        XCTAssertTrue(sidebar.waitForStore(named: "Test Store", timeout: 5))
        XCTAssertEqual(sidebar.storeCount, 1)

        // Delete it
        sidebar.deleteStore(named: "Test Store")
        XCTAssertTrue(sidebar.waitForStoreToDisappear(named: "Test Store", timeout: 5))

        // Should have 0 stores
        XCTAssertEqual(sidebar.storeCount, 0, "Should have no stores after deleting last one")

        // Should show empty state - the overview should indicate no stores
        sidebar.selectOverview()
        _ = sidebar.waitForElement(sidebar.overviewButton)
    }
}
