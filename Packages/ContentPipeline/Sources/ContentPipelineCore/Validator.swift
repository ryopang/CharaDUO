import Content

public struct ValidationIssue: CustomStringConvertible, Sendable, Equatable {
    public let description: String

    public init(_ description: String) {
        self.description = description
    }
}

/// PRD §6.3: validation must fail the build on missing localizations, duplicate
/// English entries (within a category — cross-category homonyms like
/// "Spider-Man" the Movie vs. "Spider-Man" the Superhero are legitimate),
/// unknown categories, or any category below a minimum count.
public enum Validator {
    /// Source spreadsheet category label -> runtime `GameCategory`.
    public static let knownCategories: [String: GameCategory] = [
        "Movie": .movie,
        "TV Show": .tvShow,
        "Celebrity": .celebrity,
        "Animal": .animal,
        "Food": .food,
        "Country": .country,
        "Sightseeing": .sightseeing,
        "Superhero": .superhero,
        "Sport": .sport,
        "Brand": .brand
    ]

    /// PRD §6.2.3 flags 100 words/category as thin; below half that, a match
    /// can exhaust and reshuffle within a single round, so treat it as a hard
    /// data error rather than a runtime warning.
    public static let minimumWordsPerCategory = 50

    public static func validate(_ rows: [RawRow]) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        var seenPairs = Set<String>()
        var countsByCategory: [String: Int] = [:]

        for (offset, row) in rows.enumerated() {
            let lineNumber = offset + 2

            if knownCategories[row.category] == nil {
                issues.append(ValidationIssue("Row \(lineNumber): unknown category '\(row.category)'"))
            }

            let missingLanguages = ContentLanguage.allCases.filter { (row.texts[$0] ?? "").isEmpty }
            if !missingLanguages.isEmpty {
                let names = missingLanguages.map(\.sourceColumnHeader).joined(separator: ", ")
                issues.append(ValidationIssue("Row \(lineNumber): missing localization for '\(row.english)' (\(names))"))
            }

            if !row.region.isEmpty, ContentRegion(rawValue: row.region.lowercased()) == nil {
                issues.append(ValidationIssue("Row \(lineNumber): unknown region '\(row.region)' for '\(row.english)'"))
            }

            let pairKey = "\(row.category)\u{0}\(row.english)"
            if !seenPairs.insert(pairKey).inserted {
                issues.append(ValidationIssue("Row \(lineNumber): duplicate English entry '\(row.english)' in category '\(row.category)'"))
            }

            countsByCategory[row.category, default: 0] += 1
        }

        for category in knownCategories.keys.sorted() {
            let count = countsByCategory[category] ?? 0
            if count < minimumWordsPerCategory {
                issues.append(ValidationIssue("Category '\(category)' has \(count) word(s), below the minimum of \(minimumWordsPerCategory)"))
            }
        }

        return issues
    }
}
