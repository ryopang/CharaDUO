import SwiftUI

/// PRD §4.2 — final standings and winner celebration. No reaction reel or
/// save prompt until M6.
struct MatchEndView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        if let engine = coordinator.engine {
            let teams = engine.matchState.teams
            let winners = engine.matchState.winningTeams

            VStack(spacing: 24) {
                Spacer()

                Text("Match Complete")
                    .font(.largeTitle.bold())

                if winners.count == 1, let winner = winners.first,
                   let index = teams.firstIndex(where: { $0.id == winner.id }) {
                    Text("\(winner.displayName(index: index)) wins!")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                } else if winners.count > 1 {
                    Text("It's a tie!")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    ForEach(Array(teams.enumerated()), id: \.element.id) { index, team in
                        HStack {
                            Text(team.displayName(index: index))
                                .font(.headline)
                            Spacer()
                            Text("\(team.score)")
                                .font(.headline.monospacedDigit())
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    coordinator.returnHome()
                } label: {
                    Text("Back to Home")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }
}
