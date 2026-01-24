//
//  SettingsScreen.swift
//  watchifyUITests
//
//  Page object for the Settings window.
//

import XCTest

/// Page object for Settings window interactions.
class SettingsScreen: AppScreen {

    // MARK: - Elements

    /// The Settings window (any window with settings toolbar buttons).
    var window: XCUIElement {
        app.windows.containing(.button, identifier: "General").firstMatch
    }

    /// General tab button.
    var generalTab: XCUIElement {
        app.buttons["General"]
    }

    /// Notifications tab button.
    var notificationsTab: XCUIElement {
        app.buttons["Notifications"]
    }

    /// Data tab button.
    var dataTab: XCUIElement {
        app.buttons["Data"]
    }

    /// Close button.
    var closeButton: XCUIElement {
        window.buttons[XCUIIdentifierCloseWindow]
    }

    // MARK: - General Tab Elements

    /// Sync interval picker.
    var syncIntervalPicker: XCUIElement {
        app.popUpButtons["Sync Interval"]
    }

    // MARK: - Notifications Tab Elements

    /// Price drop notification toggle.
    var priceDropToggle: XCUIElement {
        app.checkBoxes.matching(NSPredicate(format: "label CONTAINS 'price'")).firstMatch
    }

    /// Back in stock notification toggle.
    var backInStockToggle: XCUIElement {
        app.checkBoxes.matching(NSPredicate(format: "label CONTAINS 'stock'")).firstMatch
    }

    // MARK: - Data Tab Elements

    /// Clear cache button.
    var clearCacheButton: XCUIElement {
        app.buttons["Clear Image Cache"]
    }

    /// Delete all data button.
    var deleteAllDataButton: XCUIElement {
        app.buttons["Delete All Data"]
    }

    // MARK: - State

    /// Whether the Settings window is showing.
    var isShowing: Bool {
        // Check if any settings window exists
        let settingsWindow = app.windows.firstMatch
        return settingsWindow.exists && (
            generalTab.exists || notificationsTab.exists || dataTab.exists
        )
    }

    /// The currently selected tab.
    var currentTab: SettingsTab? {
        if generalTab.isSelected {
            return .general
        } else if notificationsTab.isSelected {
            return .notifications
        } else if dataTab.isSelected {
            return .data
        }
        return nil
    }

    // MARK: - Open/Close

    /// Opens Settings via the app menu.
    @discardableResult
    func open() -> Self {
        app.menuBars.menuBarItems["watchify"].click()
        let settingsMenuItem = app.menuBars.menuItems["Settings..."]
        // Try both variants of the settings menu item
        if waitForElement(settingsMenuItem, timeout: 2) {
            settingsMenuItem.click()
        } else {
            let altMenuItem = app.menuBars.menuItems["Settings\u{2026}"]
            if waitForElement(altMenuItem, timeout: 2) {
                altMenuItem.click()
            }
        }
        // Wait for settings to appear
        _ = waitForCondition(timeout: 5) { self.isShowing }
        return self
    }

    /// Opens Settings via keyboard shortcut (Cmd+,).
    @discardableResult
    func openViaKeyboard() -> Self {
        commandKey(.init(","))
        _ = waitForCondition(timeout: 5) { self.isShowing }
        return self
    }

    /// Closes the Settings window.
    @discardableResult
    func close() -> Self {
        if closeButton.exists {
            closeButton.click()
        }
        return self
    }

    /// Closes via Cmd+W.
    @discardableResult
    func closeViaKeyboard() -> Self {
        commandKey(.init("w"))
        return self
    }

    // MARK: - Tab Navigation

    /// Selects the General tab.
    @discardableResult
    func selectGeneralTab() -> Self {
        if waitForElement(generalTab) {
            generalTab.click()
        }
        return self
    }

    /// Selects the Notifications tab.
    @discardableResult
    func selectNotificationsTab() -> Self {
        if waitForElement(notificationsTab) {
            notificationsTab.click()
        }
        return self
    }

    /// Selects the Data tab.
    @discardableResult
    func selectDataTab() -> Self {
        if waitForElement(dataTab) {
            dataTab.click()
        }
        return self
    }

    /// Selects a tab by enum value.
    @discardableResult
    func selectTab(_ tab: SettingsTab) -> Self {
        switch tab {
        case .general:
            return selectGeneralTab()
        case .notifications:
            return selectNotificationsTab()
        case .data:
            return selectDataTab()
        }
    }

    // MARK: - Waits

    /// Waits for the Settings window to appear.
    func waitForWindow(timeout: TimeInterval = 5) -> Bool {
        waitForCondition(timeout: timeout) { self.isShowing }
    }

    /// Waits for the Settings window to close.
    func waitForClose(timeout: TimeInterval = 5) -> Bool {
        waitForCondition(timeout: timeout) { !self.isShowing }
    }
}

/// Settings tab identifiers.
enum SettingsTab {
    case general
    case notifications
    case data
}
