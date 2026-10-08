import XCTest

final class ProfileActivitiesUITests: XCTestCase {
    @MainActor
    func testSectionVisibilityCancelSaveAndRestore() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.cadenza.app.kkiri-coporation")
        app.launchArguments = ["-appLanguage", "ko"]
        app.launch()
        XCTAssertTrue(app.textFields["home.search"].waitForExistence(timeout: 20))
        app.tabBars.buttons["프로필"].tap()
        let manage = app.buttons["profile.sections.manage"]
        XCTAssertTrue(manage.waitForExistence(timeout: 10))
        manage.tap()
        let keys = ["bio", "activities", "career", "education", "awards", "languages",
                    "cv_website", "recommendations", "org"]
        let bio = app.switches["profile.sections.toggle.bio"]
        XCTAssertTrue(bio.waitForExistence(timeout: 5))
        var initial: [String: Bool] = [:]
        for key in keys {
            let toggle = app.switches["profile.sections.toggle.\(key)"]
            XCTAssertTrue(toggle.exists)
            initial[key] = toggle.value as? String == "1"
        }
        attach("Section controls", app)
        flipSwitch(bio)
        app.buttons["profile.sections.cancel"].tap()
        manage.tap()
        XCTAssertEqual(bio.value as? String == "1", initial["bio"])

        // Restore the original settings even if a later assertion fails.
        addTeardownBlock { @MainActor in
            app.terminate()
            app.launch()
            guard app.textFields["home.search"].waitForExistence(timeout: 20) else { return }
            app.tabBars.buttons["프로필"].tap()
            guard manage.waitForExistence(timeout: 10) else { return }
            manage.tap()
            guard bio.waitForExistence(timeout: 5) else { return }
            for key in keys {
                let toggle = app.switches["profile.sections.toggle.\(key)"]
                if (toggle.value as? String == "1") != initial[key] { self.flipSwitch(toggle) }
            }
            let save = app.buttons["profile.sections.save"]
            if save.isEnabled {
                save.tap()
                XCTAssertTrue(manage.waitForExistence(timeout: 15))
            } else {
                app.buttons["profile.sections.cancel"].tap()
            }
        }

        for key in keys {
            let toggle = app.switches["profile.sections.toggle.\(key)"]
            if toggle.value as? String == "1" { flipSwitch(toggle) }
        }
        let save = app.buttons["profile.sections.save"]
        if save.isEnabled { save.tap() }
        else { app.buttons["profile.sections.cancel"].tap() }
        XCTAssertTrue(manage.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["profile.activities.all"].exists)
        attach("All sections hidden", app)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.textFields["home.search"].waitForExistence(timeout: 20))
        app.tabBars.buttons["프로필"].tap()
        XCTAssertTrue(manage.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["profile.activities.all"].exists)
        manage.tap()
        XCTAssertTrue(bio.waitForExistence(timeout: 5))
        for key in keys {
            let toggle = app.switches["profile.sections.toggle.\(key)"]
            XCTAssertEqual(toggle.value as? String, "0")
            if initial[key] == true { flipSwitch(toggle) }
        }
        if save.isEnabled { save.tap() }
        else { app.buttons["profile.sections.cancel"].tap() }
        XCTAssertTrue(manage.waitForExistence(timeout: 15))
        if initial["activities"] == true {
            XCTAssertTrue(app.buttons["profile.activities.all"].waitForExistence(timeout: 5))
        }
        attach("Sections restored", app)
    }

    @MainActor
    func testActivityArchiveFiltersAndBackNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.cadenza.app.kkiri-coporation")
        app.launchArguments = ["-appLanguage", "ko"]
        app.launch()
        XCTAssertTrue(app.textFields["home.search"].waitForExistence(timeout: 20))
        app.tabBars.buttons["프로필"].tap()

        let allActivities = app.buttons["profile.activities.all"]
        for _ in 0..<5 {
            if allActivities.exists && allActivities.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(allActivities.isHittable)
        allActivities.tap()
        XCTAssertTrue(app.navigationBars["나의 활동"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profile.activities.filter.all"].isSelected)
        let total = app.staticTexts["profile.activities.count"].label
        attach("All activities", app)

        let details = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "profile.activities.details."
        )).firstMatch
        XCTAssertTrue(details.exists)
        let collapsedPosition = details.frame.minY
        for _ in 0..<2 {
            details.tap()
            XCTAssertEqual(details.value as? String, "펼쳐짐")
            XCTAssertEqual(details.frame.minY, collapsedPosition, accuracy: 2)
            attach("Details expanded", app)
            details.tap()
            XCTAssertEqual(details.value as? String, "접힘")
            XCTAssertEqual(details.frame.minY, collapsedPosition, accuracy: 2)
        }

        let categories = ["performance", "competition", "education", "recording"]
        for category in categories {
            let filter = app.buttons["profile.activities.filter.\(category)"]
            filter.tap()
            XCTAssertTrue(filter.isSelected)
            for other in categories where other != category {
                XCTAssertFalse(app.descendants(matching: .any)["profile.activities.row.\(other)"].exists)
            }
            XCTAssertTrue(
                app.descendants(matching: .any)["profile.activities.row.\(category)"].exists ||
                app.descendants(matching: .any)["profile.activities.empty"].exists
            )
        }
        attach("Recording filter", app)
        app.buttons["profile.activities.filter.all"].tap()
        XCTAssertEqual(app.staticTexts["profile.activities.count"].label, total)
        app.navigationBars["나의 활동"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(allActivities.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["프로필"].isSelected)
    }

    @MainActor
    private func flipSwitch(_ toggle: XCUIElement) {
        let previous = toggle.value as? String
        // SwiftUI exposes the full labeled row as the switch's accessibility frame.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertNotEqual(toggle.value as? String, previous)
    }

    @MainActor
    private func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
