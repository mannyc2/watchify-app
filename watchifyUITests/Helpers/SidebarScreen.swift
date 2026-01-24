//
//  SidebarScreen.swift
//  watchifyUITests
//
//  Page object for sidebar navigation.
//

import XCTest

/// Page object for sidebar navigation interactions.
class SidebarScreen: AppScreen {

    // MARK: - Elements

    /// The sidebar outline/list container.
    var sidebarList: XCUIElement {
        app.outlines.firstMatch
    }

    /// Overview navigation item.
    var overviewButton: XCUIElement {
        app.staticTexts["SidebarItem-Overview"]
    }

    /// Activity navigation item.
    var activityButton: XCUIElement {
        app.staticTexts["SidebarItem-Activity"]
    }

    /// Add Store button at the bottom of the sidebar.
    var addStoreButton: XCUIElement {
        app.buttons["AddStoreButton"]
    }

    // MARK: - Navigation

    /// Selects the Overview item in the sidebar.
    @discardableResult
    func selectOverview() -> Self {
        if waitForElement(overviewButton) {
            overviewButton.click()
        }
        return self
    }

    /// Selects the Activity item in the sidebar.
    @discardableResult
    func selectActivity() -> Self {
        if waitForElement(activityButton) {
            activityButton.click()
        }
        return self
    }

    /// Selects a store by its name in the sidebar.
    /// - Parameter name: The store name to select
    @discardableResult
    func selectStore(named name: String) -> Self {
        let storeRow = app.staticTexts["StoreRow-\(name)"]
        if waitForElement(storeRow) {
            storeRow.click()
        }
        return self
    }

    /// Returns the element for a store by name.
    func storeButton(named name: String) -> XCUIElement {
        app.staticTexts["StoreRow-\(name)"]
    }

    /// Clicks the Add Store button to open the sheet.
    @discardableResult
    func tapAddStore() -> AddStoreScreen {
        if waitForElement(addStoreButton) {
            addStoreButton.click()
        }
        return AddStoreScreen(app: app)
    }

    // MARK: - Store Management

    /// Deletes a store by right-clicking and selecting Delete.
    /// - Parameter name: The store name to delete
    @discardableResult
    func deleteStore(named name: String) -> Self {
        let storeRow = app.staticTexts["StoreRow-\(name)"]
        if waitForElement(storeRow) {
            storeRow.rightClick()

            // Wait for context menu Delete (identifier: 'trash') - not Edit menu Delete
            let deleteMenuItem = app.menuItems["trash"]
            if deleteMenuItem.waitForExistence(timeout: 3) {
                deleteMenuItem.click()
            }
        }
        return self
    }

    // MARK: - Queries

    /// Returns the number of stores in the sidebar by counting StoreRow elements.
    var storeCount: Int {
        app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'StoreRow-'")
        ).count
    }

    /// Returns the names of all stores in the sidebar.
    var storeNames: [String] {
        let storeRows = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'StoreRow-'")
        ).allElementsBoundByIndex
        return storeRows.compactMap { row in
            // Extract name from identifier "StoreRow-<name>"
            let identifier = row.identifier
            guard identifier.hasPrefix("StoreRow-") else { return nil }
            return String(identifier.dropFirst("StoreRow-".count))
        }
    }

    /// Checks if a store exists in the sidebar.
    func hasStore(named name: String) -> Bool {
        app.staticTexts["StoreRow-\(name)"].exists
    }

    /// Waits for a store to appear in the sidebar.
    func waitForStore(named name: String, timeout: TimeInterval = 5) -> Bool {
        waitForElement(app.staticTexts["StoreRow-\(name)"], timeout: timeout)
    }

    /// Waits for a store to disappear from the sidebar.
    func waitForStoreToDisappear(named name: String, timeout: TimeInterval = 5) -> Bool {
        let storeRow = app.staticTexts["StoreRow-\(name)"]
        return waitForCondition(timeout: timeout) {
            !storeRow.exists
        }
    }
}
