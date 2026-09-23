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

    /// The consent card (PRD §7.3) sits in front of the first match, and
    /// UserDefaults survives between launches in a simulator. These tests
    /// are about the game loop, so they pin it to "already answered, camera
    /// off" — the consent card itself has its own tests.
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSkipConsent"]
        app.launch()
        return app
    }

    func testQuickPlayReachesGameplayAndScoresATap() throws {
        let app = launchApp()

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
        let app = launchApp()

        app.buttons["Custom Game"].tap()

        // Shrink to the fastest possible match: 2 teams (default), 1 round,
        // the minimum 30s round length.
        let oneRound = app.segmentedControls["roundsPerTeamPicker"].buttons["1"]
        XCTAssertTrue(oneRound.waitForExistence(timeout: 5))
        oneRound.tap()

        app.buttons["30s"].tap()

        // Categories start unselected (setup rework), which leaves Start
        // Game disabled until at least one is on.
        let animal = app.switches.matching(NSPredicate(format: "label CONTAINS 'Animal'")).firstMatch
        XCTAssertTrue(animal.waitForExistence(timeout: 5))
        animal.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()

        let startMatch = app.buttons["Start Game"]
        let form = app.collectionViews.firstMatch
        for _ in 0..<10 where !startMatch.isHittable {
            form.swipeUp()
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

        XCTAssertTrue(app.staticTexts["Game Over"].waitForExistence(timeout: 5))
        app.buttons["Back to Home"].tap()

        XCTAssertTrue(app.buttons["Quick Play"].waitForExistence(timeout: 5), "should return cleanly to Home")
    }

    func testCustomGameCancelReturnsHomeWithoutStartingAMatch() throws {
        let app = launchApp()

        app.buttons["Custom Game"].tap()
        XCTAssertTrue(app.navigationBars["Custom Game"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()

        XCTAssertTrue(app.buttons["Quick Play"].waitForExistence(timeout: 5))
    }
}
