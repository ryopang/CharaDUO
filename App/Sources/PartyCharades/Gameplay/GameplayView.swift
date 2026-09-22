import Core
import SwiftUI

/// M3's single-screen layout — the pass-the-phone mode that must be complete
/// and fun on any iPhone with no fold, no outer display (PRD §8). The
/// tabletop split (M4) and outer scoreboard (M5) build on top of this later;
/// they never replace it.
struct GameplayView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        if let engine = coordinator.engine {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                GameplayContentView(engine: engine)
                    .onChange(of: context.date) {
                        coordinator.checkForTurnExpiry(now: ContinuousClock().now)
                    }
            }
        }
    }
}

private struct GameplayContentView: View {
    let engine: GameEngine
    @Environment(AppCoordinator.self) private var coordinator

    private var now: ContinuousClock.Instant { ContinuousClock().now }

    var body: some View {
        let fraction = engine.timer?.fractionElapsed(now: now) ?? 0
        let remainingSeconds = secondsRemaining(engine.timer)

        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("\(remainingSeconds)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(.primary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(CountdownColor.background(fractionElapsed: fraction))

                if let word = engine.currentWord {
                    VStack(spacing: 8) {
                        Text(word.category.displayName.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(word.localizations[engine.configuration.language] ?? word.localizations[.english] ?? "")
                            .font(.system(size: 48, weight: .bold))
                            .minimumScaleFactor(0.4)
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    .frame(maxHeight: .infinity)
                }

                if engine.turnReshuffled {
                    Text("Deck reshuffled")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 0) {
                Button {
                    engine.markSkip()
                } label: {
                    Text("Skip")
                        .font(.title.bold())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .background(Color.secondary.opacity(0.2))
                .foregroundStyle(.primary)

                Button {
                    engine.markCorrect()
                } label: {
                    Text("Correct")
                        .font(.title.bold())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .background(Color.green.opacity(0.85))
                .foregroundStyle(.white)
            }
            .frame(height: 160)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func secondsRemaining(_ timer: RoundTimer?) -> Int {
        guard let timer else { return 0 }
        let remaining = timer.remaining(now: now)
        let components = remaining.components
        let wholeSeconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        return Int(wholeSeconds.rounded(.up))
    }
}
