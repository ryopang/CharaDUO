public enum PipelineError: Error, CustomStringConvertible {
    case unzipFailed(entry: String, message: String)
    case xmlParsingFailed(entry: String, underlying: Error?)
    case missingSheet
    case headerMismatch(expected: [String], actual: [String])
    case incompleteRow(line: Int, row: [String?])
    case resourceMissing(name: String)
    case malformedConversionTable(line: String)

    public var description: String {
        switch self {
        case .unzipFailed(let entry, let message):
            return "Failed to extract '\(entry)' from the xlsx: \(message)"
        case .xmlParsingFailed(let entry, let underlying):
            return "Failed to parse XML in '\(entry)': \(underlying?.localizedDescription ?? "unknown error")"
        case .missingSheet:
            return "The workbook has no rows on the first sheet."
        case .headerMismatch(let expected, let actual):
            return "Header row mismatch.\n  expected: \(expected)\n  actual:   \(actual)"
        case .incompleteRow(let line, let row):
            return "Row \(line) is missing one or more of the 5 expected columns: \(row)"
        case .resourceMissing(let name):
            return "Missing bundled resource: \(name)"
        case .malformedConversionTable(let line):
            return "Malformed line in a Traditional→Simplified table: '\(line)'"
        }
    }
}
