import Core
import SwiftUI

/// The giant "+1"/"-1" that flashes center-screen on a Correct/Skip tap and
/// fades away quickly. Driven by `GameEngine.lastFeedback` (mirrored onto
/// `ScoreboardSnapshot` for the outer display) rather than local button-tap
/// state, so the inner and outer screens animate off the exact same event.
struct ScoreFeedbackOverlay: View {
    let feedback: ScoreFeedback?

    @State private var visibleFeedback: ScoreFeedback?
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8

    var body: some View {
        Group {
            if let visibleFeedback {
                Text(visibleFeedback.delta > 0 ? "+\(visibleFeedback.delta)" : "\(visibleFeedback.delta)")
                    .font(.system(size: 360, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.2)
                    .lineLimit(1)
                    .foregroundStyle(visibleFeedback.delta > 0 ? .green : .red)
                    .shadow(radius: 12)
                    .opacity(opacity)
                    .scaleEffect(scale)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onChange(of: feedback) { _, newValue in
            guard let newValue else { return }
            visibleFeedback = newValue
            opacity = 1
            scale = 1.0
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                opacity = 0
                scale = 1.15
            }
        }
    }
}
