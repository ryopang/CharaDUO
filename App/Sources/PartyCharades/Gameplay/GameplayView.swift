import Core
import Posture
import SwiftUI

/// Routes between the tabletop and single-screen layouts, and drives the
/// countdown's redraw cadence.
///
/// PRD §3.1 — posture changes reflow the layout and play continues; only a
/// `.closed` fold pauses. There is deliberately no auto-pause on any other
/// posture change: a party game gets jostled constantly and false pauses are
/// worse than the problem they solve.
struct GameplayView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        if let engine = coordinator.engine {
            if engine.isPaused {
                PausedView()
            } else {
                // The periodic tick is only a redraw prompt. Elapsed time is
                // always recomputed from ContinuousClock (PRD §10.3), never
                // accumulated from these ticks.
                TimelineView(.periodic(from: .now, by: 0.1)) { context in
                    layout(for: engine)
                        .onChange(of: context.date) {
                            coordinator.checkForTurnExpiry(now: ContinuousClock().now)
                        }
                }
                // PRD §3.2 — the lid carries the word and nothing else; the
                // system clock sitting on top of it is exactly the kind of
                // competing element that costs legibility mid-round.
                .statusBarHidden()
            }
        }
    }

    @ViewBuilder
    private func layout(for engine: GameEngine) -> some View {
        switch coordinator.posture {
        case .tabletop:
            TabletopGameplayView(engine: engine)
        case .flat, .closed, .noHinge:
            SingleScreenGameplayView(engine: engine)
        }
    }
}
