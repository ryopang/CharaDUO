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
        // Scroll in small steps until the row sits mid-screen, clear of the
        // translucent title bar that overlays the top of the form.
        let window = app.windows.firstMatch
        for _ in 0..<15 where animal.frame.midY > window.frame.height * 0.6 || animal.frame.midY < window.frame.height * 0.3 {
            let dragUp = animal.frame.midY > window.frame.height * 0.6
            let from = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: dragUp ? 0.7 : 0.4))
            let to = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: dragUp ? 0.5 : 0.6))
            from.press(forDuration: 0.05, thenDragTo: to)
            sleep(1)
        }
        for _ in 0..<3 where (animal.value as? String) != "1" {
            animal.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            sleep(1)
        }
        XCTAssertEqual(animal.value as? String, "1", "Animal category should be on")

        let startMatch = app.buttons["Start Game"]
        let form = app.collectionViews.firstMatch
        for _ in 0..<10 where !startMatch.isHittable {
            // The form isn't always exposed as a collection view; swiping
            // the app scrolls it either way.
            (form.exists ? form : app).swipeUp()
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

    /// The UI follows the phone (English on the test simulator) until a
    /// language is picked in Settings; a Custom Game word language never
    /// changes the UI; a Settings choice survives a relaunch.
    func testAppLanguageFollowsPhoneUntilChosenInSettings() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSkipConsent", "-uiTestResetAppLanguage"]
        app.launch()
        XCTAssertTrue(app.buttons["Quick Play"].waitForExistence(timeout: 5))

        // Custom Game word language: this match only, UI untouched.
        app.buttons["Custom Game"].tap()
        let wordLanguage = app.segmentedControls["wordLanguagePicker"]
        for _ in 0..<4 where !wordLanguage.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(wordLanguage.exists)
        wordLanguage.buttons["香港"].tap()
        XCTAssertTrue(app.navigationBars["Custom Game"].exists, "picking a word language must not change the UI language")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Quick Play"].waitForExistence(timeout: 5))

        // Settings choice: applies now and is kept.
        app.buttons["Settings"].tap()
        let hongKong = app.buttons["香港"].exists ? app.buttons["香港"] : app.staticTexts["香港"]
        XCTAssertTrue(hongKong.waitForExistence(timeout: 5))
        hongKong.tap()

        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launchArguments += ["-uiTestSkipConsent"]
        relaunched.launch()
        XCTAssertTrue(relaunched.buttons["即刻玩"].waitForExistence(timeout: 5), "a language chosen in Settings survives a relaunch")
        relaunched.terminate()

        // Leave the simulator following the phone again for other tests.
        let reset = XCUIApplication()
        reset.launchArguments += ["-uiTestSkipConsent", "-uiTestResetAppLanguage"]
        reset.launch()
        XCTAssertTrue(reset.buttons["Quick Play"].waitForExistence(timeout: 5))
        reset.terminate()
    }
}
