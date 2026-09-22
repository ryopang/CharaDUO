import Content
import Foundation
import Testing
@testable import Core

@MainActor
struct GameEngineTests {
    private func words(_ count: Int) -> [GameWord] {
        (0..<count).map { GameWord(id: UUID(), category: .movie, localizations: [.english: "Word \($0)"]) }
    }

    private func makeEngine(teams: Int = 2, roundsPerTeam: Int = 1, wordCount: Int = 20, skipPenaltyEnabled: Bool = false) throws -> GameEngine {
        let config = MatchConfiguration(
            teams: (0..<teams).map { _ in Team() },
            roundsPerTeam: roundsPerTeam,
            skipPenaltyEnabled: skipPenaltyEnabled
        )
        return try GameEngine(configuration: config, words: words(wordCount), seed: 123)
    }

    @Test func startTurnDrawsAFirstWordAndStartsTheTimer() throws {
        let engine = try makeEngine()
        #expect(engine.currentWord == nil)
        #expect(engine.timer == nil)

        engine.startTurn()
        #expect(engine.currentWord != nil)
        #expect(engine.timer != nil)
    }

    @Test func markCorrectAdvancesToANewWordAndRecordsAnEvent() throws {
        let engine = try makeEngine()
        engine.startTurn()
        let first = engine.currentWord
        engine.markCorrect()
        #expect(engine.currentWord != nil)
        #expect(engine.currentWord != first)
    }

    @Test func endTurnScoresAndFoldsIntoMatchState() throws {
        let engine = try makeEngine()
        engine.startTurn()
        engine.markCorrect()
        engine.markCorrect()
        engine.markSkip()

        let result = engine.endTurn()
        #expect(result.score == 2) // 2 correct, 1 skip at 0 penalty
        #expect(result.events.count == 3)
        #expect(engine.matchState.teams[0].score == 2)
        #expect(engine.currentWord == nil)
        #expect(engine.timer == nil)
    }

    @Test func skipPenaltyAffectsEndTurnScore() throws {
        let engine = try makeEngine(skipPenaltyEnabled: true)
        engine.startTurn()
        engine.markCorrect()
        engine.markSkip()
        let result = engine.endTurn()
        #expect(result.score == 0) // +1 correct, -1 skip
    }

    @Test func matchAdvancesThroughAllTurnsRoundRobin() throws {
        let engine = try makeEngine(teams: 3, roundsPerTeam: 2)
        for _ in 0..<6 {
            #expect(engine.matchState.isMatchComplete == false)
            engine.startTurn()
            engine.markCorrect()
            engine.endTurn()
        }
        #expect(engine.matchState.isMatchComplete)
    }

    @Test func eventsBeforeStartTurnAreIgnored() throws {
        let engine = try makeEngine()
        engine.markCorrect() // no turn in progress — must be a no-op
        #expect(engine.currentWord == nil)
    }

    @Test func initThrowsWhenGivenNoWords() throws {
        let config = MatchConfiguration()
        #expect(throws: DeckError.noWordsAvailable) {
            _ = try GameEngine(configuration: config, words: [])
        }
    }
}
