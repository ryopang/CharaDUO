import Content
import ContentPipelineCore
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fail("Usage: xlsx2json <input.xlsx> <output.json>")
}
let inputPath = arguments[1]
let outputPath = arguments[2]

do {
    let rows = try WorkbookReader.readRows(fromXLSXAt: inputPath)

    let issues = Validator.validate(rows)
    guard issues.isEmpty else {
        FileHandle.standardError.write("Content validation failed with \(issues.count) issue(s):\n".data(using: .utf8)!)
        for issue in issues {
            FileHandle.standardError.write("  - \(issue.description)\n".data(using: .utf8)!)
        }
        exit(1)
    }

    let converter = try TraditionalToSimplifiedConverter.loadBundled()

    let words = rows.map { row -> GameWord in
        var localizations = row.texts
        if let traditional = row.texts[.mainlandChinese] {
            localizations[.mainlandChinese] = converter.convert(traditional)
        }
        return GameWord(
            id: DeterministicID.uuid(category: row.category, english: row.english),
            category: Validator.knownCategories[row.category]!,
            localizations: localizations,
            region: ContentRegion(rawValue: row.region.lowercased())
        )
    }

    let pack = ContentPack(packID: "core", price: .free, words: words)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode([pack])
    try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)

    let categoryCount = Set(words.map(\.category)).count
    print("xlsx2json: wrote \(words.count) words across \(categoryCount) categories to \(outputPath)")
} catch {
    fail("xlsx2json failed: \(error)")
}
