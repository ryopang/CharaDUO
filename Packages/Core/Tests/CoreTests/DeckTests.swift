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
}
