import XCTest

final class PublicProfileLocalizationUITests: XCTestCase {
    @MainActor
    func testEnglishTitles() {
        checkTitles(language: "en", profileTab: "Profile", titles: [
            "About", "My Activities", "Career", "Education", "Honors & Awards",
            "Languages", "CV / Website", "Recommendations", "Organization Page"
        ])
    }

    @MainActor
    func testGermanTitles() {
        checkTitles(language: "de", profileTab: "Profil", titles: [
            "Über mich", "Meine Aktivitäten", "Berufserfahrung", "Ausbildung", "Auszeichnungen",
            "Sprachen", "CV / Webseite", "Empfehlungen", "Organisationsseite"
        ])
    }

    @MainActor
    func testKoreanTitles() {
        checkTitles(language: "ko", profileTab: "프로필", titles: [
            "소개", "나의 활동", "경력사항", "학력", "수상 경력", "언어", "CV / 홈페이지", "추천서", "기관 페이지"
        ])
    }

    @MainActor
    private func checkTitles(language: String, profileTab: String, titles: [String]) {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.cadenza.app.kkiri-coporation")
        app.launchArguments = ["-appLanguage", language]
        app.launch()
        XCTAssertTrue(app.textFields["home.search"].waitForExistence(timeout: 20))
        app.tabBars.buttons[profileTab].tap()
        let manage = app.buttons["profile.sections.manage"]
        XCTAssertTrue(manage.waitForExistence(timeout: 10))
        manage.tap()
        let keys = ["bio", "activities", "career", "education", "awards", "languages",
                    "cv_website", "recommendations", "org"]
        for (key, title) in zip(keys, titles) {
            let toggle = app.switches["profile.sections.toggle.\(key)"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            XCTAssertEqual(toggle.label, title)
        }
        attach("Section titles - \(language)", app)
        app.buttons["profile.sections.cancel"].tap()

        app.buttons["profile.connections"].tap()
        let person = app.staticTexts.matching(identifier: "임재원").firstMatch
        XCTAssertTrue(person.waitForExistence(timeout: 15))
        person.tap()
        XCTAssertTrue(app.navigationBars["임재원"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[titles[0]].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[titles[1]].exists)
        attach("Public profile top - \(language)", app)

        var sawEducation = false
        for _ in 0..<4 {
            sawEducation = sawEducation || app.staticTexts[titles[3]].exists
            XCTAssertEqual(app.staticTexts.matching(NSPredicate(
                format: "label BEGINSWITH %@", "profile."
            )).count, 0)
            app.swipeUp()
        }
        XCTAssertTrue(sawEducation)
        attach("Public profile lower sections - \(language)", app)
    }

    @MainActor
    private func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
