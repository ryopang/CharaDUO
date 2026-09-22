import Foundation

/// Parses `xl/sharedStrings.xml` into an index-ordered array of strings.
/// Handles both plain `<si><t>text</t></si>` and rich-text runs
/// `<si><r><t>...</t></r>...</si>` by concatenating every `<t>` within an `<si>`.
final class SharedStringsParser: NSObject, XMLParserDelegate {
    private var strings: [String] = []
    private var currentText = ""
    private var textDepth = 0
    private var parseError: Error?

    func parse(data: Data) throws -> [String] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw PipelineError.xmlParsingFailed(entry: "xl/sharedStrings.xml", underlying: parseError ?? parser.parserError)
        }
        return strings
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "si":
            currentText = ""
        case "t":
            textDepth += 1
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if textDepth > 0 {
            currentText += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "t":
            textDepth -= 1
        case "si":
            strings.append(currentText)
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }
}
