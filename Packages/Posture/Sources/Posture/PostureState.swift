/// PRD §3.1. Deliberately derived from the hinge alone — the draft's
/// gyroscope/accelerometer posture detection was investigated and rejected
/// (CLAUDE.md), so there is no "device roughly level" term here.
public enum PostureState: Sendable, Equatable {
    /// Hinge partially open within the tabletop band — the full two-sided
    /// experience.
    case tabletop
    /// Fully open (~180°), or partially open outside the tabletop band.
    /// Single-screen layout; still completely playable.
    case flat
    /// Folded shut. The only posture that pauses a match.
    case closed
    /// No hinge context at all: a non-Duo iPhone, or an OS below the 27.1
    /// that the hinge APIs require. Single-screen pass-the-phone mode.
    case noHinge
}

/// A local mirror of `DeviceHinge.Status`, which is only available on
/// iOS 27.1+ and cannot be constructed in tests or on macOS. Bridging to it
/// happens in the iOS-only glue; this keeps posture resolution pure and
/// unit-testable everywhere.
public enum HingeStatusKind: Sendable, Equatable {
    case closed
    case partiallyOpen
    case fullyOpen
    /// A status the SDK reports that we don't recognise. `Status` is a struct
    /// with static members, not an enum, so new values can appear without a
    /// compile error — treat them as "no usable hinge" rather than guessing.
    case unknown
}

public enum PostureResolver {
    /// PRD §3.1 — tabletop is ≈75–115°.
    public static let tabletopAngleRange: ClosedRange<Double> = 75...115

    public static func resolve(status: HingeStatusKind, angleDegrees: Double) -> PostureState {
        switch status {
        case .closed:
            return .closed
        case .fullyOpen:
            return .flat
        case .partiallyOpen:
            // Partially open but not at a tabletop angle (say 40°) is neither
            // tabletop nor literally flat. Single-screen is the always-playable
            // layout, so degrade to it rather than inventing a third mode.
            return tabletopAngleRange.contains(angleDegrees) ? .tabletop : .flat
        case .unknown:
            return .noHinge
        }
    }
}
