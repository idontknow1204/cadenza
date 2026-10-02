import XCTest

final class FeedRefreshUITests: XCTestCase {
    @MainActor
    func testPendingConnectionRequestRemainsEnabled() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.cadenza.app.kkiri-coporation")
        app.launchArguments = ["-appLanguage", "ko"]
        app.launch()
        XCTAssertTrue(app.textFields["home.search"].waitForExistence(timeout: 20))
        let pending = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label == %@", "feed.connection.", "요청됨"
        )).firstMatch
        for _ in 0..<12 {
            if pending.exists && pending.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(pending.waitForExistence(timeout: 10))
        XCTAssertTrue(pending.isHittable)
        XCTAssertTrue(pending.isEnabled)
        // Do not send or cancel another person's real connection request in this test.
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Pending connection remains actionable"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testRepeatedPullToRefresh() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.cadenza.app.kkiri-coporation")
        app.launchArguments = ["-appLanguage", "ko"]
        app.launch()
        XCTAssertTrue(app.textFields["home.search"].waitForExistence(timeout: 20))

        for index in 0..<5 {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
            let alert = app.alerts.firstMatch
            let hasAlert = alert.waitForExistence(timeout: 3)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Refresh \(index + 1)"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTAssertFalse(hasAlert, hasAlert ? alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | ") : "")
            XCTAssertTrue(app.textFields["home.search"].exists)
            if index == 2 {
                app.tabBars.buttons["프로필"].tap()
                app.tabBars.buttons["홈"].tap()
                XCTAssertTrue(app.textFields["home.search"].waitForExistence(timeout: 10))
            }
        }
    }
}
