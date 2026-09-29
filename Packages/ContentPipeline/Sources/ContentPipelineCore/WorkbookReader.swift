import Content
import Foundation

/// Reads `Multilingual_Vocabulary.xlsx` at build time only (PRD §6.3 — the
/// `.xlsx` is never read at runtime). Extracts the two XML parts we need by
/// shelling out to the system `unzip`, then parses them with `XMLParser`.
public enum WorkbookReader {
    /// Columns are found by header name, so their order — and any extra
    /// columns — don't matter. Every language column is required; `Region`
    /// is optional.
    public static func readRows(fromXLSXAt path: String) throws -> [RawRow] {
        let sheetData = try extract(entry: "xl/worksheets/sheet1.xml", fromZipAt: path)

        // Excel writes a shared-strings part; some writers (openpyxl) inline
        // every string instead, so the part is optional.
        let sharedStrings = try (try? extract(entry: "xl/sharedStrings.xml", fromZipAt: path))
            .map { try SharedStringsParser().parse(data: $0) } ?? []
        let rawRows = try SheetParser(sharedStrings: sharedStrings).parse(data: sheetData)

        guard let header = rawRows.first else {
            throw PipelineError.missingSheet
        }
        let headerValues = header.map { ($0 ?? "").trimmingCharacters(in: .whitespaces) }

        let required = [RawRow.categoryHeader] + ContentLanguage.allCases.map(\.sourceColumnHeader)
        let missing = required.filter { !headerValues.contains($0) }
        guard missing.isEmpty else {
            throw PipelineError.headerMismatch(expected: required, actual: headerValues)
        }
        let categoryColumn = headerValues.firstIndex(of: RawRow.categoryHeader)!
        let languageColumns = ContentLanguage.allCases.map { ($0, headerValues.firstIndex(of: $0.sourceColumnHeader)!) }
        let regionColumn = headerValues.firstIndex(of: RawRow.regionHeader)

        func cell(_ row: [String?], _ column: Int?) -> String? {
            guard let column, column < row.count else { return nil }
            return row[column]?.trimmingCharacters(in: .whitespaces)
        }

        var result: [RawRow] = []
        result.reserveCapacity(rawRows.count - 1)
        for (offset, row) in rawRows.dropFirst().enumerated() {
            let lineNumber = offset + 2 // 1-based, plus the header row
            guard let category = cell(row, categoryColumn), !category.isEmpty,
                  let english = cell(row, languageColumns.first { $0.0 == .english }?.1), !english.isEmpty
            else {
                throw PipelineError.incompleteRow(line: lineNumber, row: row)
            }
            // A blank translation is kept as "" so the validator can name the
            // row and language instead of the reader aborting on the first gap.
            var texts: [ContentLanguage: String] = [:]
            for (language, column) in languageColumns {
                texts[language] = cell(row, column) ?? ""
            }
            result.append(RawRow(category: category, texts: texts, region: cell(row, regionColumn) ?? ""))
        }
        return result
    }

    private static func extract(entry: String, fromZipAt path: String) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", path, entry]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8) ?? "unzip exited with status \(process.terminationStatus)"
            throw PipelineError.unzipFailed(entry: entry, message: message)
        }
        return outputData
    }
}
