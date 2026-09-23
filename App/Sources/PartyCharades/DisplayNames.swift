import Content
import Core
import Foundation

extension GameWord {
    /// The word as the describer should see it. English is the backstop —
    /// the build-time validator guarantees all four localizations exist, so
    /// this only ever matters if that guarantee is broken.
    func text(in language: ContentLanguage) -> String {
        localizations[language] ?? localizations[.english] ?? ""
    }
}

/// Shared by `MatchEndHeaderView` (inner) and its outer-display mirror, so
/// "Game Over" always reads the identical winner text on both surfaces.
func matchEndWinnerText(snapshot: MatchEndSnapshot) -> String {
    if snapshot.winners.count == 1, let winner = snapshot.winners.first,
       let index = snapshot.teams.firstIndex(where: { $0.id == winner.id }) {
        return "\(winner.displayName(index: index)) wins!"
    } else if snapshot.winners.count > 1 {
        return "It's a tie!"
    }
    return ""
}

extension RoundTimer {
    /// Whole seconds remaining, rounded up — PRD §3.3's "descending digits"
    /// are the primary, unambiguous channel, so 0.4s left still reads "1".
    func displaySecondsRemaining(now: ContinuousClock.Instant) -> Int {
        let components = remaining(now: now).components
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        return Int(seconds.rounded(.up))
    }
}

// UI chrome strings. Per PRD §6.5 these belong in a String Catalog
// (.xcstrings), follows system language — see App/Resources/Localizable.xcstrings.
// This is independent of `ContentLanguage`, which is the in-game word
// language the player picks explicitly (§6.5's "UI in English, words in
// Cantonese" case).

extension GameCategory {
    var displayName: String {
        switch self {
        case .movie: return String(localized: "Movie")
        case .tvShow: return String(localized: "TV Show")
        case .celebrity: return String(localized: "Celebrity")
        case .animal: return String(localized: "Animal")
        case .food: return String(localized: "Food")
        case .country: return String(localized: "Country")
        case .sightseeing: return String(localized: "Sightseeing")
        case .superhero: return String(localized: "Superhero")
        case .sport: return String(localized: "Sport")
        }
    }

    /// A single emoji per category, shown next to `displayName` wherever a
    /// category appears during setup or play — one visual identity carried
    /// through the whole flow.
    var emoji: String {
        switch self {
        case .movie: return "🎬"
        case .tvShow: return "📺"
        case .celebrity: return "🌟"
        case .animal: return "🐾"
        case .food: return "🍔"
        case .country: return "🌍"
        case .sightseeing: return "🗺️"
        case .superhero: return "🦸"
        case .sport: return "🏅"
        }
    }

    /// `"🎬 Movie"` — the emoji + name pairing used everywhere a category is
    /// shown during setup or play.
    var emojiDisplayName: String {
        "\(emoji) \(displayName)"
    }

    /// Categories sorted alphabetically by their localized display name, for
    /// the Custom Game category list.
    static var allCasesSortedAlphabetically: [GameCategory] {
        allCases.sorted { $0.displayName < $1.displayName }
    }
}

extension ContentLanguage {
    var displayName: String {
        switch self {
        case .english: return String(localized: "English")
        case .cantonese: return String(localized: "Cantonese")
        case .taiwanChinese: return String(localized: "Taiwan Chinese")
        case .mainlandChinese: return String(localized: "Mainland Chinese")
        }
    }

    /// The label shown in the Word Language picker. Deliberately **not**
    /// localized via the String Catalog — the user wants these four labels
    /// shown the same way regardless of the device's OS language, since
    /// they're naming the word variant (Hong Kong Cantonese, Taiwan
    /// Mandarin, Mainland Mandarin) rather than translating a UI string.
    var worldLabel: String {
        switch self {
        case .english: return "English"
        case .cantonese: return "香港"
        case .taiwanChinese: return "台灣"
        case .mainlandChinese: return "中国大陆"
        }
    }
}
