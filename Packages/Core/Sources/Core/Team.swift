import Foundation

/// PRD §2.4 — team names are optional throughout; setup never blocks on text
/// entry. `displayName` supplies the "Team N" fallback used by Quick Play.
public struct Team: Sendable, Identifiable, Equatable {
    public let id: UUID
    public var name: String?
    public var score: Int

    public init(id: UUID = UUID(), name: String? = nil, score: Int = 0) {
        self.id = id
        self.name = name
        self.score = score
    }

    /// Builds the "Team N" fallback. The app swaps this for a localized
    /// version when the player's language changes; the package default keeps
    /// Core self-contained and testable.
    nonisolated(unsafe) public static var defaultName: @Sendable (Int) -> String = { "Team \($0)" }

    public func displayName(index: Int) -> String {
        if let name, !name.isEmpty {
            return name
        }
        return Team.defaultName(index + 1)
    }
}
