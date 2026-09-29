import Foundation
import Testing
@testable import ContentPipelineCore

struct SheetParserTests {
    @Test func columnIndexParsesSingleAndDoubleLetterReferences() {
        #expect(SheetParser.columnIndex(fromCellReference: "A1") == 0)
        #expect(SheetParser.columnIndex(fromCellReference: "B7") == 1)
        #expect(SheetParser.columnIndex(fromCellReference: "E1100") == 4)
        #expect(SheetParser.columnIndex(fromCellReference: "AA1") == 26)
    }

    @Test func parsesSharedStringAndInlineCellsIntoRows() throws {
        let sharedStrings = try SharedStringsParser().parse(data: Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <si><t>Category</t></si>
          <si><t>Movie</t></si>
        </sst>
        """.utf8))
        #expect(sharedStrings == ["Category", "Movie"])

        let rows = try SheetParser(sharedStrings: sharedStrings).parse(data: Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            <row r="1">
              <c r="A1" t="s"><v>0</v></c>
            </row>
            <row r="2">
              <c r="A2" t="s"><v>1</v></c>
            </row>
          </sheetData>
        </worksheet>
        """.utf8))

        #expect(rows == [["Category"], ["Movie"]])
    }

    @Test func placesCellsByReferenceEvenWithGaps() throws {
        let rows = try SheetParser(sharedStrings: []).parse(data: Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            <row r="1">
              <c r="A1"><v>1</v></c>
              <c r="C1"><v>3</v></c>
            </row>
          </sheetData>
        </worksheet>
        """.utf8))

        #expect(rows == [["1", nil, "3"]])
    }

    @Test func emptyCellDoesNotInheritThePreviousCellsValue() throws {
        let rows = try SheetParser(sharedStrings: []).parse(data: Data("""
        <worksheet><sheetData><row r="1">
          <c r="A1" t="inlineStr"><is><t>Text</t></is></c>
          <c r="B1" t="inlineStr"></c>
        </row></sheetData></worksheet>
        """.utf8))
        #expect(rows == [["Text", nil]])
    }
}
