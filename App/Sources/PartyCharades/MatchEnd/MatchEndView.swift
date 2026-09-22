import SwiftUI

/// PRD §4.2 — final standings and winner celebration. No reaction reel or
/// save prompt until M6.
struct MatchEndView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        if let engine = coordinator.engine {
            let teams = engine.matchState.teams
            let winners = engine.matchState.winningTeams

            ScrollableCenteredColumn {
                Spacer(minLength: 16)

                Text("Match Complete")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if winners.count == 1, let winner = winners.first,
                   let index = teams.firstIndex(where: { $0.id == winner.id }) {
                    Text("\(winner.displayName(index: index)) wins!")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else if winners.count > 1 {
                    Text("It's a tie!")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // PRD §11 — native Liquid Glass via the system's own glass
                // APIs, not a hand-rolled translucency effect.
                // GlassEffectContainer groups the per-team cards so nearby
                // glass shapes merge/morph correctly instead of each
                // rendering its own independent effect.
                GlassEffectContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        ForEach(Array(teams.enumerated()), id: \.element.id) { index, team in
                            HStack {
                                Text(team.displayName(index: index))
                                    .font(.headline)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Text("\(team.score)")
                                    .font(.headline.monospacedDigit())
                            }
                            .padding()
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                            // PRD §11.1 — scores must be readable by
                            // VoiceOver. Combined so it reads as one
                            // statement ("Team 1, score 5") rather than two
                            // separate swipe stops.
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 16)

                Button {
                    coordinator.returnHome()
                } label: {
                    Text("Back to Home")
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)

                Spacer(minLength: 16)
            }
        }
    }
}
