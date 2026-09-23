import Content

/// PRD §2.2 / §2.4. Quick Play constructs this with all defaults: 2 teams,
/// all 10 categories, 60s, 3 rounds, last-used language.
public struct MatchConfiguration: Sendable, Equatable {
    public var teams: [Team]
    public var roundsPerTeam: Int
    public var roundDuration: RoundDuration
    public var categories: Set<GameCategory>
    public var language: ContentLanguage
    public var skipPenaltyEnabled: Bool

    public init(
        teams: [Team] = [Team(), Team()],
        roundsPerTeam: Int = 3,
        roundDuration: RoundDuration = .default,
        categories: Set<GameCategory> = Set(GameCategory.allCases),
        language: ContentLanguage = .english,
        skipPenaltyEnabled: Bool = false
    ) {
        precondition((1...4).contains(teams.count), "PRD §2.2: 1–4 teams")
        precondition((1...5).contains(roundsPerTeam), "PRD §2.2: 1–5 rounds per team")
        precondition(!categories.isEmpty, "at least one category must be selected")
        self.teams = teams
        self.roundsPerTeam = roundsPerTeam
        self.roundDuration = roundDuration
        self.categories = categories
        self.language = language
        self.skipPenaltyEnabled = skipPenaltyEnabled
    }
}
