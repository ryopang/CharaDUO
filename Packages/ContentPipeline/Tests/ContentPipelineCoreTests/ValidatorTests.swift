import Content
import Testing
@testable import ContentPipelineCore

struct ValidatorTests {
    private func row(
        category: String = "Movie",
        english: String = "Inception",
        cantonese: String = "潛行凶間",
        taiwanChinese: String = "全面啟動",
        mainlandChinese: String = "盜夢空間"
    ) -> RawRow {
        RawRow(
            category: category,
            english: english,
            cantonese: cantonese,
            taiwanChinese: taiwanChinese,
            mainlandChineseTraditional: mainlandChinese
        )
    }

    private func validRows(count: Int, category: String) -> [RawRow] {
        (0..<count).map { row(category: category, english: "Word \($0)") }
    }

    @Test func validDatasetProducesNoIssues() {
        let rows = GameCategory.allCases.flatMap { category in
            validRows(count: Validator.minimumWordsPerCategory, category: Validator.knownCategories.first { $0.value == category }!.key)
        }
        #expect(Validator.validate(rows).isEmpty)
    }

    @Test func unknownCategoryFailsValidation() {
        let rows = [row(category: "Sport"), row(category: "Board Game", english: "Chess")]
        let issues = Validator.validate(rows)
        #expect(issues.contains { $0.description.contains("unknown category 'Board Game'") })
    }

    @Test func missingLocalizationFailsValidation() {
        let rows = [row(cantonese: "")]
        let issues = Validator.validate(rows)
        #expect(issues.contains { $0.description.contains("missing localization") })
    }

    @Test func duplicateEnglishWithinSameCategoryFailsValidation() {
        let rows = [row(category: "Movie", english: "Titanic"), row(category: "Movie", english: "Titanic")]
        let issues = Validator.validate(rows)
        #expect(issues.contains { $0.description.contains("duplicate English entry 'Titanic'") })
    }

    @Test func sameEnglishAcrossDifferentCategoriesIsAllowed() {
        let rows = [row(category: "Movie", english: "Spider-Man"), row(category: "Superhero", english: "Spider-Man")]
        let issues = Validator.validate(rows)
        #expect(!issues.contains { $0.description.contains("duplicate English entry") })
    }

    @Test func categoryBelowMinimumFailsValidation() {
        let rows = [row(category: "Movie", english: "Only One")]
        let issues = Validator.validate(rows)
        #expect(issues.contains { $0.description.contains("Category 'Movie' has 1 word(s)") })
    }
}
