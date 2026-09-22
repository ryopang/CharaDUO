import Design
import SwiftUI

/// Thin `Color`-producing wrapper around `Design.CountdownRamp`'s pure RGB
/// math (PRD §3.3) — the ramp math itself lives in a package so it's
/// unit-testable (including the WCAG AA contrast proof); this is just the
/// SwiftUI-facing surface used across all four countdown displays
/// (single-screen, tabletop lid, tabletop far edge, outer scoreboard).
enum CountdownColor {
    static func background(fractionElapsed: Double, increaseContrast: Bool = false) -> Color {
        color(CountdownRamp.background(fractionElapsed: fractionElapsed, increaseContrast: increaseContrast))
    }

    static func foreground(fractionElapsed: Double, increaseContrast: Bool = false) -> Color {
        color(CountdownRamp.foreground(fractionElapsed: fractionElapsed, increaseContrast: increaseContrast))
    }

    private static func color(_ rgb: CountdownRamp.RGB) -> Color {
        Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}
