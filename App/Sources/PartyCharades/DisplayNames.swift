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
}
