import SwiftUI

/// PRD §3.3 — continuous green → amber → red ramp, never a direct
/// green→red jump (the single worst choice for red-green colour vision
/// deficiency). Thresholds match the PRD's remaining-time table: 100–50%
/// green static, 50–20% green→amber, 20–0% amber→red (expressed here in
/// elapsed-fraction terms: 0–50% static, 50–80% ramp, 80–100% ramp).
///
/// This is a minimal placeholder pending M7's Design layer (Theme, contrast
/// adjustments for Increase Contrast, the final-10s pulse) — it exists now
/// because the countdown's colour cue is core gameplay feedback, not
/// cosmetic polish, and M3 must be complete and fun on its own.
enum CountdownColor {
    private static let green = (r: 0.20, g: 0.78, b: 0.35)
    private static let amber = (r: 0.95, g: 0.70, b: 0.10)
    private static let red = (r: 0.90, g: 0.20, b: 0.20)

    static func background(fractionElapsed: Double) -> Color {
        let f = min(1, max(0, fractionElapsed))
        switch f {
        case ..<0.5:
            return color(green)
        case 0.5..<0.8:
            return interpolate(from: green, to: amber, t: (f - 0.5) / 0.3)
        default:
            return interpolate(from: amber, to: red, t: (f - 0.8) / 0.2)
        }
    }

    private static func interpolate(from: (r: Double, g: Double, b: Double), to: (r: Double, g: Double, b: Double), t: Double) -> Color {
        let clampedT = min(1, max(0, t))
        return Color(
            red: from.r + (to.r - from.r) * clampedT,
            green: from.g + (to.g - from.g) * clampedT,
            blue: from.b + (to.b - from.b) * clampedT
        )
    }

    private static func color(_ rgb: (r: Double, g: Double, b: Double)) -> Color {
        Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}
