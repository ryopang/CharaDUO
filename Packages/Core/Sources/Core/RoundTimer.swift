import Foundation

/// PRD §10.3 — wall-clock deltas from `ContinuousClock`, never accumulated
/// `Timer` ticks. Persisting `startInstant` + `duration` (not a remaining
/// count) is what makes backgrounding and interruption resolve correctly on
/// return: elapsed time is always recomputed from "now", never accumulated.
public struct RoundTimer: Sendable {
    public let duration: Duration
    public let startInstant: ContinuousClock.Instant

    public init(duration: Duration, clock: ContinuousClock = ContinuousClock()) {
        self.duration = duration
        self.startInstant = clock.now
    }

    public init(duration: Duration, startInstant: ContinuousClock.Instant) {
        self.duration = duration
        self.startInstant = startInstant
    }

    public func elapsed(now: ContinuousClock.Instant) -> Duration {
        max(.zero, now - startInstant)
    }

    public func remaining(now: ContinuousClock.Instant) -> Duration {
        max(.zero, duration - elapsed(now: now))
    }

    public func isExpired(now: ContinuousClock.Instant) -> Bool {
        remaining(now: now) <= .zero
    }

    /// 0 at round start, 1 at/after expiry. Drives the countdown's urgency
    /// ramp (PRD §3.3) — computed here as a pure fraction; the colour mapping
    /// itself lives in the Design layer (M7).
    public func fractionElapsed(now: ContinuousClock.Instant) -> Double {
        guard duration > .zero else { return 1 }
        return min(1, max(0, elapsed(now: now) / duration))
    }
}
