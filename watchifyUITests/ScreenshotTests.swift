//
//  ScreenshotTests.swift
//  watchifyUITests
//
//  Captures static screenshots and GIF frames for documentation.
//

import XCTest

final class ScreenshotTests: XCTestCase {

    var app: XCUIApplication!
    var sidebar: SidebarScreen!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        sidebar = SidebarScreen(app: app)
        sidebar.launch(arguments: [
            "-UITesting",
            "-SeedScreenshots",
            "-ScreenshotMode"
        ])

        // Wait for app to be ready
        XCTAssertTrue(sidebar.waitForElement(sidebar.overviewButton, timeout: 10))
    }

    override func tearDownWithError() throws {
        app = nil
        sidebar = nil
    }

    // MARK: - Static Screenshots

    @MainActor
    func testCaptureStaticScreenshots() throws {
        // 1. Overview with 3 store cards
        sidebar.selectOverview()
        Thread.sleep(forTimeInterval: 1)
        attach(screenshot: "01-overview")

        // 2. Allbirds store detail (product grid)
        sidebar.selectStore(named: "Allbirds")
        let storeDetail = StoreDetailScreen(app: app)
        _ = storeDetail.waitForProducts(timeout: 10)
        Thread.sleep(forTimeInterval: 1)
        attach(screenshot: "02-store-detail")

        // 3. Product detail — click first product card (Wool Runner with price chart)
        storeDetail.selectProduct(at: 0)
        Thread.sleep(forTimeInterval: 1)
        attach(screenshot: "03-product-detail")

        // Navigate back to store list
        let backButton = app.buttons["Allbirds"]
        if backButton.waitForExistence(timeout: 3) {
            backButton.click()
        }

        // 4. Activity feed with events
        sidebar.selectActivity()
        Thread.sleep(forTimeInterval: 1)
        attach(screenshot: "04-activity")

        // 5. Settings — General tab
        let settings = SettingsScreen(app: app)
        settings.openViaKeyboard()
        _ = settings.waitForWindow()
        Thread.sleep(forTimeInterval: 0.5)
        attach(screenshot: "05-settings")
        settings.closeViaKeyboard()
    }

    // MARK: - GIF Frames

    @MainActor
    func testCaptureGIFFrames() throws {
        var frameIndex = 0

        func captureFrame() {
            attach(screenshot: String(format: "gif-frame-%03d", frameIndex))
            frameIndex += 1
        }

        // Frame 0: Overview
        sidebar.selectOverview()
        Thread.sleep(forTimeInterval: 0.8)
        captureFrame()

        // Frame 1-2: Navigate to Allbirds store detail
        sidebar.selectStore(named: "Allbirds")
        let storeDetail = StoreDetailScreen(app: app)
        _ = storeDetail.waitForProducts(timeout: 10)
        Thread.sleep(forTimeInterval: 0.8)
        captureFrame()

        // Frame 3: Click product (Wool Runner)
        storeDetail.selectProduct(at: 0)
        Thread.sleep(forTimeInterval: 1)
        captureFrame()

        // Frame 4: Back to store detail
        let backButton = app.buttons["Allbirds"]
        if backButton.waitForExistence(timeout: 3) {
            backButton.click()
        }
        Thread.sleep(forTimeInterval: 0.5)
        captureFrame()

        // Frame 5: Navigate to Gymshark
        sidebar.selectStore(named: "Gymshark")
        _ = storeDetail.waitForProducts(timeout: 10)
        Thread.sleep(forTimeInterval: 0.8)
        captureFrame()

        // Frame 6: Back to overview
        sidebar.selectOverview()
        Thread.sleep(forTimeInterval: 0.8)
        captureFrame()

        // Frame 7: Activity feed
        sidebar.selectActivity()
        Thread.sleep(forTimeInterval: 0.8)
        captureFrame()

        // Frame 8: MVMT Watches
        sidebar.selectStore(named: "MVMT Watches")
        _ = storeDetail.waitForProducts(timeout: 10)
        Thread.sleep(forTimeInterval: 0.8)
        captureFrame()

        // Frame 9: Back to overview (loop point)
        sidebar.selectOverview()
        Thread.sleep(forTimeInterval: 0.8)
        captureFrame()
    }

    // MARK: - Helpers

    private func attach(screenshot name: String) {
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
