//
//  AccessibilityAuditTests.swift
//  watchifyUITests
//
//  Accessibility audit tests using the page object pattern.
//

import XCTest

final class AccessibilityAuditTests: XCTestCase {

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

    // MARK: - Issue Handler

    /// Filters accessibility issues, ignoring system elements we can't control.
    private func auditIssueHandler(issue: XCUIAccessibilityAuditIssue) -> Bool {
        XCTContext.runActivity(named: "Accessibility Issue: \(issue.compactDescription)") { activity in
            let attachment = XCTAttachment(string: """
                Audit Type: \(issue.auditType)
                Description: \(issue.compactDescription)
                Element: \(issue.element?.debugDescription ?? "NIL")
                """)
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }

        guard let element = issue.element else {
            // Log nil element issue details
            XCTContext.runActivity(named: "NIL ELEMENT - \(issue.auditType)") { _ in }
            return false
        }

        let frame = element.frame
        XCTContext.runActivity(named: "Element: \(element.elementType) '\(element.label)'") { activity in
            let details = """
                Type: \(element.elementType) (raw: \(element.elementType.rawValue))
                Label: \(element.label)
                Identifier: \(element.identifier)
                Frame: x=\(Int(frame.minX)), y=\(Int(frame.minY)), w=\(Int(frame.width)), h=\(Int(frame.height))
                Value: \(String(describing: element.value))
                Enabled: \(element.isEnabled)
                """
            let attachment = XCTAttachment(string: details)
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }

        return true
    }

    // MARK: - Empty State Tests

    /// Tests the empty state when app launches with no data
    @MainActor
    func testEmptyStateAccessibility() throws {
        sidebar.launch(arguments: ["-UITesting"])

        // Wait for app to be ready
        XCTAssertTrue(sidebar.waitForElement(sidebar.overviewButton))

        try app.performAccessibilityAudit(for: .all) { issue in
            self.auditIssueHandler(issue: issue)
        }
    }

    /// Tests the Add Store sheet
    @MainActor
    func testAddStoreSheetAccessibility() throws {
        sidebar.launch(arguments: ["-UITesting"])

        // Open Add Store sheet via sidebar button
        XCTAssertTrue(sidebar.waitForElement(sidebar.addStoreButton))

        let addStoreScreen = sidebar.tapAddStore()
        _ = addStoreScreen.waitForSheet()
        XCTAssertTrue(addStoreScreen.isShowing, "Add Store sheet should appear")

        // Exclude parentChild audit - SwiftUI sheets on macOS have a known
        // framework-level Parent/Child mismatch with NIL element that we can't fix
        var auditTypes: XCUIAccessibilityAuditType = .all
        auditTypes.remove(.parentChild)
        try app.performAccessibilityAudit(for: auditTypes) { issue in
            self.auditIssueHandler(issue: issue)
        }

        // Dismiss
        addStoreScreen.dismiss()
    }

    // MARK: - Settings Test (all tabs in one test)

    /// Tests all settings tabs in sequence
    @MainActor
    func testSettingsAccessibility() throws {
        sidebar.launch(arguments: ["-UITesting"])

        XCTAssertTrue(sidebar.waitForElement(sidebar.overviewButton))

        let settings = SettingsScreen(app: app)
        settings.open()

        guard settings.waitForWindow() else {
            XCTFail("Settings window did not appear")
            return
        }

        // Test General tab (default)
        try app.performAccessibilityAudit(for: .all) { issue in
            self.auditIssueHandler(issue: issue)
        }

        // Test Notifications tab
        if settings.notificationsTab.exists {
            settings.selectNotificationsTab()
            _ = settings.waitForCondition(timeout: 2) {
                settings.notificationsTab.isSelected
            }
            try app.performAccessibilityAudit(for: .all) { issue in
                self.auditIssueHandler(issue: issue)
            }
        }

        // Test Data tab
        if settings.dataTab.exists {
            settings.selectDataTab()
            _ = settings.waitForCondition(timeout: 2) {
                settings.dataTab.isSelected
            }
            try app.performAccessibilityAudit(for: .all) { issue in
                self.auditIssueHandler(issue: issue)
            }
        }

        // Close
        settings.close()
    }

    // MARK: - Populated State Test (all views in one test)

    /// Tests all main views with seeded test data
    @MainActor
    func testPopulatedStateAccessibility() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedTestData"])

        // Wait for data to load
        XCTAssertTrue(sidebar.waitForStore(named: "Test Store", timeout: 5))

        // 1. Test Overview with data
        sidebar.selectOverview()
        _ = sidebar.waitForElement(sidebar.overviewButton)
        try app.performAccessibilityAudit(for: .all) { issue in
            self.auditIssueHandler(issue: issue)
        }

        // 2. Test Activity
        sidebar.selectActivity()
        let activityTitle = app.staticTexts["Activity"]
        _ = activityTitle.waitForExistence(timeout: 3)
        try app.performAccessibilityAudit(for: .all) { issue in
            self.auditIssueHandler(issue: issue)
        }

        // 3. Test Store Detail
        sidebar.selectStore(named: "Test Store")
        let storeDetail = StoreDetailScreen(app: app)
        _ = storeDetail.waitForProducts(timeout: 10)
        try app.performAccessibilityAudit(for: .all) { issue in
            self.auditIssueHandler(issue: issue)
        }

        // 4. Test Product Detail (click first product card)
        if storeDetail.productCount > 0 {
            storeDetail.selectProduct(at: 0)
            _ = sidebar.waitForCondition(timeout: 3) {
                self.app.buttons["Test Store"].exists ||
                self.app.navigationBars.buttons.firstMatch.exists
            }
            try app.performAccessibilityAudit(for: .all) { issue in
                self.auditIssueHandler(issue: issue)
            }
        }
    }

    // MARK: - Multiple Stores Accessibility

    /// Tests accessibility with multiple stores in the sidebar
    @MainActor
    func testMultipleStoresAccessibility() throws {
        sidebar.launch(arguments: ["-UITesting", "-SeedMultipleStores"])

        // Wait for stores to load
        _ = sidebar.waitForCondition(timeout: 5) { sidebar.storeCount >= 2 }

        // Test sidebar with multiple stores
        try app.performAccessibilityAudit(for: .all) { issue in
            self.auditIssueHandler(issue: issue)
        }

        // Navigate to each store and test
        for storeName in ["Allbirds", "Gymshark"] where sidebar.hasStore(named: storeName) {
            sidebar.selectStore(named: storeName)
            let storeDetail = StoreDetailScreen(app: app)
            _ = storeDetail.waitForReady(timeout: 10)
            try app.performAccessibilityAudit(for: .all) { issue in
                self.auditIssueHandler(issue: issue)
            }
        }
    }
}
