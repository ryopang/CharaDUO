/// The 9 built-in categories, per the source vocabulary spreadsheet (PRD §6.1).
public enum GameCategory: String, Codable, CaseIterable, Sendable, Hashable {
    case movie
    case tvShow
    case celebrity
    case animal
    case food
    case country
    case sightseeing
    case superhero
    case sport
}
