import XCTest

final class LaunchSmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchShowsCoreControls() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["chooseSourceButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["saveOutputButton"].exists)
    }

    func testSaveButtonIsInitiallyDisabled() throws {
        let app = XCUIApplication()
        app.launch()

        let saveButton = app.buttons["saveOutputButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertFalse(saveButton.isEnabled)
    }
}
