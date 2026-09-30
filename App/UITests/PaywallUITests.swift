import XCTest

/// The game allowance gate: 10 free games, then the paywall. Launch flags
/// give an in-memory allowance, so nothing here touches the real Keychain.
@MainActor
final class PaywallUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSkipConsent"] + extra
        app.launch()
        return app
    }

    func testFreshInstallShowsTenGamesAndStartsWithoutPaywall() {
        let app = launch([])
        XCTAssertTrue(app.staticTexts["gamesLeft"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["gamesLeft"].label, "Games left: 10")

        app.buttons["Quick Play"].tap()
        XCTAssertTrue(app.buttons["Correct"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["paywall.pack"].exists)
    }

    func testOutOfGamesShowsPaywallInsteadOfStarting() {
        let app = launch(["-uiTestGamesPlayed", "10"])
        XCTAssertTrue(app.buttons["lowGamesNotice"].waitForExistence(timeout: 5))

        app.buttons["Quick Play"].tap()
        XCTAssertTrue(app.buttons["paywall.pack"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["paywall.unlimited"].exists)
        XCTAssertFalse(app.buttons["Correct"].exists, "no match may start behind the paywall")

        app.buttons["Not Now"].tap()
        XCTAssertTrue(app.buttons["Quick Play"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Correct"].exists)
    }

    func testLowGamesNoticeAppearsAtThreeLeftAndOpensStore() {
        let app = launch(["-uiTestGamesPlayed", "7"])
        let notice = app.buttons["lowGamesNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        notice.tap()
        XCTAssertTrue(app.buttons["paywall.pack"].waitForExistence(timeout: 5))
        app.buttons["Not Now"].tap()
        XCTAssertTrue(app.buttons["Quick Play"].waitForExistence(timeout: 5))
    }

    func testNoLowGamesNoticeWithFourLeft() {
        let app = launch(["-uiTestGamesPlayed", "6"])
        XCTAssertTrue(app.staticTexts["gamesLeft"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["lowGamesNotice"].exists)
    }

    func testUnlimitedHidesCounterAndNeverGates() {
        let app = launch(["-uiTestUnlimited", "-uiTestGamesPlayed", "50"])
        XCTAssertTrue(app.buttons["Quick Play"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["gamesLeft"].exists)
        app.buttons["Quick Play"].tap()
        XCTAssertTrue(app.buttons["Correct"].waitForExistence(timeout: 5))
    }
}
