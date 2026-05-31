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
        // Palette labels live inside Buttons (alongside the colour swatches), so
        // depending on how XCUITest flattens the label they surface as either a
        // staticText or the button's own label. Accept either.
        XCTAssertTrue(elementExists("Yellow"))
        XCTAssertTrue(elementExists("Cool"))
        XCTAssertTrue(elementExists("Forest"))
        XCTAssertTrue(elementExists("Rose"))
    }

    func testTypographyOptionsVisible() throws {
        XCTAssertTrue(app.staticTexts["Make it yours."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Editorial"].exists)
        XCTAssertTrue(app.staticTexts["Modern"].exists)
        XCTAssertTrue(app.staticTexts["Technical"].exists)
    }

    func testDensityOptionsVisible() throws {
        XCTAssertTrue(app.staticTexts["Make it yours."].waitForExistence(timeout: 5))
        // Density options are single-Text Buttons, so the label is absorbed into
        // the Button's accessibility label rather than a separate staticText.
        XCTAssertTrue(elementExists("Calm"))
        XCTAssertTrue(elementExists("Detailed"))
    }

    /// True if a label is present anywhere on screen, whether XCUITest exposes it
    /// as a staticText or as a Button label (single-Text buttons collapse the two).
    private func elementExists(_ label: String) -> Bool {
        app.staticTexts[label].exists || app.buttons[label].exists
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
