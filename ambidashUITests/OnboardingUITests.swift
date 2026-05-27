import XCTest

@MainActor
final class OnboardingUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-state"]
        app.launch()
    }

    func testThemeSetupScreenAppears() throws {
        XCTAssertTrue(app.staticTexts["Make it yours."].waitForExistence(timeout: 5))
    }

    func testPaletteOptionsVisible() throws {
        XCTAssertTrue(app.staticTexts["Make it yours."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Yellow"].exists)
        XCTAssertTrue(app.staticTexts["Cool"].exists)
        XCTAssertTrue(app.staticTexts["Forest"].exists)
        XCTAssertTrue(app.staticTexts["Rose"].exists)
    }

    func testTypographyOptionsVisible() throws {
        XCTAssertTrue(app.staticTexts["Make it yours."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Editorial"].exists)
        XCTAssertTrue(app.staticTexts["Modern"].exists)
        XCTAssertTrue(app.staticTexts["Technical"].exists)
    }

    func testDensityOptionsVisible() throws {
        XCTAssertTrue(app.staticTexts["Make it yours."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Calm"].exists)
        XCTAssertTrue(app.staticTexts["Detailed"].exists)
    }

    func testContinueNavigatesToWelcome() throws {
        XCTAssertTrue(app.staticTexts["Make it yours."].waitForExistence(timeout: 5))
        app.scrollViews.firstMatch.swipeUp()
        let btn = app.buttons["Continue"]
        if btn.waitForExistence(timeout: 3) {
            btn.tap()
            let appeared = app.staticTexts["A quiet instrument for an ambitious life."].waitForExistence(timeout: 5)
                || app.staticTexts["Begin"].waitForExistence(timeout: 5)
            XCTAssertTrue(appeared)
        }
    }
}
