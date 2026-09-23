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
    // Drives the redraw cadence. TimelineView alone isn't enough here: its
    // content closure re-runs on schedule, but the countdown views it
    // contains read the elapsed time through `GameEngine` — an `@Observable`
    // class whose watched properties (the `timer` struct itself) never
    // actually change from one tick to the next, only the wall-clock "now"
    // used to compute a fraction from it does. SwiftUI's fine-grained
    // Observable diffing then has no reason to re-invoke those views' own
    // `body`, so the digit silently freezes at its starting value even
    // though the periodic tick is firing. Passing `now` down as an explicit,
    // genuinely-changing parameter (see `now` below) is what forces them to
    // recompute.
    @State private var now = ContinuousClock().now

    var body: some View {
        if let engine = coordinator.engine {
            if engine.isPaused {
                PausedView()
            } else {
                layout(for: engine, now: now)
                    // PRD §7.3 — a smaller recording indicator on the inner
                    // display too: the describer's voice is captured even
                    // though their picture isn't.
                    .overlay(alignment: .topLeading) {
                        if coordinator.isRecording {
                            InnerRecordingIndicator()
                                .padding(.top, 20)
                                .padding(.leading, 16)
                        }
                    }
                    // PRD §3.2 — the lid carries the word and nothing else;
                    // the system clock sitting on top of it is exactly the
                    // kind of competing element that costs legibility
                    // mid-round.
                    .statusBarHidden()
                    .task(id: engine.timer?.startInstant) {
                        // The tick is only a redraw prompt. Elapsed time is
                        // always recomputed from ContinuousClock (PRD §10.3),
                        // never accumulated from these ticks.
                        while !Task.isCancelled {
                            now = ContinuousClock().now
                            coordinator.checkForTurnExpiry(now: now)
                            try? await Task.sleep(for: .milliseconds(100))
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func layout(for engine: GameEngine, now: ContinuousClock.Instant) -> some View {
        switch coordinator.posture {
        case .tabletop:
            TabletopGameplayView(engine: engine, now: now)
        case .flat, .closed, .noHinge:
            SingleScreenGameplayView(engine: engine, now: now)
        }
    }
}

/// Deliberately small: on the describer's side it's a disclosure, not a
/// feature, and it must not compete with the word.
private struct InnerRecordingIndicator: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.red)
                .frame(width: 7, height: 7)
            Text("REC")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.black.opacity(0.35), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Recording"))
    }
}
