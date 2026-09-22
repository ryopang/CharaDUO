import Foundation

extension Foundation.Bundle {
    /// Re-exposes the package-internal `.module` accessor publicly so it can
    /// be used as a default argument value from outside this module.
    public static var contentPipelineCore: Bundle { .module }
}

/// Converts Traditional Chinese to Simplified using OpenCC's TSCharacters
/// (single-character) and TSPhrases (phrase-level override) tables — see
/// `Resources/ATTRIBUTION.md`. PRD §6.2.1: the Mainland column is Traditional
/// script in every row and must be converted, preserving the curated regional
/// vocabulary (盜夢空間 stays 盜夢空間, rendered Simplified as 盗梦空间).
///
/// Algorithm: greedy longest-match against the phrase table first (so proper
/// nouns convert as a unit, not character-by-character), falling back to the
/// character table for anything left over. A handful of source characters map
/// to more than one Simplified candidate (56 of 4113); we take the table's
/// first (most common) candidate, matching OpenCC's own default profile.
public struct TraditionalToSimplifiedConverter: Sendable {
    private let phrases: [String: String]
    private let characters: [Character: Character]
    private let maxPhraseLength: Int

    init(phrases: [String: String], characters: [Character: Character]) {
        self.phrases = phrases
        self.characters = characters
        self.maxPhraseLength = phrases.keys.map(\.count).max() ?? 0
    }

    public static func loadBundled(from bundle: Bundle = .contentPipelineCore) throws -> TraditionalToSimplifiedConverter {
        let characters = try loadCharacterTable(name: "TSCharacters", bundle: bundle)
        let phrases = try loadPhraseTable(name: "TSPhrases", bundle: bundle)
        return TraditionalToSimplifiedConverter(phrases: phrases, characters: characters)
    }

    public func convert(_ input: String) -> String {
        guard maxPhraseLength >= 2 else {
            return String(input.map { characters[$0] ?? $0 })
        }

        let scalars = Array(input)
        var result = ""
        result.reserveCapacity(scalars.count)
        var i = 0
        while i < scalars.count {
            var matchedLength = 0
            let upperBound = min(maxPhraseLength, scalars.count - i)
            if upperBound >= 2 {
                for length in stride(from: upperBound, through: 2, by: -1) {
                    let candidate = String(scalars[i..<(i + length)])
                    if let simplified = phrases[candidate] {
                        result += simplified
                        matchedLength = length
                        break
                    }
                }
            }
            if matchedLength > 0 {
                i += matchedLength
            } else {
                let character = scalars[i]
                result.append(characters[character] ?? character)
                i += 1
            }
        }
        return result
    }

    private static func loadCharacterTable(name: String, bundle: Bundle) throws -> [Character: Character] {
        var table: [Character: Character] = [:]
        for line in try loadLines(resource: name, bundle: bundle) {
            let columns = line.split(separator: "\t")
            guard columns.count == 2, let source = columns[0].first else {
                throw PipelineError.malformedConversionTable(line: line)
            }
            let firstCandidate = columns[1].split(separator: " ").first.flatMap { $0.first }
            guard let target = firstCandidate else {
                throw PipelineError.malformedConversionTable(line: line)
            }
            table[source] = target
        }
        return table
    }

    private static func loadPhraseTable(name: String, bundle: Bundle) throws -> [String: String] {
        var table: [String: String] = [:]
        for line in try loadLines(resource: name, bundle: bundle) {
            let columns = line.split(separator: "\t")
            guard columns.count == 2 else {
                throw PipelineError.malformedConversionTable(line: line)
            }
            let firstCandidate = columns[1].split(separator: " ").first.map(String.init)
            guard let target = firstCandidate else {
                throw PipelineError.malformedConversionTable(line: line)
            }
            table[String(columns[0])] = target
        }
        return table
    }

    private static func loadLines(resource: String, bundle: Bundle) throws -> [String] {
        guard let url = bundle.url(forResource: resource, withExtension: "txt") else {
            throw PipelineError.resourceMissing(name: "\(resource).txt")
        }
        let contents = try String(contentsOf: url, encoding: .utf8)
        return contents
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }
}
