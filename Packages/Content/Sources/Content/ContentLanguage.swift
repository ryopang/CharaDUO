/// Game-content language. Independent of UI chrome localization (String Catalog) —
/// see PRD §6.5. A player can run the UI in English and the words in Cantonese.
// `CodingKeyRepresentable` (auto-synthesized for a String-backed
// RawRepresentable enum) is what opts `Dictionary<ContentLanguage, String>`
// (as used by `GameWord.localizations`) into JSONEncoder's keyed-object path.
// Without it, the dictionary encodes as a flat alternating-element array —
// valid, but unreadable in the bundled JSON.
public enum ContentLanguage: String, Codable, CaseIterable, Sendable, Hashable, CodingKeyRepresentable {
    case english
    case cantonese
    case taiwanChinese
    case mainlandChinese
    case japanese
}

/// Where a word "comes from" — the audience it is native to. Used only to
/// weight the deck (see `Deck`); a word with no region is global.
public enum ContentRegion: String, Codable, CaseIterable, Sendable, Hashable {
    case hk, tw, cn, jp
}

extension ContentLanguage {
    /// The region whose words this language's players should see most.
    /// English has none: every word counts as equally "theirs".
    public var homeRegion: ContentRegion? {
        switch self {
        case .english: return nil
        case .cantonese: return .hk
        case .taiwanChinese: return .tw
        case .mainlandChinese: return .cn
        case .japanese: return .jp
        }
    }
}
