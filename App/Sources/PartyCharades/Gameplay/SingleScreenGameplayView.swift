import Core
import SwiftUI

/// The pass-the-phone layout: every non-tabletop case lands here — non-Duo
/// hardware, an OS below 27.1, a flat/fully-open Duo, or a tabletop Duo whose
/// crease the system won't report. PRD §8 treats this as load-bearing, not a
/// courtesy, so it stays a complete game on its own.
struct SingleScreenGameplayView: View {
    let engine: GameEngine

    @Environment(AppCoordinator.self) private var coordinator

    // PRD §11.1 — Dynamic Type throughout, including these custom-size
    // fonts. @ScaledMetric keeps our chosen baseline sizes while letting them
    // grow or shrink with the user's text size setting; minimumScaleFactor +
    // lineLimit below is what keeps the word from clipping once it does.
    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 64
    @ScaledMetric(relativeTo: .largeTitle) private var wordSize: CGFloat = 56
    @ScaledMetric(relativeTo: .title2) private var categorySize: CGFloat = 22
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var now: ContinuousClock.Instant { ContinuousClock().now }

    var body: some View {
        let fraction = engine.timer?.fractionElapsed(now: now) ?? 0
        let secondsRemaining = engine.timer?.displaySecondsRemaining(now: now) ?? 0
        let increaseContrast = colorSchemeContrast == .increased

        GeometryReader { proxy in
            let halfHeight = proxy.size.height / 2

            ZStack {
                VStack(spacing: 0) {
                    TopHalf(
                        engine: engine,
                        fraction: fraction,
                        secondsRemaining: secondsRemaining,
                        increaseContrast: increaseContrast,
                        countdownSize: countdownSize,
                        wordSize: wordSize,
                        categorySize: categorySize,
                        width: proxy.size.width
                    )
                    .frame(height: halfHeight)

                    HStack(spacing: 0) {
                        HitZoneButton(title: "Skip", tint: Color.secondary.opacity(0.2), foreground: .primary) {
                            engine.markSkipWithFeedback()
                        }
                        HitZoneButton(title: "Correct", tint: Color.green.opacity(0.85), foreground: .white) {
                            engine.markCorrectWithFeedback()
                        }
                    }
                    .frame(height: halfHeight)
                }

                ScoreFeedbackOverlay(feedback: engine.lastFeedback)
            }
            .overlay(alignment: .topTrailing) {
                PauseButton { coordinator.pauseMatch() }
                    .padding(.top, 8)
                    .padding(.trailing, 12)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

/// The top half: category + word, with a color-ramp fill that rises to
/// cover more of this half as the round's time runs out.
private struct TopHalf: View {
    let engine: GameEngine
    let fraction: Double
    let secondsRemaining: Int
    let increaseContrast: Bool
    let countdownSize: CGFloat
    let wordSize: CGFloat
    let categorySize: CGFloat
    let width: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                // Rises from the bottom of this half as the round elapses —
                // a proportional wipe rather than a flat color swap, capped
                // at this half's own height (never spills into the button
                // area below).
                CountdownColor.background(fractionElapsed: fraction, increaseContrast: increaseContrast)
                    .frame(height: proxy.size.height * min(1, max(0, fraction)))
                    .animation(.linear(duration: 0.1), value: fraction)

                VStack(spacing: 16) {
                    Text("\(secondsRemaining)")
                        .font(.system(size: countdownSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                        .foregroundStyle(CountdownColor.foreground(fractionElapsed: fraction, increaseContrast: increaseContrast))
                        .countdownPulse(secondsRemaining: secondsRemaining)
                        .accessibilityLabel(Text("\(secondsRemaining) seconds remaining"))

                    if let word = engine.currentWord {
                        VStack(spacing: 8) {
                            Text(word.category.emojiDisplayName.uppercased())
                                .font(.system(size: categorySize, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(word.text(in: engine.configuration.language))
                                .font(.system(size: wordSize, weight: .bold))
                                .minimumScaleFactor(0.3)
                                .lineLimit(3)
                                .multilineTextAlignment(.center)
                                .frame(width: width * 0.8)
                        }
                        .accessibilityElement(children: .combine)
                    }

                    if engine.turnReshuffled {
                        Text("Deck reshuffled")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct PauseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "pause.circle.fill")
                .font(.title)
                .foregroundStyle(.white, .black.opacity(0.35))
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Pause"))
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
