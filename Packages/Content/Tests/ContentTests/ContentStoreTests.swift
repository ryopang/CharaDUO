import Testing
@testable import Content

struct ContentStoreTests {
    private func loadStore() throws -> ContentStore {
        try ContentStore.loadBundled()
    }

    @Test func loadsAllWordsAcrossEveryCategory() throws {
        let store = try loadStore()
        #expect(store.allWords.count == 1394)
        #expect(Set(store.allWords.map(\.category)).count == GameCategory.allCases.count)
    }

    @Test func eachCategoryMatchesTheSourceSpreadsheetCounts() throws {
        let store = try loadStore()
        let expectedCounts: [GameCategory: Int] = [
            .movie: 228, .tvShow: 230, .celebrity: 125, .animal: 100,
            .food: 128, .country: 100, .sightseeing: 123, .superhero: 124, .sport: 116, .brand: 120
        ]
        for (category, expected) in expectedCounts {
            #expect(store.words(in: [category]).count == expected)
        }
    }

    @Test func everyWordHasEveryLanguageLocalization() throws {
        let store = try loadStore()
        for word in store.allWords {
            for language in ContentLanguage.allCases {
                let text = store.localizedText(for: word, language: language)
                #expect(text?.isEmpty == false, "\(word.id) missing \(language)")
            }
        }
    }

    @Test func everyLanguageHasWordsFromItsHomeRegion() throws {
        let store = try loadStore()
        for language in ContentLanguage.allCases {
            guard let region = language.homeRegion else { continue }
            #expect(store.allWords.filter { $0.region == region }.count >= 30, "\(language) has too few \(region) words")
        }
    }

    @Test func everyWordHasAUniqueID() throws {
        let store = try loadStore()
        let ids = store.allWords.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func loadingIsDeterministicAcrossCalls() throws {
        let first = try loadStore().allWords.map(\.id).sorted()
        let second = try loadStore().allWords.map(\.id).sorted()
        #expect(first == second)
    }

    @Test func entitlementStoreFiltersUnlockedPacks() throws {
        struct LockAll: ContentEntitlementStore {
            func isUnlocked(packID: String) -> Bool { false }
        }
        let store = try ContentStore.loadBundled(entitlementStore: LockAll())
        #expect(store.allWords.isEmpty)
    }
}
