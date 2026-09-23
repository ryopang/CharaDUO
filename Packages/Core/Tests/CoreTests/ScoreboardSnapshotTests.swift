import Content
import Foundation
import Testing
@testable import Core

@MainActor
struct ScoreboardSnapshotTests {
    private func makeEngine(teams: Int = 2) throws -> GameEngine {
        let words = (0..<20).map {
            GameWord(id: UUID(), category: .movie, localizations: [.english: "Word \($0)"])
        }
        let config = MatchConfiguration(teams: (0..<teams).map { _ in Team() })
        return try GameEngine(configuration: config, words: words, seed: 17)
    }

    @Test func isNilBeforeATurnStarts() throws {
        let engine = try makeEngine()
        #expect(engine.scoreboardSnapshot(isRecording: false) == nil)
    }

    @Test func projectsCategoryTeamAndLiveScore() throws {
        let engine = try makeEngine()
        engine.startTurn()
        engine.markCorrect()
        engine.markCorrect()

        let snapshot = try #require(engine.scoreboardSnapshot(isRecording: true))
        #expect(snapshot.category == .movie)
        #expect(snapshot.teamName == "Team 1")
        // Live: the running total plus what this turn has earned so far.
        #expect(snapshot.score == 2)
        #expect(snapshot.isRecording)
        // "Word N" — the shape of the answer, never the answer.
        #expect(snapshot.wordShape.first == 4)
        #expect(snapshot.wordShape.count == 2)
    }

    @Test func countdownTracksTheSameClockAsTheRound() throws {
        let engine = try makeEngine()
        engine.startTurn()
        let start = try #require(engine.timer).startInstant

        let snapshot = try #require(
            engine.scoreboardSnapshot(now: start.advanced(by: .seconds(15)), isRecording: false)
        )
        #expect(snapshot.secondsRemaining == 45)
        #expect(snapshot.fractionElapsed == 0.25)
    }

    @Test func carriesEarlierRoundsIntoTheLiveScore() throws {
        let engine = try makeEngine(teams: 1)
        engine.startTurn()
        engine.markCorrect()
        engine.endTurn() // team banks 1
        engine.startTurn()
        engine.markCorrect()

        let snapshot = try #require(engine.scoreboardSnapshot(isRecording: false))
        #expect(snapshot.score == 2)
    }
}
