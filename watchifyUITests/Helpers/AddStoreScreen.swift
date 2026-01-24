//
//  AddStoreScreen.swift
//  watchifyUITests
//
//  Page object for the Add Store sheet.
//

import XCTest

/// Page object for the Add Store sheet interactions.
class AddStoreScreen: AppScreen {

    // MARK: - Elements

    /// The Add Store sheet.
    var sheet: XCUIElement {
        app.sheets.firstMatch
    }

    /// Domain text field.
    var domainField: XCUIElement {
        app.textFields["Store domain"]
    }

    /// Name text field.
    var nameField: XCUIElement {
        app.textFields["Store name"]
    }

    /// Add button in the sheet toolbar.
    var addButton: XCUIElement {
        sheet.buttons["Add"]
    }

    /// Cancel button in the sheet toolbar.
    var cancelButton: XCUIElement {
        sheet.buttons["Cancel"]
    }

    /// Loading indicator when adding a store.
    var loadingIndicator: XCUIElement {
        sheet.progressIndicators.firstMatch
    }

    /// Error message text.
    var errorText: XCUIElement {
        app.staticTexts["AddStoreError"]
    }

    // MARK: - State

    /// Whether the Add Store sheet is currently showing.
    var isShowing: Bool {
        sheet.waitForExistence(timeout: 1)
    }

    /// Whether the sheet is in loading state.
    var isLoading: Bool {
        loadingIndicator.exists
    }

    /// The current error message, if any.
    var errorMessage: String? {
        // Wait briefly for element to stabilize
        guard errorText.waitForExistence(timeout: 1) else { return nil }
        let label = errorText.label
        return label.isEmpty ? nil : label
    }

    /// Whether there is an error displayed.
    var hasError: Bool {
        errorText.exists
    }

    // MARK: - Actions

    /// Waits for the sheet to appear.
    @discardableResult
    func waitForSheet(timeout: TimeInterval = 5) -> Self {
        _ = waitForElement(sheet, timeout: timeout)
        return self
    }

    /// Enters a domain in the domain field.
    /// - Parameter domain: The domain to enter
    @discardableResult
    func enterDomain(_ domain: String) -> Self {
        let field = domainField
        if waitForElement(field) {
            field.click()
            field.typeText(domain)
        }
        return self
    }

    /// Enters a name in the name field.
    /// - Parameter name: The name to enter
    @discardableResult
    func enterName(_ name: String) -> Self {
        let field = nameField
        if waitForElement(field) {
            field.click()
            field.typeText(name)
        }
        return self
    }

    /// Clears the domain field.
    @discardableResult
    func clearDomain() -> Self {
        let field = domainField
        if waitForElement(field) {
            field.click()
            commandKey(.init("a"))
            typeShortcut(.delete)
        }
        return self
    }

    /// Taps the Add button to submit the form.
    @discardableResult
    func tapAdd() -> Self {
        if waitForElement(addButton) {
            addButton.click()
        }
        return self
    }

    /// Taps the Cancel button to dismiss the sheet.
    @discardableResult
    func tapCancel() -> Self {
        if waitForElement(cancelButton) {
            cancelButton.click()
        }
        return self
    }

    /// Dismisses the sheet using the Escape key.
    @discardableResult
    func dismiss() -> Self {
        typeShortcut(.escape)
        return self
    }

    /// Waits for the sheet to be dismissed.
    func waitForDismissal(timeout: TimeInterval = 10) -> Bool {
        waitForCondition(timeout: timeout) {
            !self.sheet.exists
        }
    }

    /// Waits for an error to appear.
    func waitForError(timeout: TimeInterval = 5) -> Bool {
        waitForCondition(timeout: timeout) {
            self.hasError
        }
    }

    /// Waits for loading to complete.
    func waitForLoadingComplete(timeout: TimeInterval = 10) -> Bool {
        waitForCondition(timeout: timeout) {
            !self.isLoading
        }
    }

    // MARK: - Combined Actions

    /// Adds a store with the given domain and optional name.
    /// - Parameters:
    ///   - domain: The store domain
    ///   - name: Optional store name
    /// - Returns: SidebarScreen for chaining
    func addStore(domain: String, name: String? = nil) -> SidebarScreen {
        enterDomain(domain)
        if let name {
            enterName(name)
        }
        tapAdd()
        _ = waitForDismissal()
        return SidebarScreen(app: app)
    }
}
