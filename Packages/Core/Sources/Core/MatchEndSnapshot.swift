import Foundation

/// The read-only projection the Game Over screen renders, mirrored onto the
/// outer display alongside the inner screen.
public struct MatchEndSnapshot: Sendable, Equatable {
    public let teams: [Team]
    public let winners: [Team]

    public init(teams: [Team], winners: [Team]) {
        self.teams = teams
        self.winners = winners
    }
}

extension MatchState {
    public var matchEndSnapshot: MatchEndSnapshot {
        MatchEndSnapshot(teams: teams, winners: winningTeams)
    }
}
