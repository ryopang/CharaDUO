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
// (.xcstrings) following system language — hardcoded here for M3 and due for
// that move during M7 polish & a11y.

extension GameCategory {
    var displayName: String {
        switch self {
        case .movie: return "Movie"
        case .tvShow: return "TV Show"
        case .celebrity: return "Celebrity"
        case .animal: return "Animal"
        case .food: return "Food"
        case .country: return "Country"
        case .sightseeing: return "Sightseeing"
        case .superhero: return "Superhero"
        case .sport: return "Sport"
        }
    }
}

extension ContentLanguage {
    var displayName: String {
        switch self {
        case .english: return "English"
        case .cantonese: return "Cantonese"
        case .taiwanChinese: return "Taiwan Chinese"
        case .mainlandChinese: return "Mainland Chinese"
        }
    }
}
