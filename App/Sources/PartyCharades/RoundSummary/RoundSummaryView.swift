import Content
import Core
import SwiftUI

/// PRD §4.1 — score this round + running total, expandable list of every
/// word with Correct/Skipped colour coding, and — when the reaction camera
/// caught any Corrects — the round's highlight clip (PRD §5.6), which never
/// blocks "Next Team".
///
/// Top half / bottom half split: the header (team, this round's correct
/// count, game total, category) fills the upper half exactly as it does on
/// the outer display's mirror (`GuesserRoundSummaryView`) — both render the
/// same `RoundSummaryHeaderView` off the same `RoundSummarySnapshot` so the
/// two surfaces never drift apart.
struct RoundSummaryView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        if let engine = coordinator.engine, let result = coordinator.lastTurnResult {
            let snapshot = engine.roundSummarySnapshot(for: result)

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    RoundSummaryHeaderView(snapshot: snapshot)
                        .frame(height: proxy.size.height / 2)

                    // All the round's results sit above the button, which
                    // stays pinned near the bottom edge so it's reachable
                    // without hunting through the word lists first.
                    VStack(spacing: 0) {
                        // Arrives a beat after the round ends (the last
                        // segment finishes writing); absent entirely when
                        // capture was off or failed — no placeholder, no
                        // explanation (PRD §5.7).
                        if let reel = coordinator.lastTurnReel {
                            HighlightClipCard(reel: reel, title: snapshot.teamName)
                                .frame(height: min(150, proxy.size.height * 0.16))
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .transition(.opacity)
                        }

                        HStack(spacing: 0) {
                            WordColumn(
                                title: tr("Correct Answers"),
                                words: snapshot.correctWords,
                                language: snapshot.language,
                                tint: .green
                            )
                            Divider()
                            WordColumn(
                                title: tr("Skipped"),
                                words: snapshot.skippedWords,
                                language: snapshot.language,
                                tint: .secondary
                            )
                        }
                        .frame(maxHeight: .infinity)

                        Button {
                            coordinator.continueAfterRoundSummary()
                        } label: {
                            Text(snapshot.isMatchComplete ? "See Results" : "Next Team")
                                .font(.title3.bold())
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .padding(.bottom, 24)
                        .padding(.top, 12)
                    }
                    .frame(height: proxy.size.height / 2)
                    .animation(.easeOut(duration: 0.25), value: coordinator.lastTurnReel?.id)
                }
            }
        }
    }
}

/// Shared by `RoundSummaryView`'s upper half and `GuesserRoundSummaryView`
/// (the outer-display mirror) — one view, so "both will show exactly the
/// same thing" is structural rather than two copies that can drift.
struct RoundSummaryHeaderView: View {
    let snapshot: RoundSummarySnapshot

    var body: some View {
        VStack(spacing: 12) {
            Text(snapshot.teamName)
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("\(snapshot.correctThisRound) correct answers this round")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
            HStack(spacing: 20) {
                Text("Total: \(snapshot.totalCorrectForGame)")
                if let category = snapshot.categoryLabel {
                    Text(category.emojiDisplayName)
                } else {
                    Text("Multiple Categories")
                }
            }
            .font(.title3.bold())
            .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WordColumn: View {
    let title: String
    let words: [GameWord]
    let language: ContentLanguage
    let tint: Color

    var body: some View {
        VStack(spacing: 0) {
            Text("\(title) (\(words.count))")
                .font(.headline)
                .foregroundStyle(tint)
                .padding(.top, 12)
                .padding(.bottom, 4)

            List(Array(words.enumerated()), id: \.offset) { _, word in
                let wordText = word.text(in: language)
                Text(wordText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    // PRD §11.1 — round results must be readable by
                    // VoiceOver; the column header alone isn't announced per
                    // row, so each row states its own status explicitly.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(wordText), \(title)"))
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity)
    }
}
