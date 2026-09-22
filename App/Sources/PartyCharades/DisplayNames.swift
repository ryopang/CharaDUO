import Content

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
