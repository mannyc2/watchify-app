//
//  NavigationTests.swift
//  watchifyUITests
//
//  Tests for navigation flows in the app.
//

import XCTest

final class NavigationTests: XCTestCase {

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

    // MARK: - Sidebar Navigation Tests

    /// Tests navigating between Overview and Activity in the sidebar.
    @MainActor
    func testSidebarNavigationBetweenOverviewAndActivity() throws {
        sidebar.launch(arguments: ["-UITesting"])

        // Should start on Overview
        XCTAssertTrue(sidebar.overviewButton.waitForExistence(timeout: 5))

        // Navigate to Activity
        sidebar.selectActivity()

        // Verify Activity is selected (check for Activity-specific content)
        let activityTitle = app.staticTexts["Activity"]
        XCTAssertTrue(activityTitle.waitForExistence(timeout: 3))

        // Navigate back to Overview
        sidebar.selectOverview()

        // Verify Overview content appears
        let overviewTitle = app.staticTexts["Overview"]
        XCTAssertTrue(overviewTitle.waitForExistence(timeout: 3))
    }

    /// Tests navigating between multiple stores in the sidebar.
    @MainActor
    func testSidebarNavigationBetweenStores() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedMultipleStores"])

        // Wait for stores to load
        XCTAssertTrue(sidebar.waitForStore(named: "Allbirds", timeout: 5))

        // Select first store
        sidebar.selectStore(named: "Allbirds")

        // Verify store detail appears
        let allbirdsNav = app.navigationBars["Allbirds"]
        XCTAssertTrue(allbirdsNav.waitForExistence(timeout: 3) || app.staticTexts["Allbirds"].exists)

        // Select second store
        if sidebar.hasStore(named: "Gymshark") {
            sidebar.selectStore(named: "Gymshark")

            // Verify second store detail appears
            let gymsharkNav = app.navigationBars["Gymshark"]
            XCTAssertTrue(gymsharkNav.waitForExistence(timeout: 3) || app.staticTexts["Gymshark"].exists)
        }

        // Navigate back to first store
        sidebar.selectStore(named: "Allbirds")

        // Verify we're back on first store
        XCTAssertTrue(allbirdsNav.waitForExistence(timeout: 3) || app.staticTexts["Allbirds"].exists)
    }

    /// Tests keyboard shortcut navigation (Cmd+1-9).
    @MainActor
    func testKeyboardShortcutNavigation() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        // Wait for app to load
        XCTAssertTrue(sidebar.waitForElement(sidebar.overviewButton))

        // Cmd+1 should go to Overview
        sidebar.commandKey(.init("1"))
        let overviewContent = app.staticTexts["Overview"]
        XCTAssertTrue(overviewContent.waitForExistence(timeout: 3))

        // Cmd+2 should go to Activity
        sidebar.commandKey(.init("2"))
        let activityContent = app.staticTexts["Activity"]
        XCTAssertTrue(activityContent.waitForExistence(timeout: 3))

        // Cmd+3 should go to first store (if exists)
        sidebar.commandKey(.init("3"))

        // If there's a store, we should now see store detail
        // This depends on having seeded data with at least one store
    }

    /// Tests that Overview shows store cards that can be clicked to navigate.
    @MainActor
    func testOverviewToStoreNavigation() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        // Make sure we're on Overview
        sidebar.selectOverview()

        // Wait for overview content to load
        XCTAssertTrue(sidebar.waitForElement(sidebar.overviewButton))

        // Look for a store card in the overview
        // Store cards use NavigationLink, so clicking should navigate
        let storeCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Test Store'")).firstMatch
        if storeCard.waitForExistence(timeout: 3) {
            storeCard.click()

            // Should navigate to store detail
            let storeNav = app.navigationBars["Test Store"]
            XCTAssertTrue(storeNav.waitForExistence(timeout: 3) || app.staticTexts["Test Store"].exists)
        }
    }

    /// Tests Activity row navigation to associated store.
    @MainActor
    func testActivityRowNavigation() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        // Navigate to Activity
        sidebar.selectActivity()

        // Wait for activity content
        let activityTitle = app.staticTexts["Activity"]
        XCTAssertTrue(activityTitle.waitForExistence(timeout: 3))

        // Find an event row and click it
        // Events should navigate to their associated store
        let eventRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'price'")).firstMatch
        if eventRow.waitForExistence(timeout: 3) {
            eventRow.click()

            // Should navigate to the store
            // The seeded event is for "Test Store"
            _ = sidebar.waitForCondition(timeout: 3) {
                self.app.navigationBars["Test Store"].exists ||
                self.app.staticTexts["Test Store"].exists
            }
        }
    }

    // MARK: - Deep Navigation Tests

    /// Tests navigating to a product and back.
    @MainActor
    func testProductDetailNavigation() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        // Navigate to the test store
        sidebar.selectStore(named: "Test Store")

        let storeDetail = StoreDetailScreen(app: app)

        // Wait for products to load
        XCTAssertTrue(storeDetail.waitForProducts(timeout: 10))

        // Skip if no products
        guard storeDetail.productCount > 0 else { return }

        // Click a product card
        storeDetail.selectProduct(at: 0)

        // Should show product detail
        let backButton = app.buttons["Test Store"]
        if backButton.waitForExistence(timeout: 3) {
            // Navigate back
            backButton.click()

            // Should be back on store detail
            XCTAssertTrue(storeDetail.waitForProducts(timeout: 5))
        }
    }

    /// Tests that selection persists after switching away and back.
    @MainActor
    func testSelectionPersistence() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        // Select the store
        sidebar.selectStore(named: "Test Store")

        // Verify we're on the store
        let storeNav = app.navigationBars["Test Store"]
        _ = storeNav.waitForExistence(timeout: 3)

        // Switch to Activity
        sidebar.selectActivity()
        let activityTitle = app.staticTexts["Activity"]
        XCTAssertTrue(activityTitle.waitForExistence(timeout: 3))

        // Switch back to the store
        sidebar.selectStore(named: "Test Store")

        // Store should still be showing correctly
        XCTAssertTrue(storeNav.waitForExistence(timeout: 3) || app.staticTexts["Test Store"].exists)
    }
}
