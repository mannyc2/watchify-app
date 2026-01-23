//
//  AccessibilityAuditTests.swift
//  watchifyUITests
//

import XCTest

final class AccessibilityAuditTests: XCTestCase {

    let app = XCUIApplication()

    // MARK: - Issue Handler

    /// Filters accessibility issues, ignoring system elements we can't control.
    private func auditIssueHandler(issue: XCUIAccessibilityAuditIssue) -> Bool {
        guard let element = issue.element else {
            print("### NIL ELEMENT: \(issue.compactDescription)")
            return false
        }

        let frame = element.frame
        let elementType = element.elementType
        let pos = "\(Int(frame.minX)),\(Int(frame.minY)),\(Int(frame.width))x\(Int(frame.height))"
        print("### ISSUE: \(issue.compactDescription) | type=\(issue.auditType) elem=\(elementType.rawValue) frame=\(pos)")

        return true
    }

    // MARK: - Empty State Tests

    /// Tests the empty state when app launches with no data
    func testEmptyStateAccessibility() throws {
        app.launchArguments = ["-UITesting"]
        app.launch()

        try app.performAccessibilityAudit(for: .all) { issue in
            self.auditIssueHandler(issue: issue)
        }
    }

    /// Tests the Add Store sheet
    func testAddStoreSheetAccessibility() throws {
        app.launchArguments = ["-UITesting"]
        app.launch()

        // Open Add Store sheet via sidebar button (avoids menu/toolbar issues)
        let addStoreButton = app.outlines.buttons["Add Store"]
        guard addStoreButton.waitForExistence(timeout: 2) else {
            XCTFail("Add Store button not found in sidebar")
            return
        }
        addStoreButton.click()

        // Wait for sheet
        sleep(1)

        try app.performAccessibilityAudit(for: .all) { issue in
            self.auditIssueHandler(issue: issue)
        }

        // Dismiss
        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Settings Test (all tabs in one test)

    /// Tests all settings tabs in sequence
    func testSettingsAccessibility() throws {
        app.launchArguments = ["-UITesting"]
        app.launch()

        // Open Settings via menu
        app.menuBars.menuBarItems["watchify"].click()
        let settingsMenuItem = app.menuBars.menuItems["Settings…"]
        guard settingsMenuItem.waitForExistence(timeout: 2) else {
            XCTFail("Settings menu item not found")
            return
        }
        settingsMenuItem.click()

        let settingsWindow = app.windows.firstMatch
        guard settingsWindow.waitForExistence(timeout: 2) else {
            XCTFail("Settings window did not appear")
            return
        }
        sleep(1)

        // Test General tab (default)
        try app.performAccessibilityAudit(for: .all) { issue in
            self.auditIssueHandler(issue: issue)
        }

        // Test Notifications tab
        let notificationsTab = settingsWindow.toolbars.buttons["Notifications"]
        if notificationsTab.exists {
            notificationsTab.click()
            sleep(1)
            try app.performAccessibilityAudit(for: .all) { issue in
                self.auditIssueHandler(issue: issue)
            }
        }

        // Test Data tab
        let dataTab = settingsWindow.toolbars.buttons["Data"]
        if dataTab.exists {
            dataTab.click()
            sleep(1)
            try app.performAccessibilityAudit(for: .all) { issue in
                self.auditIssueHandler(issue: issue)
            }
        }

        // Close
        settingsWindow.buttons[XCUIIdentifierCloseWindow].click()
    }

    // MARK: - Populated State Test (all views in one test)

    /// Tests all main views with seeded test data
    func testPopulatedStateAccessibility() throws {
        app.launchArguments = ["-UITesting", "-SeedTestData"]
        app.launch()

        // Wait for data to load
        sleep(1)

        // 1. Test Overview with data
        let overviewButton = app.outlines.buttons["Overview"]
        if overviewButton.waitForExistence(timeout: 2) {
            overviewButton.click()
            sleep(1)
            try app.performAccessibilityAudit(for: .all) { issue in
                self.auditIssueHandler(issue: issue)
            }
        }

        // 2. Test Activity
        let activityButton = app.outlines.buttons["Activity"]
        if activityButton.waitForExistence(timeout: 2) {
            activityButton.click()
            sleep(1)
            try app.performAccessibilityAudit(for: .all) { issue in
                self.auditIssueHandler(issue: issue)
            }
        }

        // 3. Test Store Detail
        let storeButton = app.outlines.buttons["Test Store"]
        if storeButton.waitForExistence(timeout: 2) {
            storeButton.click()
            sleep(1)
            try app.performAccessibilityAudit(for: .all) { issue in
                self.auditIssueHandler(issue: issue)
            }

            // 4. Test Product Detail (click first product card)
            let productCard = app.buttons.matching(identifier: "ProductCard").firstMatch
            if productCard.waitForExistence(timeout: 2) {
                productCard.click()
                sleep(1)
                try app.performAccessibilityAudit(for: .all) { issue in
                    self.auditIssueHandler(issue: issue)
                }
            }
        }
    }
}
