import XCTest

final class WelcomeToSignOutUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGuestFlowCanSignOutBackToWelcome() {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_RESET_LOCAL_STATE",
            "UITEST_SKIP_SIGNUP_DIRECT_TO_HOME"
        ]
        app.launch()

        let skipSignupButton = app.buttons["welcome.skipSignupButton"]
        XCTAssertTrue(skipSignupButton.waitForExistence(timeout: 10))
        skipSignupButton.tap()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()

        let signOutButton = app.buttons["settings.signOutButton"]
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 10))
        signOutButton.tap()

        XCTAssertTrue(skipSignupButton.waitForExistence(timeout: 10))
    }
}
