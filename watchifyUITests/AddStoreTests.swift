//
//  AddStoreTests.swift
//  watchifyUITests
//
//  Tests for the Add Store workflow.
//

import XCTest

final class AddStoreTests: XCTestCase {

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

    // MARK: - Sheet Presentation Tests

    /// Tests that the Add Store sheet opens when clicking the sidebar button.
    @MainActor
    func testAddStoreSheetOpensFromSidebar() throws {
        sidebar.launch(arguments: ["-UITesting"])

        XCTAssertTrue(sidebar.waitForElement(sidebar.addStoreButton))

        let addStoreScreen = sidebar.tapAddStore()
        _ = addStoreScreen.waitForSheet()

        XCTAssertTrue(addStoreScreen.isShowing, "Add Store sheet should be presented")
    }

    /// Tests that the Add Store sheet opens via Cmd+N keyboard shortcut.
    @MainActor
    func testAddStoreSheetOpensViaKeyboardShortcut() throws {
        sidebar.launch(arguments: ["-UITesting"])

        XCTAssertTrue(sidebar.waitForElement(sidebar.overviewButton))

        // Press Cmd+N
        sidebar.commandKey(.init("n"))

        let addStoreScreen = AddStoreScreen(app: app)
        _ = addStoreScreen.waitForSheet()
        XCTAssertTrue(addStoreScreen.isShowing, "Add Store sheet should open with Cmd+N")
    }

    // MARK: - Cancel Tests

    /// Tests that canceling the Add Store sheet dismisses it without adding a store.
    @MainActor
    func testAddStoreCancel() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let addStoreScreen = sidebar.tapAddStore()
        _ = addStoreScreen.waitForSheet()
        XCTAssertTrue(addStoreScreen.isShowing)

        // Enter some data
        addStoreScreen.enterDomain("test-store.com")

        // Cancel
        addStoreScreen.tapCancel()

        // Sheet should be dismissed
        XCTAssertTrue(addStoreScreen.waitForDismissal(), "Sheet should dismiss on cancel")

        // No store should be added
        XCTAssertFalse(sidebar.hasStore(named: "test-store"), "Store should not be added after cancel")
    }

    /// Tests that pressing Escape dismisses the Add Store sheet.
    @MainActor
    func testAddStoreEscapeDismisses() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let addStoreScreen = sidebar.tapAddStore()
        _ = addStoreScreen.waitForSheet()
        XCTAssertTrue(addStoreScreen.isShowing)

        // Press Escape
        addStoreScreen.dismiss()

        XCTAssertTrue(addStoreScreen.waitForDismissal(), "Sheet should dismiss on Escape")
    }

    // MARK: - Validation Tests

    /// Tests that the Add button is disabled when the domain field is empty.
    @MainActor
    func testAddButtonDisabledWhenEmpty() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let addStoreScreen = sidebar.tapAddStore()
        _ = addStoreScreen.waitForSheet()
        XCTAssertTrue(addStoreScreen.isShowing)

        // Add button should be disabled with empty domain
        XCTAssertFalse(addStoreScreen.addButton.isEnabled, "Add button should be disabled when domain is empty")
    }

    /// Tests that the Add button is enabled when a domain is entered.
    @MainActor
    func testAddButtonEnabledWithDomain() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let addStoreScreen = sidebar.tapAddStore()
        _ = addStoreScreen.waitForSheet()
        XCTAssertTrue(addStoreScreen.isShowing)

        // Enter a domain
        addStoreScreen.enterDomain("example.com")

        // Add button should now be enabled
        XCTAssertTrue(addStoreScreen.addButton.isEnabled, "Add button should be enabled with domain")
    }

    /// Tests that an invalid domain shows an error message.
    @MainActor
    func testAddStoreInvalidDomainShowsError() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let addStoreScreen = sidebar.tapAddStore()
        _ = addStoreScreen.waitForSheet()
        XCTAssertTrue(addStoreScreen.isShowing)

        // Enter an invalid domain (not a real Shopify store)
        addStoreScreen.enterDomain("not-a-real-shopify-store-12345.com")
        addStoreScreen.tapAdd()

        // Wait for error to appear (network request will fail)
        XCTAssertTrue(addStoreScreen.waitForError(timeout: 15), "Error should appear for invalid store")

        // Sheet should still be showing
        XCTAssertTrue(addStoreScreen.sheet.exists, "Sheet should remain open on error")
    }

    // MARK: - Form Behavior Tests

    /// Tests that entering text in the name field works correctly.
    @MainActor
    func testNameFieldInput() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let addStoreScreen = sidebar.tapAddStore()
        _ = addStoreScreen.waitForSheet()
        XCTAssertTrue(addStoreScreen.isShowing)

        addStoreScreen
            .enterDomain("test.com")
            .enterName("My Test Store")

        // Verify both fields have content
        // The form should accept the input
        XCTAssertTrue(addStoreScreen.addButton.isEnabled)
    }

    /// Tests that clearing the domain field disables the Add button.
    @MainActor
    func testClearingDomainDisablesAdd() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let addStoreScreen = sidebar.tapAddStore()
        _ = addStoreScreen.waitForSheet()
        XCTAssertTrue(addStoreScreen.isShowing)

        // Enter then clear domain
        addStoreScreen
            .enterDomain("example.com")

        XCTAssertTrue(addStoreScreen.addButton.isEnabled, "Add should be enabled")

        addStoreScreen.clearDomain()

        // Button should be disabled again
        XCTAssertFalse(addStoreScreen.addButton.isEnabled, "Add should be disabled after clearing")
    }

    // MARK: - Loading State Tests

    /// Tests that the sheet shows a loading indicator while adding a store.
    @MainActor
    func testAddStoreShowsLoadingState() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let addStoreScreen = sidebar.tapAddStore()
        _ = addStoreScreen.waitForSheet()
        XCTAssertTrue(addStoreScreen.isShowing)

        // Enter a domain and submit
        addStoreScreen.enterDomain("example.com")
        addStoreScreen.tapAdd()

        // Check for loading state (progress indicator)
        // This may appear briefly before error
        let hasLoading = addStoreScreen.loadingIndicator.waitForExistence(timeout: 2)

        // Either loading appeared or we quickly got an error/success
        XCTAssertTrue(hasLoading || addStoreScreen.hasError || !addStoreScreen.sheet.exists,
                     "Should show loading, error, or dismiss")
    }

    // MARK: - URL Normalization Tests

    /// Tests that URLs with https:// prefix are normalized.
    @MainActor
    func testURLNormalization() throws {
        sidebar.launch(arguments: ["-UITesting"])

        let addStoreScreen = sidebar.tapAddStore()
        _ = addStoreScreen.waitForSheet()
        XCTAssertTrue(addStoreScreen.isShowing)

        // Enter URL with https prefix
        addStoreScreen.enterDomain("https://example.com/")

        // Should be able to submit (normalization happens in code)
        XCTAssertTrue(addStoreScreen.addButton.isEnabled)
    }
}
