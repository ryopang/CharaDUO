import Content
import Foundation

/// The read-only projection the round-summary screen renders — on the inner
/// screen and, since the outer display now stays lit through round summary,
/// on the accessory scene too (both build from this one snapshot so they
/// show exactly the same thing).
public struct RoundSummarySnapshot: Sendable, Equatable {
    public let teamName: String
    public let correctThisRound: Int
    public let totalCorrectForGame: Int
    /// The single category this round drew from, or nil when the match spans
    /// more than one category (a Custom Game can select several).
    public let categoryLabel: GameCategory?
    public let correctWords: [GameWord]
    public let skippedWords: [GameWord]
    public let language: ContentLanguage
    public let isMatchComplete: Bool

    public init(
        teamName: String,
        correctThisRound: Int,
        totalCorrectForGame: Int,
        categoryLabel: GameCategory?,
        correctWords: [GameWord],
        skippedWords: [GameWord],
        language: ContentLanguage,
        isMatchComplete: Bool
    ) {
        self.teamName = teamName
        self.correctThisRound = correctThisRound
        self.totalCorrectForGame = totalCorrectForGame
        self.categoryLabel = categoryLabel
        self.correctWords = correctWords
        self.skippedWords = skippedWords
        self.language = language
        self.isMatchComplete = isMatchComplete
    }
}

extension GameEngine {
    /// Builds the round-summary projection for a just-ended turn. `result`
    /// must already be folded into `matchState` (i.e. called after
    /// `endTurn()`), since "total correct answers for the game" sums across
    /// `matchState.completedTurns`, which only includes this turn once
    /// `endTurn()` has recorded it.
    public func roundSummarySnapshot(for result: TurnResult) -> RoundSummarySnapshot {
        let team = matchState.teams[result.teamIndex]
        let correctThisRound = result.events.filter { $0.kind == .correct }.count
        let totalCorrectForGame = matchState.completedTurns
            .filter { $0.teamIndex == result.teamIndex }
            .flatMap(\.events)
            .filter { $0.kind == .correct }
            .count
        let categoryLabel = configuration.categories.count == 1 ? configuration.categories.first : nil

        return RoundSummarySnapshot(
            teamName: team.displayName(index: result.teamIndex),
            correctThisRound: correctThisRound,
            totalCorrectForGame: totalCorrectForGame,
            categoryLabel: categoryLabel,
            correctWords: result.events.filter { $0.kind == .correct }.map(\.word),
            skippedWords: result.events.filter { $0.kind == .skip }.map(\.word),
            language: configuration.language,
            isMatchComplete: matchState.isMatchComplete
        )
    }
}
