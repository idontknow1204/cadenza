import XCTest

final class LoadingUITests: XCTestCase {
    @MainActor
    func testLogoAndNativeRefresh() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["preview.refreshCount"].waitForExistence(timeout: 10))
        capture(app, name: "Gray loading logos on light dark and burgundy backgrounds")
        XCTAssertTrue(app.progressIndicators["preview.determinate"].exists)
        for index in 1...3 {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
            capture(app, name: "Native refresh logo \(index)")
            let complete = NSPredicate(format: "label == %@", "Refreshes: \(index)")
            expectation(for: complete, evaluatedWith: app.staticTexts["preview.refreshCount"])
            waitForExpectations(timeout: 12)
        }
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
