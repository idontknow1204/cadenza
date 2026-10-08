import XCTest

final class RecordComposerUITests: XCTestCase {
    @MainActor
    func testRecordTabOpensAndReturnsToSelectedTab() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.cadenza.app.kkiri-coporation")
        app.launchArguments = ["-appLanguage", "ko"]
        app.launch()
        XCTAssertTrue(app.textFields["home.search"].waitForExistence(timeout: 20))
        for tab in ["홈", "프로필"] {
            app.tabBars.buttons[tab].tap()
            app.tabBars.buttons["기록"].tap()
            XCTAssertTrue(app.navigationBars["기록하기"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["독주"].isHittable)
            let height = app.buttons["독주"].frame.height
            app.buttons["독주"].tap()
            XCTAssertEqual(app.buttons["독주"].frame.height, height, accuracy: 1)
            XCTAssertLessThan(height, 100)
            app.buttons["취소"].tap()
            XCTAssertTrue(app.tabBars.buttons[tab].isSelected)
        }
    }

    @MainActor
    func testHeaderComposerAndLocalizedChips() {
        continueAfterFailure = false
        for (language, cancel, solo) in [
            ("en", "Cancel", "Solo"),
            ("de", "Abbrechen", "Solo")
        ] {
            let app = XCUIApplication(bundleIdentifier: "com.cadenza.app.kkiri-coporation")
            app.launchArguments = ["-appLanguage", language]
            app.launch()
            XCTAssertTrue(app.textFields["home.search"].waitForExistence(timeout: 20))
            app.buttons.matching(identifier: "home.create").firstMatch.tap()
            XCTAssertTrue(app.buttons[solo].waitForExistence(timeout: 5), language)
            let chip = app.buttons[solo]
            XCTAssertLessThan(chip.frame.height, 120)
            chip.tap()
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Record composer \(language)"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.buttons[cancel].tap()
            XCTAssertTrue(app.textFields["home.search"].exists)
        }
    }
}
