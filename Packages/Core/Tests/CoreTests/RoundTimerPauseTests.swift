import Content
import Foundation
import Testing
@testable import Core

/// PRD §3.1 — folding shut pauses the match. The timer still stores instants
/// and a duration, never a remaining count (§10.3), so pausing freezes the
/// elapsed reference and resuming shifts the start instant forward.
struct RoundTimerPauseTests {
    @Test func pausingFreezesElapsedTime() {
        var timer = RoundTimer(duration: .seconds(60))
        let pauseInstant = timer.startInstant.advanced(by: .seconds(20))
        timer.pause(at: pauseInstant)

        #expect(timer.isPaused)
        // Time keeps passing in the real world; elapsed must not.
        let muchLater = timer.startInstant.advanced(by: .seconds(300))
        #expect(timer.elapsed(now: muchLater) == .seconds(20))
        #expect(timer.remaining(now: muchLater) == .seconds(40))
        #expect(timer.isExpired(now: muchLater) == false)
    }

    @Test func resumingContinuesFromWhereItFroze() {
        var timer = RoundTimer(duration: .seconds(60))
        timer.pause(at: timer.startInstant.advanced(by: .seconds(20)))
        // Paused for five minutes while the device sat folded shut.
        timer.resume(at: timer.startInstant.advanced(by: .seconds(320)))

        #expect(!timer.isPaused)
        // 20s had elapsed before the pause, so 10s later reads 30s elapsed.
        let now = timer.startInstant.advanced(by: .seconds(30))
        #expect(timer.elapsed(now: now) == .seconds(30))
        #expect(timer.remaining(now: now) == .seconds(30))
    }

    @Test func pausingTwiceKeepsTheFirstPauseInstant() {
        var timer = RoundTimer(duration: .seconds(60))
        timer.pause(at: timer.startInstant.advanced(by: .seconds(10)))
        timer.pause(at: timer.startInstant.advanced(by: .seconds(50)))

        let later = timer.startInstant.advanced(by: .seconds(200))
        #expect(timer.elapsed(now: later) == .seconds(10))
    }

    @Test func resumingWithoutPausingDoesNothing() {
        var timer = RoundTimer(duration: .seconds(60))
        let originalStart = timer.startInstant
        timer.resume(at: originalStart.advanced(by: .seconds(30)))

        #expect(!timer.isPaused)
        #expect(timer.startInstant == originalStart)
    }

    @Test func fractionElapsedAlsoFreezesWhilePaused() {
        var timer = RoundTimer(duration: .seconds(60))
        timer.pause(at: timer.startInstant.advanced(by: .seconds(30)))

        let muchLater = timer.startInstant.advanced(by: .seconds(600))
        #expect(timer.fractionElapsed(now: muchLater) == 0.5)
    }
}

@MainActor
struct GameEnginePauseTests {
    private func makeEngine() throws -> GameEngine {
        let words = (0..<10).map {
            GameWord(id: UUID(), category: .movie, localizations: [.english: "Word \($0)"])
        }
        return try GameEngine(configuration: MatchConfiguration(), words: words, seed: 5)
    }

    @Test func taponsAreIgnoredWhilePaused() throws {
        let engine = try makeEngine()
        engine.startTurn()
        engine.markCorrect()

        engine.pauseTurn()
        #expect(engine.isPaused)
        let scoreAtPause = engine.currentTurnScore

        engine.markCorrect()
        engine.markSkip()
        #expect(engine.currentTurnScore == scoreAtPause)

        engine.resumeTurn()
        engine.markCorrect()
        #expect(engine.currentTurnScore == scoreAtPause + 1)
    }
}
