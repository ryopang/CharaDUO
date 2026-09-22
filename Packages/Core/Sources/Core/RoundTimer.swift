import Foundation

/// PRD §10.3 — wall-clock deltas from `ContinuousClock`, never accumulated
/// `Timer` ticks. Persisting `startInstant` + `duration` (not a remaining
/// count) is what makes backgrounding and interruption resolve correctly on
/// return: elapsed time is always recomputed from "now", never accumulated.
public struct RoundTimer: Sendable {
    public let duration: Duration
    public private(set) var startInstant: ContinuousClock.Instant
    /// Set while the match is paused (PRD §3.1 — only a `.closed` fold
    /// pauses). Still an instant, never a remaining count: pausing freezes
    /// the elapsed reference, and resuming shifts `startInstant` forward by
    /// however long the pause lasted.
    public private(set) var pausedAt: ContinuousClock.Instant?

    public var isPaused: Bool { pausedAt != nil }

    public init(duration: Duration, clock: ContinuousClock = ContinuousClock()) {
        self.duration = duration
        self.startInstant = clock.now
    }

    public init(duration: Duration, startInstant: ContinuousClock.Instant) {
        self.duration = duration
        self.startInstant = startInstant
    }

    public mutating func pause(at instant: ContinuousClock.Instant) {
        guard pausedAt == nil else { return }
        pausedAt = instant
    }

    public mutating func resume(at instant: ContinuousClock.Instant) {
        guard let pausedAt else { return }
        startInstant = startInstant.advanced(by: max(.zero, instant - pausedAt))
        self.pausedAt = nil
    }

    public func elapsed(now: ContinuousClock.Instant) -> Duration {
        max(.zero, (pausedAt ?? now) - startInstant)
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
