import XCTest

/// M6 end to end on a simulator with no camera: `-uiTestSyntheticCamera`
/// feeds generated frames through the production recorder, so the round
/// summary clip, the Game Over reel and the Save sheet are the real ones.
/// Each test waits out real 30s rounds, so these are the slow ones.
@MainActor
final class ReactionReelUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(captureState: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uiTestSkipConsent",
            "-uiTestSyntheticCamera",
            "-uiTestCaptureState", captureState,
            "-uiTestPosture", "flat",
        ]
        app.launch()
        return app
    }

    /// 2 teams × 1 round × 30s — the shortest match Custom Game allows.
    private func startShortestMatch(_ app: XCUIApplication) {
        app.buttons["Custom Game"].tap()
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
        startMatch.tap()
    }

    private func replayCard(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reaction replay'")).firstMatch
    }

    func testCorrectsProduceAReelThatNeverBlocksTheMatch() throws {
        let app = launch(captureState: "full")
        startShortestMatch(app)

        let correct = app.buttons["Correct"]
        XCTAssertTrue(correct.waitForExistence(timeout: 5))
        sleep(3) // give the buffer some lead-in before the guess
        correct.tap()

        let nextTeam = app.buttons["Next Team"]
        XCTAssertTrue(nextTeam.waitForExistence(timeout: 35))
        XCTAssertTrue(replayCard(app).waitForExistence(timeout: 5), "a Correct should leave a highlight clip on the summary")

        // PRD §5.6 — the clip never blocks "Next team", even while playing.
        nextTeam.tap()
        XCTAssertTrue(correct.waitForExistence(timeout: 5))
        sleep(3)
        correct.tap()

        let seeResults = app.buttons["See Results"]
        XCTAssertTrue(seeResults.waitForExistence(timeout: 35))
        seeResults.tap()

        XCTAssertTrue(app.staticTexts["Reaction Replays"].waitForExistence(timeout: 5))
        let saveReel = app.buttons["Save Reaction Reel"]
        XCTAssertTrue(saveReel.waitForExistence(timeout: 5))
        saveReel.tap()

        XCTAssertTrue(app.buttons["Save to Photos"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["2×"].isSelected, "PRD §5.6 — the picker defaults to 2×")
        app.buttons["3×"].tap()
        app.buttons["Done"].tap()

        app.buttons["Back to Home"].tap()
        XCTAssertTrue(app.buttons["Quick Play"].waitForExistence(timeout: 5))
    }

    func testNoCaptureMeansNoClipSectionAndNoExplanation() throws {
        let app = launch(captureState: "none")
        startShortestMatch(app)

        let correct = app.buttons["Correct"]
        XCTAssertTrue(correct.waitForExistence(timeout: 5))
        correct.tap()

        XCTAssertTrue(app.buttons["Next Team"].waitForExistence(timeout: 35))
        // PRD §5.7 — at most, the summary omits the clip section.
        XCTAssertFalse(replayCard(app).waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["REC"].exists)
    }
}
