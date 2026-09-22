import Content
import Core
import Foundation
import Observation
import Posture
#if canImport(UIKit)
import UIKit
#endif

/// Owns navigation between the setup, gameplay, round-summary and match-end
/// screens, and creates/discards the `GameEngine` for each match. No UI code.
@MainActor
@Observable
final class AppCoordinator {
    enum Screen: Equatable {
        case home
        case customGame
        case gameplay
        case roundSummary
        case matchEnd
    }

    private(set) var screen: Screen = .home
    private(set) var engine: GameEngine?
    private(set) var lastTurnResult: TurnResult?
    var startError: String?

    let settings: AppSettings
    let hinge = HingeObserver()
    private let contentStore: ContentStore

    var posture: PostureState {
        #if DEBUG
        if let forced = DebugOverrides.posture { return forced }
        #endif
        return hinge.posture
    }

    init(contentStore: ContentStore, settings: AppSettings = AppSettings()) {
        self.contentStore = contentStore
        self.settings = settings
    }

    /// PRD §3.1 — the *only* posture event that pauses a match is `.closed`.
    /// Tabletop ⇄ flat transitions just reflow the layout mid-round.
    func postureChanged(to posture: PostureState) {
        guard posture == .closed, screen == .gameplay, let engine, !engine.isPaused else { return }
        engine.pauseTurn()
        setIdleTimerDisabled(false)
    }

    func resumeFromPause() {
        guard let engine, engine.isPaused else { return }
        engine.resumeTurn()
        setIdleTimerDisabled(true)
    }

    /// PRD §10.3 — the screen must not sleep mid-round, and must be allowed
    /// to sleep at every other moment.
    private func setIdleTimerDisabled(_ disabled: Bool) {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = disabled
        #endif
    }

    func presentCustomGame() {
        screen = .customGame
    }

    func returnHome() {
        engine = nil
        lastTurnResult = nil
        startError = nil
        screen = .home
        setIdleTimerDisabled(false)
    }

    /// PRD §2.4 Quick Play: one tap, 2 teams, all categories, 60s, 3 rounds,
    /// last-used language. No naming, no toggles.
    func startQuickPlay() {
        start(with: MatchConfiguration(
            teams: [Team(), Team()],
            roundsPerTeam: 3,
            roundDuration: .default,
            categories: Set(GameCategory.allCases),
            language: settings.lastUsedLanguage,
            skipPenaltyEnabled: false
        ))
    }

    func startCustomGame(_ configuration: MatchConfiguration) {
        start(with: configuration)
    }

    private func start(with configuration: MatchConfiguration) {
        settings.lastUsedLanguage = configuration.language
        let words = contentStore.words(in: configuration.categories)
        do {
            let engine = try GameEngine(configuration: configuration, words: words)
            self.engine = engine
            self.startError = nil
            engine.startTurn()
            screen = .gameplay
            setIdleTimerDisabled(true)
        } catch {
            startError = "Not enough words in the selected categories to start a match."
        }
    }

    /// Called from the countdown view whenever the clock ticks; a no-op
    /// unless the current turn's timer has actually expired (PRD §10.3 —
    /// the tick is just a redraw prompt, expiry is decided from wall-clock
    /// elapsed time, never from tick count).
    func checkForTurnExpiry(now: ContinuousClock.Instant) {
        guard screen == .gameplay, let engine, let timer = engine.timer else { return }
        if timer.isExpired(now: now) {
            endCurrentTurn()
        }
    }

    func endCurrentTurn() {
        guard let engine, engine.timer != nil else { return }
        lastTurnResult = engine.endTurn()
        screen = .roundSummary
        setIdleTimerDisabled(false)
    }

    func continueAfterRoundSummary() {
        guard let engine else { return }
        if engine.matchState.isMatchComplete {
            screen = .matchEnd
        } else {
            engine.startTurn()
            screen = .gameplay
            setIdleTimerDisabled(true)
        }
    }
}
