import Content
import Foundation
import Testing
@testable import Core

struct DeckTests {
    private func words(_ count: Int) -> [GameWord] {
        (0..<count).map { GameWord(id: UUID(), category: .movie, localizations: [.english: "Word \($0)"]) }
    }

    @Test func initThrowsOnEmptyWordList() {
        #expect(throws: DeckError.noWordsAvailable) {
            _ = try Deck(words: [], seed: 1)
        }
    }

    @Test func drawsEveryWordExactlyOnceBeforeRepeating() throws {
        let pool = words(10)
        var deck = try Deck(words: pool, seed: 42)
        deck.startRound()

        var seen: [GameWord.ID] = []
        for _ in 0..<10 {
            let draw = deck.draw()
            #expect(draw.reshuffled == false)
            seen.append(draw.word.id)
        }
        #expect(Set(seen).count == 10)
        #expect(Set(seen) == Set(pool.map(\.id)))
    }

    @Test func reshufflesWhenPoolRunsDry() throws {
        let pool = words(5)
        var deck = try Deck(words: pool, seed: 7)
        deck.startRound()

        for _ in 0..<5 {
            let draw = deck.draw()
            #expect(draw.reshuffled == false)
        }

        // The 6th draw exhausts the initial shuffle and must reshuffle.
        let sixth = deck.draw()
        #expect(sixth.reshuffled == true)
    }

    @Test func reshuffleExcludesWordsUsedInTheCurrentRound() throws {
        // A 6-word deck where a single round draws all 6, then a 7th: the
        // 7th draw must reshuffle, and since every word was already used
        // this round, the reshuffle pool is empty and falls back to the
        // full word list — repeats become possible only once the round has
        // truly exhausted the deck, never before.
        let pool = words(6)
        var deck = try Deck(words: pool, seed: 3)
        deck.startRound()

        var reshuffleFlags: [Bool] = []
        for _ in 0..<7 {
            reshuffleFlags.append(deck.draw().reshuffled)
        }
        #expect(reshuffleFlags == [false, false, false, false, false, false, true])
    }

    @Test func startRoundResetsTheExclusionWindowNotThePool() throws {
        // Draw 3 of 5 words in round 1, then start round 2: the remaining
        // 2 undrawn words come first, and the 3 used-in-round-1 words are
        // eligible again once the pool runs dry (they were NOT used "this
        // round").
        let pool = words(5)
        var deck = try Deck(words: pool, seed: 11)
        deck.startRound()

        var round1: [GameWord.ID] = []
        for _ in 0..<3 {
            round1.append(deck.draw().word.id)
        }

        deck.startRound()
        let round2First = deck.draw()
        #expect(round2First.reshuffled == false)
        #expect(!round1.contains(round2First.word.id))
    }

    @Test func isDeterministicForAGivenSeed() throws {
        let pool = words(20)
        var deckA = try Deck(words: pool, seed: 99)
        var deckB = try Deck(words: pool, seed: 99)
        deckA.startRound()
        deckB.startRound()

        let drawsA = (0..<20).map { _ in deckA.draw().word.id }
        let drawsB = (0..<20).map { _ in deckB.draw().word.id }
        #expect(drawsA == drawsB)
    }

    // MARK: - Regional 70/30 weighting

    private func regionalPool(local: Int, other: Int) -> [GameWord] {
        (0..<local).map { GameWord(id: UUID(), category: .movie, localizations: [.english: "L\($0)"], region: .hk) }
        + (0..<other).map { GameWord(id: UUID(), category: .movie, localizations: [.english: "O\($0)"], region: $0 % 2 == 0 ? nil : .jp) }
    }

    @Test func favoredRegionGetsAboutSeventyPercentOfEarlyDraws() throws {
        var total = 0
        var local = 0
        for seed in 1...40 as ClosedRange<UInt64> {
            var deck = try Deck(words: regionalPool(local: 300, other: 300), seed: seed, favoredRegion: .hk)
            deck.startRound()
            for _ in 0..<60 {
                total += 1
                if deck.draw().word.region == .hk { local += 1 }
            }
        }
        let share = Double(local) / Double(total)
        #expect(abs(share - 0.7) < 0.04, "favored share was \(share)")
    }

    @Test func noFavoredRegionMeansUniformDraws() throws {
        var local = 0
        var total = 0
        for seed in 1...40 as ClosedRange<UInt64> {
            var deck = try Deck(words: regionalPool(local: 100, other: 300), seed: seed)
            deck.startRound()
            for _ in 0..<40 {
                total += 1
                if deck.draw().word.region == .hk { local += 1 }
            }
        }
        // 25% of the pool is HK; nothing should push that toward 70%.
        #expect(abs(Double(local) / Double(total) - 0.25) < 0.05)
    }

    @Test func regionalDeckStillNeverRepeatsBeforeExhaustion() throws {
        let pool = regionalPool(local: 6, other: 14)
        var deck = try Deck(words: pool, seed: 5, favoredRegion: .hk)
        deck.startRound()
        var seen = Set<GameWord.ID>()
        for _ in 0..<20 {
            let draw = deck.draw()
            #expect(draw.reshuffled == false)
            #expect(seen.insert(draw.word.id).inserted)
        }
        #expect(deck.draw().reshuffled == true)
    }

    @Test func favoredRegionWithNoTaggedWordsFallsBackToEverything() throws {
        var deck = try Deck(words: words(8), seed: 9, favoredRegion: .jp)
        deck.startRound()
        var seen = Set<GameWord.ID>()
        for _ in 0..<8 { seen.insert(deck.draw().word.id) }
        #expect(seen.count == 8)
    }
}
