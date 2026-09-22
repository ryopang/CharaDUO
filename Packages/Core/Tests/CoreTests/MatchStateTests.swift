import Content
import Foundation
import Testing
@testable import Core

struct MatchStateTests {
    private func turn(team: Int, round: Int, score: Int) -> TurnResult {
        TurnResult(teamIndex: team, roundIndex: round, events: [], score: score, deckReshuffled: false)
    }

    @Test func turnOrderIsRoundRobinAcrossTeams() {
        let config = MatchConfiguration(teams: [Team(), Team(), Team()], roundsPerTeam: 2)
        var state = MatchState(configuration: config)

        // Round 0: team 0, 1, 2. Round 1: team 0, 1, 2.
        let expected: [(team: Int, round: Int)] = [(0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1)]
        for step in expected {
            #expect(state.currentTeamIndex == step.team)
            #expect(state.currentRoundIndex == step.round)
            state.recordTurn(turn(team: state.currentTeamIndex, round: state.currentRoundIndex, score: 1))
        }
        #expect(state.isMatchComplete)
    }

    @Test func totalTurnsIsRoundsTimesTeams() {
        let config = MatchConfiguration(teams: [Team(), Team()], roundsPerTeam: 3)
        let state = MatchState(configuration: config)
        #expect(state.totalTurns == 6)
    }

    @Test func scoreCarriesAcrossRounds() {
        let config = MatchConfiguration(teams: [Team(), Team()], roundsPerTeam: 2)
        var state = MatchState(configuration: config)

        state.recordTurn(turn(team: 0, round: 0, score: 3))
        state.recordTurn(turn(team: 1, round: 0, score: 1))
        state.recordTurn(turn(team: 0, round: 1, score: 2))
        state.recordTurn(turn(team: 1, round: 1, score: 5))

        #expect(state.teams[0].score == 5)
        #expect(state.teams[1].score == 6)
        #expect(state.isMatchComplete)
    }

    @Test func winningTeamsReturnsTheHighestScorer() {
        let config = MatchConfiguration(teams: [Team(), Team()], roundsPerTeam: 1)
        var state = MatchState(configuration: config)
        state.recordTurn(turn(team: 0, round: 0, score: 4))
        state.recordTurn(turn(team: 1, round: 0, score: 2))
        #expect(state.winningTeams.map(\.score) == [4])
    }

    @Test func winningTeamsIncludesTiesForFirst() {
        let config = MatchConfiguration(teams: [Team(), Team(), Team()], roundsPerTeam: 1)
        var state = MatchState(configuration: config)
        state.recordTurn(turn(team: 0, round: 0, score: 3))
        state.recordTurn(turn(team: 1, round: 0, score: 3))
        state.recordTurn(turn(team: 2, round: 0, score: 1))
        #expect(state.winningTeams.count == 2)
    }

    @Test func teamNamesAreOptionalWithNumberedFallback() {
        let team = Team(name: nil)
        #expect(team.displayName(index: 2) == "Team 3")
        #expect(Team(name: "The Word Wizards").displayName(index: 0) == "The Word Wizards")
        #expect(Team(name: "").displayName(index: 4) == "Team 5")
    }
}
