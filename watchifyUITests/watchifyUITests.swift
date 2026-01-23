//
//  watchifyUITests.swift
//  watchifyUITests
//
//  Created by cjpher on 1/22/26.
//

import XCTest

final class WatchifyUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-UITesting"]
            app.launch()
        }
    }
}
