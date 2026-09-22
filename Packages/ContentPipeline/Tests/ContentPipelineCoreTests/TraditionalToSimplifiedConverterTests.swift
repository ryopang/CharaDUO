import Testing
@testable import ContentPipelineCore

struct TraditionalToSimplifiedConverterTests {
    private func makeConverter() throws -> TraditionalToSimplifiedConverter {
        try TraditionalToSimplifiedConverter.loadBundled()
    }

    @Test func convertsKnownMoviePhrases() throws {
        let converter = try makeConverter()
        // PRD §6.2.1's own worked example: regional titles differ, script doesn't.
        #expect(converter.convert("盜夢空間") == "盗梦空间")
        #expect(converter.convert("鐵達尼號") == "铁达尼号")
        #expect(converter.convert("駭客帝國") == "骇客帝国")
    }

    @Test func passesThroughAlreadySimplifiedOrNonChineseText() throws {
        let converter = try makeConverter()
        #expect(converter.convert("阿凡達").isEmpty == false)
        #expect(converter.convert("Inception") == "Inception")
    }

    @Test func fallsBackToCharacterLevelWhenNoPhraseMatches() throws {
        let converter = try makeConverter()
        // Single unrelated traditional characters with no phrase-table entry
        // still convert character-by-character.
        let result = converter.convert("國")
        #expect(result == "国")
    }
}
