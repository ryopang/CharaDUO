import SwiftUI

/// Design refresh (2026-09-23): one always-dark theme built on the icon's
/// purple, with SF Pro Rounded throughout. Countdown colours are separate
/// (`CountdownRamp`) — this is chrome only.
enum Theme {
    /// The icon's mid purple; also the launch screen colour.
    static let background = Color(red: 0.306, green: 0.125, blue: 0.478)
    /// Deeper purple for the bottom of gradients and scrims.
    static let backgroundDeep = Color(red: 0.14, green: 0.06, blue: 0.27)
    /// Bright, saturated purple for tint / prominent controls.
    static let accent = Color(red: 0.60, green: 0.42, blue: 1.0)
    /// The pill behind "DUO" in the wordmark.
    static let pill = Color(red: 0.84, green: 0.20, blue: 0.35)

    static var backdrop: LinearGradient {
        LinearGradient(colors: [background, backgroundDeep], startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    /// Applied once at the root: dark scheme, purple tint, rounded type.
    func charaDuoTheme() -> some View {
        self
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
            .fontDesign(.rounded)
    }
}
