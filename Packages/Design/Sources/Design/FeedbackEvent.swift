/// PRD §10.4 — every point where the game gives feedback, and which channels
/// carry it. Kept as pure data (no UIKit/AVFoundation dependency) so the
/// mapping itself is unit-testable; the App layer's `FeedbackPlayer` is what
/// actually calls `UIImpactFeedbackGenerator` etc.
public enum FeedbackEvent: Sendable, Equatable, CaseIterable {
    case correct
    case skip
    /// Fires once per second for the last 10 seconds of a round, escalating.
    case finalCountdownTick(secondsRemaining: Int)

    public static var allCases: [FeedbackEvent] {
        [.correct, .skip, .finalCountdownTick(secondsRemaining: 10)]
    }
}

public enum HapticStyle: Sendable, Equatable {
    case impactHeavy
    case notificationError
    /// Intensity climbs as `secondsRemaining` counts down to 1 — "escalating"
    /// per §10.4, not a flat repeated tick.
    case escalatingTick(secondsRemaining: Int)
}

public enum ChimeStyle: Sendable, Equatable {
    case ascending
    case lowBuzz
    case tick
}

extension FeedbackEvent {
    /// PRD §10.4 — "Correct: heavy impact + ascending chime. Skip: error
    /// notification + low buzz." Correct/Skip are never colour-only — this
    /// pairing with position (§2.1) is the differentiator.
    public var haptic: HapticStyle {
        switch self {
        case .correct: return .impactHeavy
        case .skip: return .notificationError
        case .finalCountdownTick(let seconds): return .escalatingTick(secondsRemaining: seconds)
        }
    }

    public var chime: ChimeStyle {
        switch self {
        case .correct: return .ascending
        case .skip: return .lowBuzz
        case .finalCountdownTick: return .tick
        }
    }
}
