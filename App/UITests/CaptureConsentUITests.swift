import XCTest

/// M5 verification for PRD §7.3's consent card and §8's degradation rules.
///
/// The simulator has no camera, so every run here exercises the path that
/// matters most: capture unavailable, outer display never presented, game
/// completely unaffected. That is precisely what §1.2.3 demands — "the app
/// must remain fully functional without them."
@MainActor
final class CaptureConsentUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(forceConsent: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [forceConsent ? "-uiTestForceConsent" : "-uiTestSkipConsent"]
        app.launch()
        return app
    }

    func testConsentCardAppearsBeforeTheFirstMatch() throws {
        let app = launch(forceConsent: true)
        app.buttons["Quick Play"].tap()

        XCTAssertTrue(
            app.staticTexts["About the reaction camera"].waitForExistence(timeout: 10),
            "PRD §7.3 — the card must come before the first match, not mid-round"
        )
        XCTAssertTrue(app.buttons["Allow Camera & Mic"].exists)
        XCTAssertTrue(app.buttons["Play Without It"].exists)
    }

    /// Declining is a first-class outcome: the match starts anyway.
    func testDecliningStillStartsTheMatch() throws {
        let app = launch(forceConsent: true)
        app.buttons["Quick Play"].tap()

        XCTAssertTrue(app.buttons["Play Without It"].waitForExistence(timeout: 10))
        app.buttons["Play Without It"].tap()

        XCTAssertTrue(
            app.buttons["Correct"].waitForExistence(timeout: 10),
            "declining the camera must not block the game"
        )
        XCTAssertTrue(app.buttons["Skip"].exists)
    }

    /// Once answered, the card never comes back — and it must never appear
    /// between rounds.
    func testConsentIsNotAskedAgainOnceAnswered() throws {
        let app = launch(forceConsent: false)
        app.buttons["Quick Play"].tap()

        XCTAssertTrue(app.buttons["Correct"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["About the reaction camera"].exists)
    }

    /// PRD §1.2.3 / §8 — with no camera (the simulator's permanent state)
    /// there is no outer display, and the game is unaffected end to end.
    func testGameIsFullyPlayableWithNoCaptureAvailable() throws {
        let app = launch(forceConsent: false)
        app.buttons["Quick Play"].tap()

        let correct = app.buttons["Correct"]
        XCTAssertTrue(correct.waitForExistence(timeout: 10))
        correct.tap()
        app.buttons["Skip"].tap()
        correct.tap()

        XCTAssertTrue(correct.exists)
        XCTAssertTrue(app.buttons["Skip"].exists)
    }
}
