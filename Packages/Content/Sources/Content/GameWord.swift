import Foundation

/// PRD §6.4 runtime model — decoded from bundled JSON, never SwiftData/Core Data.
public struct GameWord: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let category: GameCategory
    public let localizations: [ContentLanguage: String]

    public init(id: UUID, category: GameCategory, localizations: [ContentLanguage: String]) {
        self.id = id
        self.category = category
        self.localizations = localizations
    }
}
