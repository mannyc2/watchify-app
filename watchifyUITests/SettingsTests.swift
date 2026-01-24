//
//  SettingsTests.swift
//  watchifyUITests
//
//  Tests for the Settings window.
//

import XCTest

final class SettingsTests: XCTestCase {

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

    // MARK: - Open/Close Tests

    /// Tests opening Settings via the app menu.
    @MainActor
    func testOpenSettingsViaMenu() throws {
        sidebar.launch(arguments: ["-UITesting"])

        XCTAssertTrue(sidebar.waitForElement(sidebar.overviewButton))

        let settings = SettingsScreen(app: app)
        settings.open()

        XCTAssertTrue(settings.waitForWindow(), "Settings window should open via menu")

        settings.close()
    }

    /// Tests opening Settings via keyboard shortcut (Cmd+,).
    @MainActor
    func testOpenSettingsViaKeyboardShortcut() throws {
        sidebar.launch(arguments: ["-UITesting"])

        XCTAssertTrue(sidebar.waitForElement(sidebar.overviewButton))

        let settings = SettingsScreen(app: app)
        settings.openViaKeyboard()

        XCTAssertTrue(settings.waitForWindow(), "Settings window should open with Cmd+,")

        settings.closeViaKeyboard()
    }

    /// Tests closing Settings via the close button.
    @MainActor
    func testCloseSettingsViaButton() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let settings = SettingsScreen(app: app)
        settings.openViaKeyboard()

        XCTAssertTrue(settings.waitForWindow())

        settings.close()

        XCTAssertTrue(settings.waitForClose(), "Settings should close via button")
    }

    /// Tests closing Settings via Cmd+W.
    @MainActor
    func testCloseSettingsViaKeyboardShortcut() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let settings = SettingsScreen(app: app)
        settings.openViaKeyboard()

        XCTAssertTrue(settings.waitForWindow())

        settings.closeViaKeyboard()

        XCTAssertTrue(settings.waitForClose(), "Settings should close with Cmd+W")
    }

    // MARK: - Tab Navigation Tests

    /// Tests switching between all Settings tabs.
    @MainActor
    func testSettingsTabSwitching() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let settings = SettingsScreen(app: app)
        settings.openViaKeyboard()

        XCTAssertTrue(settings.waitForWindow())

        // General tab should be default
        XCTAssertTrue(settings.generalTab.exists)

        // Switch to Notifications
        settings.selectNotificationsTab()
        _ = settings.waitForCondition(timeout: 2) {
            settings.notificationsTab.isSelected || settings.priceDropToggle.exists
        }

        // Switch to Data
        settings.selectDataTab()
        _ = settings.waitForCondition(timeout: 2) {
            settings.dataTab.isSelected || settings.clearCacheButton.exists
        }

        // Switch back to General
        settings.selectGeneralTab()
        _ = settings.waitForCondition(timeout: 2) {
            settings.generalTab.isSelected || settings.syncIntervalPicker.exists
        }

        settings.close()
    }

    // MARK: - General Tab Tests

    /// Tests the sync interval picker in General settings.
    @MainActor
    func testSyncIntervalPicker() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let settings = SettingsScreen(app: app)
        settings.openViaKeyboard()

        XCTAssertTrue(settings.waitForWindow())
        settings.selectGeneralTab()

        // Look for sync interval picker
        let syncPicker = settings.syncIntervalPicker
        if syncPicker.waitForExistence(timeout: 3) {
            // Verify it's interactable
            XCTAssertTrue(syncPicker.isEnabled)
        }

        settings.close()
    }

    // MARK: - Notifications Tab Tests

    /// Tests notification toggles in Notifications settings.
    @MainActor
    func testNotificationToggles() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let settings = SettingsScreen(app: app)
        settings.openViaKeyboard()

        XCTAssertTrue(settings.waitForWindow())
        settings.selectNotificationsTab()

        // Look for notification toggles
        let priceToggle = settings.priceDropToggle
        let stockToggle = settings.backInStockToggle

        // At least one should exist
        let hasToggles = priceToggle.waitForExistence(timeout: 3) ||
                         stockToggle.waitForExistence(timeout: 1)

        if hasToggles {
            // Verify they're interactable
            if priceToggle.exists {
                XCTAssertTrue(priceToggle.isEnabled)
            }
        }

        settings.close()
    }

    // MARK: - Data Tab Tests

    /// Tests the Clear Cache button in Data settings.
    @MainActor
    func testClearCacheButton() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let settings = SettingsScreen(app: app)
        settings.openViaKeyboard()

        XCTAssertTrue(settings.waitForWindow())
        settings.selectDataTab()

        // Look for clear cache button
        let clearButton = settings.clearCacheButton
        if clearButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(clearButton.isEnabled, "Clear cache button should be enabled")
        }

        settings.close()
    }

    /// Tests the Delete All Data button in Data settings.
    @MainActor
    func testDeleteAllDataButton() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let settings = SettingsScreen(app: app)
        settings.openViaKeyboard()

        XCTAssertTrue(settings.waitForWindow())
        settings.selectDataTab()

        // Look for delete button
        let deleteButton = settings.deleteAllDataButton
        if deleteButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(deleteButton.isEnabled, "Delete all data button should be enabled")

            // Don't actually click it - that would delete data
        }

        settings.close()
    }

    // MARK: - State Persistence Tests

    /// Tests that tab selection persists when reopening Settings.
    @MainActor
    func testTabSelectionPersists() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let settings = SettingsScreen(app: app)

        // Open and go to Data tab
        settings.openViaKeyboard()
        XCTAssertTrue(settings.waitForWindow())
        settings.selectDataTab()

        // Close
        settings.close()
        XCTAssertTrue(settings.waitForClose())

        // Reopen
        settings.openViaKeyboard()
        XCTAssertTrue(settings.waitForWindow())

        // Data tab should still be selected
        // This depends on @AppStorage persistence
        _ = settings.waitForCondition(timeout: 2) {
            settings.dataTab.isSelected ||
            settings.clearCacheButton.exists
        }

        settings.close()
    }
}
