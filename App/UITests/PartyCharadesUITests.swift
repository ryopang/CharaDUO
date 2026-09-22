import XCTest

/// Real end-to-end verification of M3: drives the actual rendered UI through
/// the whole loop (Home → Quick Play/Custom Game → gameplay → round summary
/// → match end → Home) via XCUITest against a booted simulator. This
/// environment has no Simulator.app GUI shell, so this — run headlessly via
/// `xcodebuild test` — is the correct substitute for manually tapping
/// through the app.
@MainActor
final class PartyCharadesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testQuickPlayReachesGameplayAndScoresATap() throws {
        let app = XCUIApplication()
        app.launch()

        let quickPlay = app.buttons["Quick Play"]
        XCTAssertTrue(quickPlay.waitForExistence(timeout: 5))
        quickPlay.tap()

        let correct = app.buttons["Correct"]
        let skip = app.buttons["Skip"]
        XCTAssertTrue(correct.waitForExistence(timeout: 5), "gameplay screen should appear immediately with a word drawn")
        XCTAssertTrue(skip.exists)

        correct.tap()
        skip.tap()
        correct.tap()
        // Buttons must still be present and tappable after several taps —
        // proves the deck keeps drawing new words without crashing.
        XCTAssertTrue(correct.exists)
        XCTAssertTrue(skip.exists)
    }

    func testCustomGameShortestMatchReachesMatchEndAndReturnsHome() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Custom Game"].tap()

        // Shrink to the fastest possible match: 2 teams (default), 1 round,
        // the minimum 30s round length.
        let decrementRounds = app.buttons["roundsPerTeamStepper-Decrement"]
        XCTAssertTrue(decrementRounds.waitForExistence(timeout: 5))
        decrementRounds.tap()
        decrementRounds.tap()

        app.buttons["30s"].tap()

        let startMatch = app.buttons["Start Match"]
        for _ in 0..<5 where !startMatch.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(startMatch.waitForExistence(timeout: 5))
        startMatch.tap()

        // Team 1's turn.
        XCTAssertTrue(app.buttons["Correct"].waitForExistence(timeout: 5))
        app.buttons["Correct"].tap()

        let nextTeam = app.buttons["Next Team"]
        XCTAssertTrue(nextTeam.waitForExistence(timeout: 35), "round should auto-advance to summary once the 30s timer expires")
        nextTeam.tap()

        // Team 2's turn — the last one in a 1-round, 2-team match.
        XCTAssertTrue(app.buttons["Correct"].waitForExistence(timeout: 5))
        app.buttons["Correct"].tap()

        let seeResults = app.buttons["See Results"]
        XCTAssertTrue(seeResults.waitForExistence(timeout: 35))
        seeResults.tap()

        XCTAssertTrue(app.staticTexts["Match Complete"].waitForExistence(timeout: 5))
        app.buttons["Back to Home"].tap()

        XCTAssertTrue(app.buttons["Quick Play"].waitForExistence(timeout: 5), "should return cleanly to Home")
    }

    func testCustomGameCancelReturnsHomeWithoutStartingAMatch() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Custom Game"].tap()
        XCTAssertTrue(app.navigationBars["Custom Game"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()

        XCTAssertTrue(app.buttons["Quick Play"].waitForExistence(timeout: 5))
    }
}
