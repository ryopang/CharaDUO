import Foundation

/// PRD §3.3's countdown urgency treatment, as pure RGB/contrast math with no
/// SwiftUI dependency — so it's unit-testable with `swift test` like the
/// rest of the project, and the app layer stays a thin `Color`-producing
/// wrapper around it (see the App target's `CountdownColor`).
public enum CountdownRamp {
    public typealias RGB = (r: Double, g: Double, b: Double)

    private static let green: RGB = (r: 0.20, g: 0.78, b: 0.35)
    private static let amber: RGB = (r: 0.95, g: 0.70, b: 0.10)
    private static let red: RGB = (r: 0.90, g: 0.20, b: 0.20)

    /// Continuous green → amber → red ramp, never a direct green→red jump —
    /// the single worst choice for red-green colour vision deficiency.
    /// Thresholds match the PRD's remaining-time table: 100–50% green
    /// static, 50–20% green→amber, 20–0% amber→red (elapsed-fraction terms:
    /// 0–50% static, 50–80% ramp, 80–100% ramp).
    ///
    /// Under Increase Contrast, interpolation is dropped for three flat
    /// steps at the same thresholds.
    public static func background(fractionElapsed: Double, increaseContrast: Bool) -> RGB {
        let f = min(1, max(0, fractionElapsed))
        if increaseContrast {
            switch f {
            case ..<0.5: return green
            case 0.5..<0.8: return amber
            default: return red
            }
        }
        switch f {
        case ..<0.5:
            return green
        case 0.5..<0.8:
            return interpolate(from: green, to: amber, t: (f - 0.5) / 0.3)
        default:
            return interpolate(from: amber, to: red, t: (f - 0.8) / 0.2)
        }
    }

    /// Pure black or pure white, whichever gives the higher contrast against
    /// this point on the ramp — the two extremes bound the achievable
    /// contrast ratio, so this is how "the digit colour shifts along with
    /// the background to hold that ratio" (PRD §3.3) is satisfied exactly.
    public static func foreground(fractionElapsed: Double, increaseContrast: Bool) -> RGB {
        let bg = background(fractionElapsed: fractionElapsed, increaseContrast: increaseContrast)
        let bgLuminance = relativeLuminance(bg)
        let blackContrast = contrastRatio(bgLuminance, 0)
        let whiteContrast = contrastRatio(bgLuminance, 1)
        return blackContrast >= whiteContrast ? (0, 0, 0) : (1, 1, 1)
    }

    private static func interpolate(from: RGB, to: RGB, t: Double) -> RGB {
        let clampedT = min(1, max(0, t))
        return (
            r: from.r + (to.r - from.r) * clampedT,
            g: from.g + (to.g - from.g) * clampedT,
            b: from.b + (to.b - from.b) * clampedT
        )
    }

    /// WCAG 2.x relative luminance: https://www.w3.org/TR/WCAG21/#dfn-relative-luminance
    public static func relativeLuminance(_ rgb: RGB) -> Double {
        func linearize(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(rgb.r) + 0.7152 * linearize(rgb.g) + 0.0722 * linearize(rgb.b)
    }

    /// WCAG 2.x contrast ratio: https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio
    public static func contrastRatio(_ l1: Double, _ l2: Double) -> Double {
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }
}
