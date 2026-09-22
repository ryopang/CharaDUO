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
                    let wordText = event.word.localizations[engine.configuration.language] ?? event.word.localizations[.english] ?? ""
                    HStack {
                        Text(wordText)
                        Spacer()
                        Image(systemName: event.kind == .correct ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(event.kind == .correct ? .green : .secondary)
                            .accessibilityHidden(true)
                    }
                    // PRD §11.1 — round results must be readable by
                    // VoiceOver. The icon carries no text on its own, so the
                    // row combines into one statement ("Titanic, Correct")
                    // with an explicit label rather than relying on the
                    // icon's default SF Symbol name.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(wordText), \(event.kind == .correct ? "Correct" : "Skipped")"))
                }
                .listStyle(.plain)

                Button {
                    coordinator.continueAfterRoundSummary()
                } label: {
                    Text(engine.matchState.isMatchComplete ? "See Results" : "Next Team")
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding()
            }
        }
    }
}
