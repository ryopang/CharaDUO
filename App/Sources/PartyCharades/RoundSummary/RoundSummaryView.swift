import Core
import SwiftUI

/// PRD §4.1 — score this round + running total, expandable list of every
/// word with Correct/Skipped colour coding. No highlight-clip player until
/// M6 wires up the reaction camera.
struct RoundSummaryView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        if let engine = coordinator.engine, let result = coordinator.lastTurnResult {
            let team = engine.matchState.teams[result.teamIndex]

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text(team.displayName(index: result.teamIndex))
                        .font(.title.bold())
                    Text("+\(result.score) this round")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Total: \(team.score)")
                        .font(.headline)
                    if result.deckReshuffled {
                        Text("Deck reshuffled")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()

                List(Array(result.events.enumerated()), id: \.offset) { _, event in
                    HStack {
                        Text(event.word.localizations[engine.configuration.language] ?? event.word.localizations[.english] ?? "")
                        Spacer()
                        Image(systemName: event.kind == .correct ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(event.kind == .correct ? .green : .secondary)
                    }
                }
                .listStyle(.plain)

                Button {
                    coordinator.continueAfterRoundSummary()
                } label: {
                    Text(engine.matchState.isMatchComplete ? "See Results" : "Next Team")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
        }
    }
}
