import Foundation
import Testing
@testable import Core

struct RoundTimerTests {
    @Test func elapsedAndRemainingTrackWallClockDeltas() {
        let timer = RoundTimer(duration: .seconds(60))
        let now = timer.startInstant.advanced(by: .seconds(25))
        #expect(timer.elapsed(now: now) == .seconds(25))
        #expect(timer.remaining(now: now) == .seconds(35))
        #expect(timer.isExpired(now: now) == false)
    }

    @Test func isExpiredAtAndAfterDuration() {
        let timer = RoundTimer(duration: .seconds(60))
        let atExpiry = timer.startInstant.advanced(by: .seconds(60))
        let pastExpiry = timer.startInstant.advanced(by: .seconds(90))
        #expect(timer.isExpired(now: atExpiry) == true)
        #expect(timer.remaining(now: atExpiry) == .zero)
        #expect(timer.isExpired(now: pastExpiry) == true)
        #expect(timer.remaining(now: pastExpiry) == .zero)
    }

    @Test func fractionElapsedInterpolatesLinearly() {
        let timer = RoundTimer(duration: .seconds(60))
        #expect(timer.fractionElapsed(now: timer.startInstant) == 0)
        #expect(timer.fractionElapsed(now: timer.startInstant.advanced(by: .seconds(30))) == 0.5)
        #expect(timer.fractionElapsed(now: timer.startInstant.advanced(by: .seconds(60))) == 1)
    }

    @Test func fractionElapsedClampsPastExpiry() {
        let timer = RoundTimer(duration: .seconds(60))
        let farPast = timer.startInstant.advanced(by: .seconds(600))
        #expect(timer.fractionElapsed(now: farPast) == 1)
    }

    /// Wall-clock deltas mean a long real-world gap (e.g. the app was
    /// backgrounded) resolves correctly on return — there's no accumulated
    /// tick count to have drifted or paused. This is the whole point of
    /// PRD §10.3's "never accumulated Timer ticks" requirement.
    @Test func survivesALongGapAsIfBackgrounded() {
        let timer = RoundTimer(duration: .seconds(60))
        let afterSimulatedBackgrounding = timer.startInstant.advanced(by: .seconds(45))
        #expect(timer.elapsed(now: afterSimulatedBackgrounding) == .seconds(45))
        #expect(timer.remaining(now: afterSimulatedBackgrounding) == .seconds(15))
    }

    @Test func negativeDeltaClampsToZeroElapsed() {
        // Defensive: `now` should never precede `startInstant`, but elapsed
        // must never go negative if it somehow does.
        let timer = RoundTimer(duration: .seconds(60))
        let before = timer.startInstant.advanced(by: .seconds(-5))
        #expect(timer.elapsed(now: before) == .zero)
        #expect(timer.remaining(now: before) == .seconds(60))
    }
}
