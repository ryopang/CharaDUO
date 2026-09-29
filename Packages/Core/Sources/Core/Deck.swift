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
    /// Share of draws taken from the favored region's words while both the
    /// favored and the other pool still have cards (the 70/30 rule).
    public static let defaultFavoredShare = 0.7

    private let allWords: [GameWord]
    private let favoredRegion: ContentRegion?
    private let favoredShare: Double
    private var upcomingFavored: [GameWord] = []
    private var upcomingOther: [GameWord] = []
    private var usedThisRound: Set<GameWord.ID> = []
    private var generator: SeededGenerator

    /// `favoredRegion` biases which words come up: with both kinds available,
    /// `favoredShare` of draws are words tagged with that region and the rest
    /// come from everything else. Nil (or a category mix with no tagged
    /// words) means a plain uniform shuffle. Either way, no word repeats
    /// until the deck runs dry.
    public init(
        words: [GameWord],
        seed: UInt64 = .random(in: .min ... .max),
        favoredRegion: ContentRegion? = nil,
        favoredShare: Double = Deck.defaultFavoredShare
    ) throws {
        guard !words.isEmpty else { throw DeckError.noWordsAvailable }
        self.allWords = words
        self.favoredRegion = favoredRegion
        self.favoredShare = favoredShare
        self.generator = SeededGenerator(seed: seed)
        refill(from: words)
    }

    public mutating func startRound() {
        usedThisRound.removeAll()
    }

    public mutating func draw() -> DeckDraw {
        var reshuffled = false
        if upcomingFavored.isEmpty && upcomingOther.isEmpty {
            let unusedThisRound = allWords.filter { !usedThisRound.contains($0.id) }
            refill(from: unusedThisRound.isEmpty ? allWords : unusedThisRound)
            reshuffled = true
        }

        let takeFavored: Bool
        if upcomingFavored.isEmpty {
            takeFavored = false
        } else if upcomingOther.isEmpty {
            takeFavored = true
        } else {
            takeFavored = Double.random(in: 0..<1, using: &generator) < favoredShare
        }

        let word = takeFavored ? upcomingFavored.removeLast() : upcomingOther.removeLast()
        usedThisRound.insert(word.id)
        return DeckDraw(word: word, reshuffled: reshuffled)
    }

    private mutating func refill(from pool: [GameWord]) {
        let shuffled = pool.shuffled(using: &generator)
        guard let favoredRegion else {
            upcomingFavored = []
            upcomingOther = shuffled
            return
        }
        upcomingFavored = shuffled.filter { $0.region == favoredRegion }
        upcomingOther = shuffled.filter { $0.region != favoredRegion }
    }
}
