import Content
import Foundation

public struct DeckDraw: Sendable, Equatable {
    public let word: GameWord
    /// True the moment the deck ran dry and had to recycle previously-used
    /// words — the caller surfaces PRD §2.3's "deck reshuffled" note on this.
    public let reshuffled: Bool
}

public enum DeckError: Error, Equatable {
    case noWordsAvailable
}

/// PRD §2.3: no word repeats within a match. Built from a shuffled pool of
/// every selected word at match start; when the pool runs dry, reshuffle
/// excluding the words already used in the *current* round (so a team never
/// immediately redraws a word it just had), recycling words from earlier
/// rounds. If even that pool is empty — the round has burned through the
/// entire deck — fall back to the full word list as a last resort rather than
/// returning nothing mid-round.
public struct Deck: Sendable {
    private let allWords: [GameWord]
    private var upcoming: [GameWord]
    private var usedThisRound: Set<GameWord.ID> = []
    private var generator: SeededGenerator

    public init(words: [GameWord], seed: UInt64 = .random(in: .min ... .max)) throws {
        guard !words.isEmpty else { throw DeckError.noWordsAvailable }
        self.allWords = words
        self.generator = SeededGenerator(seed: seed)
        self.upcoming = words.shuffled(using: &generator)
    }

    public mutating func startRound() {
        usedThisRound.removeAll()
    }

    public mutating func draw() -> DeckDraw {
        if let word = upcoming.popLast() {
            usedThisRound.insert(word.id)
            return DeckDraw(word: word, reshuffled: false)
        }

        let unusedThisRound = allWords.filter { !usedThisRound.contains($0.id) }
        let pool = unusedThisRound.isEmpty ? allWords : unusedThisRound
        upcoming = pool.shuffled(using: &generator)

        let word = upcoming.removeLast()
        usedThisRound.insert(word.id)
        return DeckDraw(word: word, reshuffled: true)
    }
}
