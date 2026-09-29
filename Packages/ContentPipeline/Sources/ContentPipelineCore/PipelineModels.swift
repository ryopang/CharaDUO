import Content

/// The spreadsheet column that holds each language's text. Exhaustive on
/// purpose: adding a `ContentLanguage` case fails to compile here until its
/// column is named, so a new language can't be silently skipped.
extension ContentLanguage {
    public var sourceColumnHeader: String {
        switch self {
        case .english: return "English"
        case .cantonese: return "Cantonese (Spoken Traditional)"
        case .taiwanChinese: return "Taiwan Chinese (Traditional)"
        case .mainlandChinese: return "Mainland Chinese (Traditional)"
        case .japanese: return "Japanese"
        }
    }
}

/// One data row exactly as read from the source spreadsheet, before validation
/// or script conversion. `texts` holds every language as written in the sheet
/// (Mainland is still Traditional script — the converter runs later).
public struct RawRow: Sendable, Equatable {
    public static let categoryHeader = "Category"
    /// Optional column; blank means a global word.
    public static let regionHeader = "Region"

    public let category: String
    public let texts: [ContentLanguage: String]
    public let region: String

    public var english: String { texts[.english] ?? "" }

    public init(category: String, texts: [ContentLanguage: String], region: String = "") {
        self.category = category
        self.texts = texts
        self.region = region
    }
}
