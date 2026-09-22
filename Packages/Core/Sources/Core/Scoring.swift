/// PRD §2.3 — Correct = +1. Skip = 0 by default, or −1 when the Skip Penalty
/// toggle is on.
public enum Scoring {
    public static func points(for kind: RoundEventKind, skipPenaltyEnabled: Bool) -> Int {
        switch kind {
        case .correct: return 1
        case .skip: return skipPenaltyEnabled ? -1 : 0
        }
    }

    public static func totalScore(for events: [RoundEvent], skipPenaltyEnabled: Bool) -> Int {
        events.reduce(0) { $0 + points(for: $1.kind, skipPenaltyEnabled: skipPenaltyEnabled) }
    }
}
