import Content
import Core
import Foundation
import Observation

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
    private let contentStore: ContentStore

    init(contentStore: ContentStore, settings: AppSettings = AppSettings()) {
        self.contentStore = contentStore
        self.settings = settings
    }

    func presentCustomGame() {
        screen = .customGame
    }

    func returnHome() {
        engine = nil
        lastTurnResult = nil
        startError = nil
        screen = .home
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
    }

    func continueAfterRoundSummary() {
        guard let engine else { return }
        if engine.matchState.isMatchComplete {
            screen = .matchEnd
        } else {
            engine.startTurn()
            screen = .gameplay
        }
    }
}
