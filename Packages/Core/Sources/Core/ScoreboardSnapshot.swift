import Content
import Foundation

/// PRD §10.2 — the accessory scene is a **read-only projection** of
/// `GameEngine`; it must not own or mutate state. Handing it an immutable
/// value rather than the engine makes that structural instead of a rule
/// someone has to remember.
public struct ScoreboardSnapshot: Sendable, Equatable {
    public let category: GameCategory
    public let secondsRemaining: Int
    public let fractionElapsed: Double
    public let teamName: String
    public let score: Int
    public let isRecording: Bool

    public init(
        category: GameCategory,
        secondsRemaining: Int,
        fractionElapsed: Double,
        teamName: String,
        score: Int,
        isRecording: Bool
    ) {
        self.category = category
        self.secondsRemaining = secondsRemaining
        self.fractionElapsed = fractionElapsed
        self.teamName = teamName
        self.score = score
        self.isRecording = isRecording
    }
}

extension GameEngine {
    /// Builds the projection the guessers' scoreboard renders (PRD §3.4):
    /// current category, countdown, team name and live score.
    public func scoreboardSnapshot(
        now: ContinuousClock.Instant = ContinuousClock().now,
        isRecording: Bool
    ) -> ScoreboardSnapshot? {
        guard let timer, let word = currentWord else { return nil }
        let index = matchState.currentTeamIndex
        let remaining = timer.remaining(now: now).components
        let seconds = Double(remaining.seconds) + Double(remaining.attoseconds) / 1e18

        return ScoreboardSnapshot(
            category: word.category,
            secondsRemaining: Int(seconds.rounded(.up)),
            fractionElapsed: timer.fractionElapsed(now: now),
            teamName: matchState.teams[index].displayName(index: index),
            score: matchState.teams[index].score + currentTurnScore,
            isRecording: isRecording
        )
    }
}
