import Core
import SwiftUI

/// The pass-the-phone layout: every non-tabletop case lands here — non-Duo
/// hardware, an OS below 27.1, a flat/fully-open Duo, or a tabletop Duo whose
/// crease the system won't report. PRD §8 treats this as load-bearing, not a
/// courtesy, so it stays a complete game on its own.
struct SingleScreenGameplayView: View {
    let engine: GameEngine

    // PRD §11.1 — Dynamic Type throughout, including these custom-size
    // fonts. @ScaledMetric keeps our chosen baseline sizes while letting them
    // grow or shrink with the user's text size setting; minimumScaleFactor +
    // lineLimit below is what keeps the word from clipping once it does.
    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 64
    @ScaledMetric(relativeTo: .largeTitle) private var wordSize: CGFloat = 48
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var now: ContinuousClock.Instant { ContinuousClock().now }

    var body: some View {
        let fraction = engine.timer?.fractionElapsed(now: now) ?? 0
        let secondsRemaining = engine.timer?.displaySecondsRemaining(now: now) ?? 0
        let increaseContrast = colorSchemeContrast == .increased

        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("\(secondsRemaining)")
                    .font(.system(size: countdownSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(CountdownColor.foreground(fractionElapsed: fraction, increaseContrast: increaseContrast))
                    .countdownPulse(secondsRemaining: secondsRemaining)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(CountdownColor.background(fractionElapsed: fraction, increaseContrast: increaseContrast))
                    .accessibilityLabel(Text("\(secondsRemaining) seconds remaining"))

                if let word = engine.currentWord {
                    VStack(spacing: 8) {
                        Text(word.category.displayName.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(word.text(in: engine.configuration.language))
                            .font(.system(size: wordSize, weight: .bold))
                            .minimumScaleFactor(0.35)
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    .frame(maxHeight: .infinity)
                    .accessibilityElement(children: .combine)
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
                    engine.markSkipWithFeedback()
                }
                HitZoneButton(title: "Correct", tint: Color.green.opacity(0.85), foreground: .white) {
                    engine.markCorrectWithFeedback()
                }
            }
            .frame(height: 160)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

/// Shared by both layouts. PRD §2.1 — sized for a standing, angled, blind
/// stab: no margins, no competing controls, the whole zone is the target.
/// PRD §11.1 — hit zones must be ≥44pt, and in practice these are far larger
/// (each is half the flat surface); Correct/Skip differ by position, haptic,
/// sound, and icon/label, not colour alone.
struct HitZoneButton: View {
    let title: String
    let tint: Color
    let foreground: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title.bold())
                // At large Dynamic Type sizes "Correct" wraps to "Cor-rect"
                // in the narrow half-width zone — shrinking to fit on one
                // line reads far better than a mid-word hyphen break.
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .background(tint)
        .foregroundStyle(foreground)
        .accessibilityAddTraits(.isButton)
    }
}
