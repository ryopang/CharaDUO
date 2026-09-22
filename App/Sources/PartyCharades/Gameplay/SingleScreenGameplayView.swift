import Core
import SwiftUI

/// The pass-the-phone layout: every non-tabletop case lands here — non-Duo
/// hardware, an OS below 27.1, a flat/fully-open Duo, or a tabletop Duo whose
/// crease the system won't report. PRD §8 treats this as load-bearing, not a
/// courtesy, so it stays a complete game on its own.
struct SingleScreenGameplayView: View {
    let engine: GameEngine

    private var now: ContinuousClock.Instant { ContinuousClock().now }

    var body: some View {
        let fraction = engine.timer?.fractionElapsed(now: now) ?? 0

        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("\(engine.timer?.displaySecondsRemaining(now: now) ?? 0)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(CountdownColor.background(fractionElapsed: fraction))

                if let word = engine.currentWord {
                    VStack(spacing: 8) {
                        Text(word.category.displayName.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(word.text(in: engine.configuration.language))
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
                HitZoneButton(title: "Skip", tint: Color.secondary.opacity(0.2), foreground: .primary) {
                    engine.markSkip()
                }
                HitZoneButton(title: "Correct", tint: Color.green.opacity(0.85), foreground: .white) {
                    engine.markCorrect()
                }
            }
            .frame(height: 160)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

/// Shared by both layouts. PRD §2.1 — sized for a standing, angled, blind
/// stab: no margins, no competing controls, the whole zone is the target.
struct HitZoneButton: View {
    let title: String
    let tint: Color
    let foreground: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title.bold())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .background(tint)
        .foregroundStyle(foreground)
    }
}
