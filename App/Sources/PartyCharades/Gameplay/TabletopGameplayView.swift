import Core
import Posture
import SwiftUI

/// PRD §3.2 — the two-sided tabletop layout. The lid is describer-private;
/// the flat half serves the describer (blind-tap zones) and the guessers (a
/// 180°-rotated far edge) at the same time. That rotation is the signature
/// idea of the app.
struct TabletopGameplayView: View {
    let engine: GameEngine
    let now: ContinuousClock.Instant

    var body: some View {
        GeometryReader { proxy in
            if let split = FoldGeometry.split(
                container: proxy.size,
                division: division(in: proxy)
            ) {
                TabletopSplitView(engine: engine, split: split, containerSize: proxy.size, now: now)
            } else {
                // The hinge says tabletop but the system reports no usable
                // crease. CLAUDE.md: never hardcode the fold position or a
                // 50/50 split — so fall back rather than guess a midpoint.
                SingleScreenGameplayView(engine: engine, now: now)
            }
        }
        // The two halves must reach the physical edges of the inner display:
        // the crease comes from `reservedRegions` in the *full* display's
        // coordinate space, so a safe-area-inset GeometryReader would report a
        // smaller container and every offset below would be measured against
        // the wrong origin.
        .ignoresSafeArea()
    }

    private func division(in proxy: GeometryProxy) -> CGRect? {
        #if DEBUG
        if let forced = DebugOverrides.division(in: proxy.size) { return forced }
        #endif
        return activeDivisionFrame(in: proxy)
    }
}

private struct TabletopSplitView: View {
    let engine: GameEngine
    let split: FoldSplit
    let containerSize: CGSize
    let now: ContinuousClock.Instant

    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        let flat = FoldGeometry.flatHalfLayout(flat: split.flat)

        ZStack(alignment: .topLeading) {
            Color.black

            DescriberLidView(engine: engine, now: now)
                .frame(width: split.lid.width, height: split.lid.height)
                .offset(x: split.lid.minX, y: split.lid.minY)

            // Rotated a half turn so it reads right-side-up from across the
            // table. 180° about the centre leaves the bounding box alone, so
            // the offset still positions it correctly.
            GuesserFarEdgeView(engine: engine, now: now)
                .frame(width: flat.farEdge.width, height: flat.farEdge.height)
                .rotationEffect(.degrees(180))
                .offset(x: flat.farEdge.minX, y: flat.farEdge.minY)

            HitZoneButton(kind: .correct) {
                coordinator.recordCorrect()
            }
            .frame(width: flat.correct.width, height: flat.correct.height)
            .offset(x: flat.correct.minX, y: flat.correct.minY)

            HitZoneButton(kind: .skip) {
                engine.markSkipWithFeedback()
            }
            .frame(width: flat.skip.width, height: flat.skip.height)
            .offset(x: flat.skip.minX, y: flat.skip.minY)

            // Spans the full container — both the lid and the flat half read
            // as one surface for this event, not just wherever the tap
            // landed.
            ScoreFeedbackOverlay(feedback: engine.lastFeedback)
                .frame(width: containerSize.width, height: containerSize.height)
        }
    }
}

private struct TabletopPauseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "pause.circle.fill")
                .font(.title2)
                .foregroundStyle(.white, .black.opacity(0.35))
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Pause"))
    }
}

/// The vertical half, seen only by the describer. PRD §3.2: the word at
/// maximum legible size is this surface's entire job. The whole lid is one
/// flat countdown colour (design refresh 2026-09-23), so the word sits on a
/// high-contrast card that stays legible on green, amber and red alike.
private struct DescriberLidView: View {
    let engine: GameEngine
    let now: ContinuousClock.Instant

    @Environment(AppCoordinator.self) private var coordinator

    // PRD §11.1 / §3.2 — the word is "the single most important element in
    // the app", sized to fill the surface; Dynamic Type has to grow it
    // further still. minimumScaleFactor below is the backstop once it does.
    @ScaledMetric(relativeTo: .largeTitle) private var wordSize: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var timerSize: CGFloat = 28
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let fraction = engine.timer?.fractionElapsed(now: now) ?? 0
        let increaseContrast = colorSchemeContrast == .increased
        let urgency = CountdownColor.background(fractionElapsed: fraction, increaseContrast: increaseContrast)
        let secondsRemaining = engine.timer?.displaySecondsRemaining(now: now) ?? 0

        let foreground = CountdownColor.foreground(fractionElapsed: fraction, increaseContrast: increaseContrast)

        ZStack {
            urgency
                .animation(.linear(duration: 0.1), value: fraction)

            VStack(spacing: 16) {
                if let word = engine.currentWord {
                    Text(word.category.emojiDisplayName.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(foreground.opacity(0.8))

                    Text(word.text(in: engine.configuration.language))
                        .font(.system(size: wordSize, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.25)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 28))
                }

                // Subordinate to the word, per §3.2.
                Text("\(secondsRemaining)")
                    .font(.system(size: timerSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(foreground)
                    .countdownPulse(secondsRemaining: secondsRemaining)
                    .accessibilityLabel(Text("\(secondsRemaining) seconds remaining"))
            }
            .padding(24)
        }
        .overlay(alignment: .topTrailing) {
            TabletopPauseButton { coordinator.pauseMatch() }
                .padding(20)
        }
    }
}

/// The strip of the flat half nearest the crease, rotated to face the
/// guessers. PRD §3.2/§3.3: this is a surface the whole room watches, so it
/// carries the urgency gradient at **full** strength.
private struct GuesserFarEdgeView: View {
    let engine: GameEngine
    let now: ContinuousClock.Instant

    @Environment(AppCoordinator.self) private var coordinator
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 64
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let state = engine.matchState
        let index = state.currentTeamIndex
        let team = state.teams[index]
        let liveScore = team.score + engine.currentTurnScore
        let fraction = engine.timer?.fractionElapsed(now: now) ?? 0
        let increaseContrast = colorSchemeContrast == .increased
        let secondsRemaining = engine.timer?.displaySecondsRemaining(now: now) ?? 0
        let foreground = CountdownColor.foreground(fractionElapsed: fraction, increaseContrast: increaseContrast)

        ZStack {
            CountdownColor.background(fractionElapsed: fraction, increaseContrast: increaseContrast)

            VStack(spacing: 4) {
                Text("\(secondsRemaining)")
                    .font(.system(size: timerSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(foreground)
                    .countdownPulse(secondsRemaining: secondsRemaining)

                HStack(spacing: 8) {
                    Text(team.displayName(index: index))
                        .font(.headline)
                    Text("\(liveScore)")
                        .font(.headline.monospacedDigit())
                }
                .foregroundStyle(foreground.opacity(0.75))
            }
        }
        .overlay(alignment: .topTrailing) {
            TabletopPauseButton { coordinator.pauseMatch() }
                .padding(20)
        }
    }
}
