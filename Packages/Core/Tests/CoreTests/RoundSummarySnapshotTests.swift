import Content
import Foundation
import Testing
@testable import Core

@MainActor
struct RoundSummarySnapshotTests {
    private func words(_ count: Int, category: GameCategory = .movie) -> [GameWord] {
        (0..<count).map { GameWord(id: UUID(), category: category, localizations: [.english: "Word \($0)"]) }
    }

    private func makeEngine(teams: Int = 2, roundsPerTeam: Int = 2, categories: Set<GameCategory> = [.movie]) throws -> GameEngine {
        let config = MatchConfiguration(
            teams: (0..<teams).map { _ in Team() },
            roundsPerTeam: roundsPerTeam,
            categories: categories
        )
        return try GameEngine(configuration: config, words: words(20, category: categories.first ?? .movie), seed: 42)
    }

    @Test func summarizesCorrectAndSkippedWordsForTheJustEndedTurn() throws {
        let engine = try makeEngine()
        engine.startTurn()
        engine.markCorrect()
        engine.markCorrect()
        engine.markSkip()
        let result = engine.endTurn()

        let snapshot = engine.roundSummarySnapshot(for: result)
        #expect(snapshot.teamName == "Team 1")
        #expect(snapshot.correctThisRound == 2)
        #expect(snapshot.correctWords.count == 2)
        #expect(snapshot.skippedWords.count == 1)
        #expect(snapshot.categoryLabel == .movie)
        #expect(snapshot.isMatchComplete == false)
    }

    @Test func totalCorrectForGameSumsAcrossCompletedTurnsForThatTeam() throws {
        let engine = try makeEngine(teams: 1, roundsPerTeam: 2)
        engine.startTurn()
        engine.markCorrect()
        let firstResult = engine.endTurn()
        #expect(engine.roundSummarySnapshot(for: firstResult).totalCorrectForGame == 1)

        engine.startTurn()
        engine.markCorrect()
        engine.markCorrect()
        let secondResult = engine.endTurn()
        // Second turn's own 2 correct, plus the 1 banked from the first.
        #expect(engine.roundSummarySnapshot(for: secondResult).totalCorrectForGame == 3)
    }

    @Test func categoryLabelIsNilWhenTheMatchSpansMultipleCategories() throws {
        let engine = try makeEngine(teams: 1, categories: [.movie, .animal])
        engine.startTurn()
        engine.markCorrect()
        let result = engine.endTurn()

        #expect(engine.roundSummarySnapshot(for: result).categoryLabel == nil)
    }
}
