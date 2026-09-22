import Foundation

/// PRD §2.2 — fixed rounds: turns proceed round-robin (round 0: every team
/// once, round 1: every team once, ...) until each team has described
/// `roundsPerTeam` times. Running score carries across rounds.
public struct MatchState: Sendable {
    public let configuration: MatchConfiguration
    public private(set) var teams: [Team]
    public private(set) var completedTurns: [TurnResult] = []
    public private(set) var turnNumber: Int = 0

    public init(configuration: MatchConfiguration) {
        self.configuration = configuration
        self.teams = configuration.teams
    }

    public var totalTurns: Int {
        configuration.roundsPerTeam * teams.count
    }

    public var isMatchComplete: Bool {
        turnNumber >= totalTurns
    }

    public var currentTeamIndex: Int {
        teams.isEmpty ? 0 : turnNumber % teams.count
    }

    public var currentRoundIndex: Int {
        teams.isEmpty ? 0 : turnNumber / teams.count
    }

    public mutating func recordTurn(_ result: TurnResult) {
        precondition(!isMatchComplete, "recordTurn called after the match already completed")
        precondition(result.teamIndex == currentTeamIndex, "turn recorded for the wrong team")
        teams[currentTeamIndex].score += result.score
        completedTurns.append(result)
        turnNumber += 1
    }

    /// Every team tied for the highest score — usually one, occasionally more.
    public var winningTeams: [Team] {
        guard let maxScore = teams.map(\.score).max() else { return [] }
        return teams.filter { $0.score == maxScore }
    }
}
