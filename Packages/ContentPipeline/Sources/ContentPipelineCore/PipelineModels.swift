/// One data row exactly as read from the source spreadsheet, before validation
/// or script conversion. Column order matches PRD §6.1.
public struct RawRow: Sendable, Equatable {
    public let category: String
    public let english: String
    public let cantonese: String
    public let taiwanChinese: String
    public let mainlandChineseTraditional: String

    public init(
        category: String,
        english: String,
        cantonese: String,
        taiwanChinese: String,
        mainlandChineseTraditional: String
    ) {
        self.category = category
        self.english = english
        self.cantonese = cantonese
        self.taiwanChinese = taiwanChinese
        self.mainlandChineseTraditional = mainlandChineseTraditional
    }
}
