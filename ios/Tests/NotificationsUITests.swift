import XCTest

final class NotificationsUITests: XCTestCase {
    @MainActor
    func testSuggestedProfileNavigationAndReturn() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.cadenza.app.kkiri-coporation")
        app.launchArguments = ["-appLanguage", "ko"]
        app.launch()
        XCTAssertTrue(app.textFields["home.search"].waitForExistence(timeout: 20))
        app.tabBars.buttons["알림"].tap()
        let profile = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "notifications.suggestion.profile."
        )).firstMatch
        for _ in 0..<12 {
            if profile.exists && profile.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        XCTAssertTrue(profile.isHittable)
        let name = profile.label
        let userID = profile.identifier.replacingOccurrences(of: "notifications.suggestion.profile.", with: "")
        let connect = app.buttons["notifications.suggestion.connect.\(userID)"]
        XCTAssertTrue(connect.exists)
        XCTAssertTrue(connect.isEnabled)
        let connectionLabel = connect.label

        for _ in 0..<2 {
            profile.tap()
            let navigation = app.navigationBars[name]
            XCTAssertTrue(navigation.waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts.matching(identifier: name).firstMatch.waitForExistence(timeout: 10))
            attach("Suggested person's profile", app)
            navigation.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(profile.waitForExistence(timeout: 10))
            XCTAssertTrue(profile.isHittable)
            XCTAssertEqual(connect.label, connectionLabel)
            XCTAssertTrue(connect.isEnabled)
            XCTAssertTrue(app.tabBars.buttons["알림"].isSelected)
        }
        attach("Returned to suggestions", app)
    }

    @MainActor
    private func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
