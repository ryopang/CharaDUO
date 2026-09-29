import Foundation

/// PRD §6.4 runtime model — decoded from bundled JSON, never SwiftData/Core Data.
public struct GameWord: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let category: GameCategory
    public let localizations: [ContentLanguage: String]
    /// Optional audience tag from the spreadsheet's Region column; nil = global.
    public let region: ContentRegion?

    public init(id: UUID, category: GameCategory, localizations: [ContentLanguage: String], region: ContentRegion? = nil) {
        self.id = id
        self.category = category
        self.localizations = localizations
        self.region = region
    }
}
