import Core
import Posture
import SwiftUI

/// PRD §3.2 — the two-sided tabletop layout. The lid is describer-private;
/// the flat half serves the describer (blind-tap zones) and the guessers (a
/// 180°-rotated far edge) at the same time. That rotation is the signature
/// idea of the app.
struct TabletopGameplayView: View {
    let engine: GameEngine

    var body: some View {
        GeometryReader { proxy in
            if let split = FoldGeometry.split(
                container: proxy.size,
                division: division(in: proxy)
            ) {
                TabletopSplitView(engine: engine, split: split)
            } else {
                // The hinge says tabletop but the system reports no usable
                // crease. CLAUDE.md: never hardcode the fold position or a
                // 50/50 split — so fall back rather than guess a midpoint.
                SingleScreenGameplayView(engine: engine)
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

    var body: some View {
        let flat = FoldGeometry.flatHalfLayout(flat: split.flat)

        ZStack(alignment: .topLeading) {
            Color.black

            DescriberLidView(engine: engine)
                .frame(width: split.lid.width, height: split.lid.height)
                .offset(x: split.lid.minX, y: split.lid.minY)

            // Rotated a half turn so it reads right-side-up from across the
            // table. 180° about the centre leaves the bounding box alone, so
            // the offset still positions it correctly.
            GuesserFarEdgeView(engine: engine)
                .frame(width: flat.farEdge.width, height: flat.farEdge.height)
                .rotationEffect(.degrees(180))
                .offset(x: flat.farEdge.minX, y: flat.farEdge.minY)

            HitZoneButton(title: "Correct", tint: Color.green.opacity(0.85), foreground: .white) {
                engine.markCorrect()
            }
            .frame(width: flat.correct.width, height: flat.correct.height)
            .offset(x: flat.correct.minX, y: flat.correct.minY)

            // A concrete fill, not a translucent tint over black: the zone has
            // to read as a target for a blind, angled stab (PRD §2.1), not as
            // empty space below the Correct zone.
            HitZoneButton(title: "Skip", tint: Color(white: 0.24), foreground: .white) {
                engine.markSkip()
            }
            .frame(width: flat.skip.width, height: flat.skip.height)
            .offset(x: flat.skip.minX, y: flat.skip.minY)
        }
    }
}

/// The vertical half, seen only by the describer. PRD §3.2: the word at
/// maximum legible size is this surface's entire job, so the urgency ramp is
/// **restrained** here — it colours the timer's own container and a thin
/// border inset, never a full background wash that would fight the word.
private struct DescriberLidView: View {
    let engine: GameEngine

    private var now: ContinuousClock.Instant { ContinuousClock().now }

    var body: some View {
        let urgency = CountdownColor.background(
            fractionElapsed: engine.timer?.fractionElapsed(now: now) ?? 0
        )

        ZStack {
            Color.black

            VStack(spacing: 16) {
                if let word = engine.currentWord {
                    Text(word.category.displayName.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text(word.text(in: engine.configuration.language))
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.3)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Subordinate to the word, per §3.2.
                Text("\(engine.timer?.displaySecondsRemaining(now: now) ?? 0)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .background(urgency, in: Capsule())
            }
            .padding(24)
        }
        .overlay(
            Rectangle()
                .strokeBorder(urgency, lineWidth: 5)
                .padding(6)
        )
    }
}

/// The strip of the flat half nearest the crease, rotated to face the
/// guessers. PRD §3.2/§3.3: this is a surface the whole room watches, so it
/// carries the urgency gradient at **full** strength.
private struct GuesserFarEdgeView: View {
    let engine: GameEngine

    private var now: ContinuousClock.Instant { ContinuousClock().now }

    var body: some View {
        let state = engine.matchState
        let index = state.currentTeamIndex
        let team = state.teams[index]
        let liveScore = team.score + engine.currentTurnScore

        ZStack {
            CountdownColor.background(
                fractionElapsed: engine.timer?.fractionElapsed(now: now) ?? 0
            )

            VStack(spacing: 4) {
                Text("\(engine.timer?.displaySecondsRemaining(now: now) ?? 0)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(.black)

                HStack(spacing: 8) {
                    Text(team.displayName(index: index))
                        .font(.headline)
                    Text("\(liveScore)")
                        .font(.headline.monospacedDigit())
                }
                .foregroundStyle(.black.opacity(0.75))
            }
        }
    }
}
