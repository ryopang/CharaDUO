import Content
import Foundation
import Testing
@testable import Core

struct ScoringTests {
    private let word = GameWord(id: UUID(), category: .movie, localizations: [.english: "Inception"])

    @Test func correctIsAlwaysPlusOne() {
        #expect(Scoring.points(for: .correct, skipPenaltyEnabled: false) == 1)
        #expect(Scoring.points(for: .correct, skipPenaltyEnabled: true) == 1)
    }

    @Test func skipIsZeroByDefault() {
        #expect(Scoring.points(for: .skip, skipPenaltyEnabled: false) == 0)
    }

    @Test func skipIsMinusOneWhenPenaltyEnabled() {
        #expect(Scoring.points(for: .skip, skipPenaltyEnabled: true) == -1)
    }

    @Test func totalScoreSumsAllEvents() {
        let events = [
            RoundEvent(word: word, kind: .correct),
            RoundEvent(word: word, kind: .correct),
            RoundEvent(word: word, kind: .skip)
        ]
        #expect(Scoring.totalScore(for: events, skipPenaltyEnabled: false) == 2)
        #expect(Scoring.totalScore(for: events, skipPenaltyEnabled: true) == 1)
    }

    @Test func totalScoreOfNoEventsIsZero() {
        #expect(Scoring.totalScore(for: [], skipPenaltyEnabled: true) == 0)
    }
}
