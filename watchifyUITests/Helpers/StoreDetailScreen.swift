//
//  StoreDetailScreen.swift
//  watchifyUITests
//
//  Page object for the store detail view.
//

import XCTest

/// Page object for the store detail view interactions.
class StoreDetailScreen: AppScreen {

    // MARK: - Elements

    /// Sync button in the toolbar.
    var syncButton: XCUIElement {
        // The sync button has different labels based on state
        app.buttons["Sync products from store"]
    }

    /// Sync button when syncing (progress indicator).
    var syncProgress: XCUIElement {
        app.progressIndicators.firstMatch
    }

    /// Offline indicator button.
    var offlineButton: XCUIElement {
        app.buttons["Offline, sync unavailable"]
    }

    /// Sort picker in the toolbar.
    var sortPicker: XCUIElement {
        app.popUpButtons["Sort products"]
    }

    /// Search field.
    var searchField: XCUIElement {
        app.searchFields.firstMatch
    }

    /// Product grid/list container.
    var productGrid: XCUIElement {
        app.scrollViews.firstMatch
    }

    /// "No Products" empty state.
    var noProductsView: XCUIElement {
        app.staticTexts["No Products"]
    }

    /// "Sync Now" button in empty state.
    var syncNowButton: XCUIElement {
        app.buttons["Sync Now"]
    }

    /// Error banner view.
    var errorBanner: XCUIElement {
        app.groups.containing(NSPredicate(format: "label CONTAINS 'error' OR label CONTAINS 'Error'")).firstMatch
    }

    /// Retry button in error banner.
    var retryButton: XCUIElement {
        app.buttons["Retry"]
    }

    /// Dismiss button in error/rate limit banner.
    var dismissBannerButton: XCUIElement {
        app.buttons.matching(identifier: "Dismiss").firstMatch
    }

    // MARK: - Product Cards

    /// All product card buttons.
    var productCards: XCUIElementQuery {
        app.buttons.matching(identifier: "ProductCard")
    }

    /// Returns the number of product cards visible.
    var productCount: Int {
        productCards.count
    }

    /// Returns a product card by index.
    func productCard(at index: Int) -> XCUIElement {
        productCards.element(boundBy: index)
    }

    /// Finds a product card containing the given text.
    func productCard(containing text: String) -> XCUIElement {
        productCards.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    // MARK: - State

    /// Whether the store is currently syncing.
    var isSyncing: Bool {
        syncProgress.exists
    }

    /// Whether the app is offline.
    var isOffline: Bool {
        offlineButton.exists
    }

    /// Whether the empty state is showing.
    var isEmpty: Bool {
        noProductsView.exists
    }

    /// Whether an error banner is showing.
    var hasError: Bool {
        errorBanner.exists || retryButton.exists
    }

    // MARK: - Actions

    /// Taps the sync button to refresh products.
    @discardableResult
    func tapSync() -> Self {
        if waitForElement(syncButton) {
            syncButton.click()
        }
        return self
    }

    /// Taps the Sync Now button in empty state.
    @discardableResult
    func tapSyncNow() -> Self {
        if waitForElement(syncNowButton) {
            syncNowButton.click()
        }
        return self
    }

    /// Taps the retry button in error banner.
    @discardableResult
    func tapRetry() -> Self {
        if waitForElement(retryButton) {
            retryButton.click()
        }
        return self
    }

    /// Dismisses the error/rate limit banner.
    @discardableResult
    func dismissBanner() -> Self {
        if waitForElement(dismissBannerButton) {
            dismissBannerButton.click()
        }
        return self
    }

    /// Selects a product card by index.
    @discardableResult
    func selectProduct(at index: Int) -> Self {
        let card = productCard(at: index)
        if waitForElement(card) {
            card.click()
        }
        return self
    }

    /// Selects a product card containing the given text.
    @discardableResult
    func selectProduct(containing text: String) -> Self {
        let card = productCard(containing: text)
        if waitForElement(card) {
            card.click()
        }
        return self
    }

    // MARK: - Search

    /// Enters text in the search field.
    @discardableResult
    func search(for text: String) -> Self {
        // Activate search with Cmd+F
        commandKey(.init("f"))
        if waitForElement(searchField) {
            searchField.typeText(text)
        }
        return self
    }

    /// Clears the search field.
    @discardableResult
    func clearSearch() -> Self {
        if searchField.exists {
            searchField.click()
            commandKey(.init("a"))
            typeShortcut(.delete)
            typeShortcut(.escape) // Dismiss search
        }
        return self
    }

    // MARK: - Sort

    /// Changes the sort order.
    @discardableResult
    func sort(by option: String) -> Self {
        if waitForElement(sortPicker) {
            sortPicker.click()
            let menuItem = app.menuItems[option]
            if waitForElement(menuItem) {
                menuItem.click()
            }
        }
        return self
    }

    // MARK: - Waits

    /// Waits for products to load.
    func waitForProducts(timeout: TimeInterval = 10) -> Bool {
        waitForCondition(timeout: timeout) {
            self.productCount > 0 || self.isEmpty
        }
    }

    /// Waits for sync to complete.
    func waitForSyncComplete(timeout: TimeInterval = 30) -> Bool {
        waitForCondition(timeout: timeout) {
            !self.isSyncing
        }
    }

    /// Waits for the store detail to be ready (not loading).
    func waitForReady(timeout: TimeInterval = 10) -> Bool {
        waitForCondition(timeout: timeout) {
            // Either has products, is empty, or has error
            self.productCount > 0 || self.isEmpty || self.hasError
        }
    }
}
