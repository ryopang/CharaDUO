import SwiftUI

/// PRD §3.3 — "Final 10s: Red, plus a per-second pulse in sync with the
/// haptic tick." §11.1 / §3.3: under Reduce Motion, drop the pulse and keep
/// the colour ramp — the ramp itself never moves independently of real
/// elapsed time, so there's nothing else to disable.
struct CountdownPulseModifier: ViewModifier {
    let secondsRemaining: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.12 : 1.0)
            .onChange(of: secondsRemaining) { _, newValue in
                guard !reduceMotion, newValue > 0, newValue <= 10 else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    isPulsing = true
                }
                withAnimation(.easeOut(duration: 0.18).delay(0.12)) {
                    isPulsing = false
                }
            }
    }
}

extension View {
    func countdownPulse(secondsRemaining: Int) -> some View {
        modifier(CountdownPulseModifier(secondsRemaining: secondsRemaining))
    }
}
