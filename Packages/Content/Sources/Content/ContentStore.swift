import Foundation

public enum ContentStoreError: Error {
    case bundledResourceMissing
}

extension Foundation.Bundle {
    /// Re-exposes the package-internal `.module` accessor publicly so it can
    /// be used as a default argument value from outside this module.
    public static var content: Bundle { .module }
}

/// Read-only, in-memory word bank decoded from the bundled `vocabulary.json`
/// (PRD §6.4). The `.xlsx` source is never read at runtime.
public struct ContentStore: Sendable {
    public let packs: [ContentPack]

    public init(packs: [ContentPack]) {
        self.packs = packs
    }

    public static func loadBundled(
        from bundle: Bundle = .content,
        entitlementStore: ContentEntitlementStore = AlwaysUnlocked()
    ) throws -> ContentStore {
        guard let url = bundle.url(forResource: "vocabulary", withExtension: "json") else {
            throw ContentStoreError.bundledResourceMissing
        }
        let data = try Data(contentsOf: url)
        let packs = try JSONDecoder().decode([ContentPack].self, from: data)
            .filter { entitlementStore.isUnlocked(packID: $0.packID) }
        return ContentStore(packs: packs)
    }

    public var allWords: [GameWord] {
        packs.flatMap(\.words)
    }

    public func words(in categories: Set<GameCategory>) -> [GameWord] {
        allWords.filter { categories.contains($0.category) }
    }

    public func localizedText(for word: GameWord, language: ContentLanguage) -> String? {
        word.localizations[language]
    }
}
