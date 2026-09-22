/// PRD §2.2 — Time Limit mode only in v1. 30 / 60 / 90 / 120s, default 60s.
public enum RoundDuration: Int, Sendable, Codable, CaseIterable {
    case thirtySeconds = 30
    case sixtySeconds = 60
    case ninetySeconds = 90
    case oneTwentySeconds = 120

    public static let `default` = RoundDuration.sixtySeconds

    public var duration: Duration { .seconds(rawValue) }
}
