import XCTest

final class JobsUITests: XCTestCase {
    @MainActor
    func testSearchRetainsFiltersAndDetailCopyFeedback() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let violinJob = app.staticTexts["바이올린 정단원 오디션"]
        let celloJob = app.staticTexts["첼로 수석 단원 모집"]
        XCTAssertTrue(violinJob.waitForExistence(timeout: 10))
        XCTAssertTrue(celloJob.exists)
        XCTAssertFalse(app.staticTexts["jobs.resultCount"].exists)
        XCTAssertFalse(app.buttons["내 도시 우선"].exists)
        capture(app, "Jobs — light")
        app.buttons["바이올린"].tap()
        XCTAssertTrue(waitForNonExistence(celloJob))
        XCTAssertTrue(violinJob.exists)
        let search = app.textFields["jobs.search"]
        search.tap()
        search.typeText("Cadenza\n")
        XCTAssertTrue(violinJob.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["jobs.filters"].exists)
        violinJob.tap()
        XCTAssertTrue(app.buttons["연락처 복사"].waitForExistence(timeout: 5))
        app.buttons["연락처 복사"].tap()
        XCTAssertTrue(app.buttons["연락처 복사 완료"].waitForExistence(timeout: 3))
        capture(app, "Job detail — copy confirmation")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertEqual(search.value as? String, "Cadenza")
        XCTAssertTrue(violinJob.exists)
    }

    @MainActor
    func testSearchFailureIsNotPresentedAsEmptyResults() {
        let app = XCUIApplication()
        app.launch()
        let search = app.textFields["jobs.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("error\n")
        XCTAssertTrue(app.staticTexts["공고를 불러오지 못했어요"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["다시 시도"].exists)
        XCTAssertFalse(app.staticTexts["조건에 맞는 공고가 없어요"].exists)
    }

    @MainActor
    func testOlderSearchCannotReplaceNewerResults() async throws {
        let app = XCUIApplication()
        app.launch()
        let search = app.textFields["jobs.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("slow")
        try await Task.sleep(for: .milliseconds(600))
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "Cadenza\n")
        let violinJob = app.staticTexts["바이올린 정단원 오디션"]
        XCTAssertTrue(violinJob.waitForExistence(timeout: 8))
        try await Task.sleep(for: .seconds(2))
        XCTAssertTrue(violinJob.exists)
    }

    @MainActor
    func testDarkGermanLargeText() {
        let app = XCUIApplication()
        app.launchEnvironment = ["PREVIEW_DARK": "1", "PREVIEW_LANGUAGE": "de"]
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.textFields["jobs.search"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["jobs.filters"].isHittable)
        XCTAssertTrue(app.textFields["jobs.search"].isHittable)
        capture(app, "Jobs — German dark accessibility text")
    }

    @MainActor private func waitForNonExistence(_ element: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: 3) == .completed
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
