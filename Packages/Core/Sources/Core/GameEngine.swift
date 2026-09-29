import Content
import Foundation
import Observation

/// A single Correct/Skip scoring event, for the App layer's "+1"/"-1"
/// overlay. Carried on `GameEngine` (not view-local state) and mirrored onto
/// `ScoreboardSnapshot` so the inner screen and the outer display animate off
/// the exact same event rather than each guessing independently.
public struct ScoreFeedback: Sendable, Equatable {
    public let id: UUID
    public let delta: Int

    public init(id: UUID = UUID(), delta: Int) {
        self.id = id
        self.delta = delta
    }
}

/// PRD §10.1 — the single source of truth, shared by both scenes (main +
/// accessory) once M5 adds the outer display. The accessory scene only reads
/// this; it must never mutate it (enforced there, not here, by only handing
/// the accessory scene read-only projections).
///
/// No UI, no scene/lifecycle code lives here — this is pure match logic
/// wiring `Deck`, `Scoring`, `RoundTimer`, and `MatchState` together.
@MainActor
@Observable
public final class GameEngine {
    public let configuration: MatchConfiguration
    public private(set) var matchState: MatchState
    public private(set) var currentWord: GameWord?
    public private(set) var timer: RoundTimer?
    public private(set) var turnReshuffled = false
    /// The most recent Correct/Skip feedback event, for the "+1"/"-1"
    /// overlay. Not reset between turns — the App layer keys its animation
    /// off `id` changing, not off this becoming nil.
    public private(set) var lastFeedback: ScoreFeedback?

    private var deck: Deck
    private var turnEvents: [RoundEvent] = []

    public init(configuration: MatchConfiguration, words: [GameWord], seed: UInt64 = .random(in: .min ... .max)) throws {
        self.configuration = configuration
        self.matchState = MatchState(configuration: configuration)
        self.deck = try Deck(
            words: words,
            seed: seed,
            favoredRegion: configuration.language.homeRegion
        )
    }

    /// Starts the current team's timed turn: resets the deck's per-round
    /// exclusion window, starts the round timer, and draws the first word.
    public func startTurn(clock: ContinuousClock = ContinuousClock()) {
        guard !matchState.isMatchComplete, timer == nil else { return }
        deck.startRound()
        turnEvents = []
        turnReshuffled = false
        timer = RoundTimer(duration: configuration.roundDuration.duration, clock: clock)
        drawNextWord()
    }

    public var isPaused: Bool { timer?.isPaused ?? false }

    /// Score accumulated so far in the in-progress turn — drives the live
    /// score the guessers read on the far edge (PRD §3.2).
    public var currentTurnScore: Int {
        Scoring.totalScore(for: turnEvents, skipPenaltyEnabled: configuration.skipPenaltyEnabled)
    }

    /// PRD §3.1 — the only posture event that pauses a match is `.closed`.
    /// Everything else reflows the layout and play continues.
    public func pauseTurn(at instant: ContinuousClock.Instant = ContinuousClock().now) {
        timer?.pause(at: instant)
    }

    public func resumeTurn(at instant: ContinuousClock.Instant = ContinuousClock().now) {
        timer?.resume(at: instant)
    }

    public func markCorrect() {
        recordEvent(kind: .correct)
    }

    public func markSkip() {
        recordEvent(kind: .skip)
    }

    /// Posts a "+1"/"-1" feedback event for the overlay. Called by the App
    /// layer alongside `markCorrect()`/`markSkip()` — kept separate from
    /// those so Core's scoring stays free of any display concern (whether an
    /// event should even show an overlay, e.g. skip with no penalty enabled,
    /// is an App-layer decision).
    public func postFeedback(delta: Int) {
        lastFeedback = ScoreFeedback(delta: delta)
    }

    /// Ends the in-progress turn, scores it, and folds it into `matchState`.
    /// Call once the timer expires or the describer's team is done early.
    @discardableResult
    public func endTurn() -> TurnResult {
        precondition(timer != nil, "endTurn called with no turn in progress")
        let result = TurnResult(
            teamIndex: matchState.currentTeamIndex,
            roundIndex: matchState.currentRoundIndex,
            events: turnEvents,
            score: Scoring.totalScore(for: turnEvents, skipPenaltyEnabled: configuration.skipPenaltyEnabled),
            deckReshuffled: turnReshuffled
        )
        matchState.recordTurn(result)
        timer = nil
        currentWord = nil
        turnEvents = []
        return result
    }

    private func drawNextWord() {
        let draw = deck.draw()
        if draw.reshuffled {
            turnReshuffled = true
        }
        currentWord = draw.word
    }

    private func recordEvent(kind: RoundEventKind) {
        guard let timer, !timer.isPaused, let word = currentWord else { return }
        turnEvents.append(RoundEvent(word: word, kind: kind))
        drawNextWord()
    }
}
