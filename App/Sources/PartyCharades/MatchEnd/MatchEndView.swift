import Core
import SwiftUI

/// PRD §4.2 — final standings and winner celebration.
///
/// Top half / bottom half split, mirroring `RoundSummaryView`: the header
/// ("Game Over" + winner) fills the upper half and is the exact same view
/// (`MatchEndHeaderView`) the outer display's mirror (`GuesserMatchEndView`)
/// renders, off the same `MatchEndSnapshot`.
struct MatchEndView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        if let engine = coordinator.engine {
            let snapshot = engine.matchState.matchEndSnapshot

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    // Upper half: the win/lose headline plus the standings —
                    // everything the player reads, above the fold.
                    ScrollView {
                        VStack(spacing: 20) {
                            MatchEndHeaderView(snapshot: snapshot)
                            Standings(snapshot: snapshot)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }
                    .frame(height: proxy.size.height / 2)

                    // Lower half: nothing but the next actions.
                    VStack(spacing: 12) {
                        // M6 hasn't landed yet — there's no reel to save.
                        // Kept visible (not hidden) so the option reads as
                        // "coming soon," not missing.
                        Button {
                        } label: {
                            Text("Save Video")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .disabled(true)

                        Button {
                            coordinator.rematch()
                        } label: {
                            Text("Rematch")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)

                        Button {
                            coordinator.startNewCustomGame()
                        } label: {
                            Text("New Custom Game")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)

                        Button {
                            coordinator.returnHome()
                        } label: {
                            Text("Back to Home")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(height: proxy.size.height / 2)
                }
            }
        }
    }
}

/// Shared by `MatchEndView`'s upper half and `GuesserMatchEndView` (the
/// outer-display mirror).
struct MatchEndHeaderView: View {
    let snapshot: MatchEndSnapshot

    var body: some View {
        VStack(spacing: 20) {
            Text("Game Over")
                .font(.system(size: 88, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            let winnerText = matchEndWinnerText(snapshot: snapshot)
            if !winnerText.isEmpty {
                Text("\(winnerText) 🎉")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct Standings: View {
    let snapshot: MatchEndSnapshot

    var body: some View {
        // PRD §11 — native Liquid Glass via the system's own glass APIs, not
        // a hand-rolled translucency effect. GlassEffectContainer groups the
        // per-team cards so nearby glass shapes merge/morph correctly
        // instead of each rendering its own independent effect.
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
                ForEach(Array(snapshot.teams.enumerated()), id: \.element.id) { index, team in
                    HStack {
                        Text(team.displayName(index: index))
                            .font(.subheadline.bold())
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Text("\(team.score)")
                            .font(.subheadline.bold().monospacedDigit())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
                    // PRD §11.1 — scores must be readable by VoiceOver.
                    // Combined so it reads as one statement ("Team 1, score
                    // 5") rather than two separate swipe stops.
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
