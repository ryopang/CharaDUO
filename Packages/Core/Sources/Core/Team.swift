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

    public func displayName(index: Int) -> String {
        if let name, !name.isEmpty {
            return name
        }
        return "Team \(index + 1)"
    }
}
