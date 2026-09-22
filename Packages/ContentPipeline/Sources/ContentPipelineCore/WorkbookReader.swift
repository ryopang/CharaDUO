import Foundation

/// Reads `Multilingual_Vocabulary_1100.xlsx` at build time only (PRD §6.3 — the
/// `.xlsx` is never read at runtime). Extracts the two XML parts we need by
/// shelling out to the system `unzip`, then parses them with `XMLParser`.
public enum WorkbookReader {
    public static let expectedHeader = [
        "Category",
        "English",
        "Cantonese (Spoken Traditional)",
        "Taiwan Chinese (Traditional)",
        "Mainland Chinese (Traditional)"
    ]

    public static func readRows(fromXLSXAt path: String) throws -> [RawRow] {
        let sharedStringsData = try extract(entry: "xl/sharedStrings.xml", fromZipAt: path)
        let sheetData = try extract(entry: "xl/worksheets/sheet1.xml", fromZipAt: path)

        let sharedStrings = try SharedStringsParser().parse(data: sharedStringsData)
        let rawRows = try SheetParser(sharedStrings: sharedStrings).parse(data: sheetData)

        guard let header = rawRows.first else {
            throw PipelineError.missingSheet
        }
        let headerValues = header.map { $0 ?? "" }
        guard headerValues == expectedHeader else {
            throw PipelineError.headerMismatch(expected: expectedHeader, actual: headerValues)
        }

        var result: [RawRow] = []
        result.reserveCapacity(rawRows.count - 1)
        for (offset, row) in rawRows.dropFirst().enumerated() {
            let lineNumber = offset + 2 // 1-based, plus the header row
            guard row.count >= 5,
                  let category = row[0], let english = row[1], let cantonese = row[2],
                  let taiwanChinese = row[3], let mainlandChinese = row[4]
            else {
                throw PipelineError.incompleteRow(line: lineNumber, row: row)
            }
            result.append(RawRow(
                category: category.trimmingCharacters(in: .whitespaces),
                english: english.trimmingCharacters(in: .whitespaces),
                cantonese: cantonese.trimmingCharacters(in: .whitespaces),
                taiwanChinese: taiwanChinese.trimmingCharacters(in: .whitespaces),
                mainlandChineseTraditional: mainlandChinese.trimmingCharacters(in: .whitespaces)
            ))
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
