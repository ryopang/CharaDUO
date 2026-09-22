import Foundation

/// Parses a worksheet XML part (`xl/worksheets/sheet1.xml`) into rows of
/// nullable string values, resolving shared-string cells (`t="s"`) against the
/// index built by `SharedStringsParser`. Cell placement is derived from the
/// `r` attribute (e.g. "C5" → column index 2) rather than assumed sequential
/// order, so a row with gaps still lands its values in the right column.
final class SheetParser: NSObject, XMLParserDelegate {
    private let sharedStrings: [String]
    private var rows: [[String?]] = []
    private var currentRow: [String?] = []
    private var currentCellIndex: Int?
    private var currentCellType: String?
    private var currentValue = ""
    private var capturingValue = false
    private var parseError: Error?

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parse(data: Data) throws -> [[String?]] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw PipelineError.xmlParsingFailed(entry: "xl/worksheets/sheet1.xml", underlying: parseError ?? parser.parserError)
        }
        return rows
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "row":
            currentRow = []
        case "c":
            currentCellType = attributeDict["t"]
            if let ref = attributeDict["r"] {
                currentCellIndex = Self.columnIndex(fromCellReference: ref)
            } else {
                currentCellIndex = currentRow.count
            }
        case "v", "t":
            capturingValue = true
            currentValue = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturingValue {
            currentValue += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "v", "t":
            capturingValue = false
        case "c":
            guard let index = currentCellIndex else { return }
            while currentRow.count <= index {
                currentRow.append(nil)
            }
            if currentCellType == "s", let sharedIndex = Int(currentValue) {
                currentRow[index] = sharedIndex < sharedStrings.count ? sharedStrings[sharedIndex] : nil
            } else if !currentValue.isEmpty {
                currentRow[index] = currentValue
            }
            currentCellIndex = nil
            currentCellType = nil
        case "row":
            rows.append(currentRow)
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }

    /// "A1" -> 0, "B1" -> 1, "AA1" -> 26, etc.
    static func columnIndex(fromCellReference ref: String) -> Int {
        var index = 0
        for scalar in ref.unicodeScalars {
            guard scalar.isASCII, ("A"..."Z").contains(Character(scalar)) else { break }
            index = index * 26 + Int(scalar.value - Unicode.Scalar("A").value) + 1
        }
        return max(index - 1, 0)
    }
}
