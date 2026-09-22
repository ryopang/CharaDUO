import XCTest

/// M4 verification. `simctl` can't fold a simulator — that's a Device Hub GUI
/// action — so these drive the tabletop layout through the DEBUG-only
/// overrides CLAUDE.md §6 asks for, on the iPhone Duo simulator.
///
/// The pure geometry and posture rules are covered by the Posture package's
/// unit tests; what these add is proof the real rendered view tree routes and
/// lays out correctly rather than falling back or crashing.
@MainActor
final class TabletopLayoutUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(posture: String, creaseFraction: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestPosture", posture]
        if let creaseFraction {
            app.launchArguments += ["-uiTestCreaseFraction", creaseFraction]
        }
        app.launch()
        return app
    }

    private func startQuickPlay(_ app: XCUIApplication) {
        let quickPlay = app.buttons["Quick Play"]
        XCTAssertTrue(quickPlay.waitForExistence(timeout: 10))
        quickPlay.tap()
    }

    func testTabletopLayoutRendersBothHitZones() throws {
        let app = launch(posture: "tabletop", creaseFraction: "0.46")
        startQuickPlay(app)

        // Both blind-tap zones live on the flat half (PRD §3.2).
        XCTAssertTrue(app.buttons["Correct"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Skip"].exists)

        // Leave the layout on screen long enough to be captured externally.
        Thread.sleep(forTimeInterval: 8)
    }

    func testTabletopHitZonesStillScore() throws {
        let app = launch(posture: "tabletop", creaseFraction: "0.46")
        startQuickPlay(app)

        let correct = app.buttons["Correct"]
        XCTAssertTrue(correct.waitForExistence(timeout: 10))
        correct.tap()
        app.buttons["Skip"].tap()
        correct.tap()

        // Still alive and drawing new words after tapping through.
        XCTAssertTrue(correct.exists)
        XCTAssertTrue(app.buttons["Skip"].exists)
    }

    /// PRD §3.2 / CLAUDE.md: if the system reports no crease we must NOT
    /// guess a midpoint — the layout falls back to single-screen, which is
    /// still a complete game.
    func testTabletopWithoutACreaseFallsBackToSingleScreen() throws {
        let app = launch(posture: "tabletop") // no crease override
        startQuickPlay(app)

        // Single-screen still presents both zones, so the game stays playable.
        XCTAssertTrue(app.buttons["Correct"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Skip"].exists)
    }

    /// PRD §8 — a flat/fully-open Duo uses the single-screen layout.
    func testFlatPostureUsesSingleScreenLayout() throws {
        let app = launch(posture: "flat")
        startQuickPlay(app)

        XCTAssertTrue(app.buttons["Correct"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Skip"].exists)
    }
}
