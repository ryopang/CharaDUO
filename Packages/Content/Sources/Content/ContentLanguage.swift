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
}
