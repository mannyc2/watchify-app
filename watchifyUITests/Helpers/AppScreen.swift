//
//  AppScreen.swift
//  watchifyUITests
//
//  Base class for page objects with common utilities.
//

import XCTest

/// Base class for page objects providing common UI testing utilities.
class AppScreen {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Launch Helpers

    /// Launches the app with the specified arguments.
    /// - Parameters:
    ///   - arguments: Additional launch arguments (e.g., "-SeedTestData")
    ///   - resetState: Whether to include "-UITesting" to reset state
    @discardableResult
    func launch(arguments: [String] = [], resetState: Bool = true) -> Self {
        var allArgs = arguments
        if resetState {
            allArgs.insert("-UITesting", at: 0)
        }
        app.launchArguments = allArgs
        app.launch()
        return self
    }

    // MARK: - Wait Helpers

    /// Waits for an element to exist with a timeout.
    /// - Parameters:
    ///   - element: The element to wait for
    ///   - timeout: Maximum wait time (default 5 seconds)
    /// - Returns: True if element exists within timeout
    @discardableResult
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Waits for an element to become hittable (exists and is not obscured).
    /// - Parameters:
    ///   - element: The element to wait for
    ///   - timeout: Maximum wait time
    /// - Returns: True if element becomes hittable within timeout
    func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Waits for a condition to become true.
    /// - Parameters:
    ///   - timeout: Maximum wait time
    ///   - pollInterval: Time between condition checks
    ///   - condition: Closure that returns true when condition is met
    /// - Returns: True if condition becomes true within timeout
    func waitForCondition(
        timeout: TimeInterval = 5,
        pollInterval: TimeInterval = 0.1,
        condition: () -> Bool
    ) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if condition() { return true }
            Thread.sleep(forTimeInterval: pollInterval)
        }
        return condition()
    }

    /// Waits for an element's count to reach a specific value.
    /// - Parameters:
    ///   - query: The element query to count
    ///   - count: Expected count
    ///   - timeout: Maximum wait time
    /// - Returns: True if count matches within timeout
    func waitForCount(_ query: XCUIElementQuery, count: Int, timeout: TimeInterval = 5) -> Bool {
        waitForCondition(timeout: timeout) {
            query.count == count
        }
    }

    // MARK: - Screenshot Helpers

    /// Captures and attaches a screenshot to the test results.
    /// - Parameters:
    ///   - name: Name for the screenshot
    ///   - lifetime: Attachment lifetime
    /// - Returns: The screenshot attachment
    @discardableResult
    func screenshot(name: String, lifetime: XCTAttachment.Lifetime = .keepAlways) -> XCTAttachment {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = lifetime
        return attachment
    }

    // MARK: - Keyboard Shortcuts

    /// Types a keyboard shortcut.
    /// - Parameters:
    ///   - key: The key to press
    ///   - modifiers: Modifier flags (e.g., .command)
    func typeShortcut(_ key: XCUIKeyboardKey, modifiers: XCUIElement.KeyModifierFlags = []) {
        app.typeKey(key, modifierFlags: modifiers)
    }

    /// Types Command+key shortcut.
    func commandKey(_ key: XCUIKeyboardKey) {
        typeShortcut(key, modifiers: .command)
    }

    /// Types Shift+Command+key shortcut.
    func shiftCommandKey(_ key: XCUIKeyboardKey) {
        typeShortcut(key, modifiers: [.shift, .command])
    }

    // MARK: - Common Elements

    /// The main application window.
    var mainWindow: XCUIElement {
        app.windows.firstMatch
    }

    /// Whether a sheet is currently presented.
    var isSheetPresented: Bool {
        app.sheets.count > 0
    }

    /// Dismisses any presented sheet by pressing Escape.
    func dismissSheet() {
        if isSheetPresented {
            typeShortcut(.escape)
        }
    }
}
