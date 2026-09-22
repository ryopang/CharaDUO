#if DEBUG
import CoreGraphics
import Foundation
import Posture

/// CLAUDE.md §6 requires every path to be forceable by a debug setting so it
/// can be exercised without the real hardware condition. `simctl` has no
/// hinge control — folding is a Device Hub GUI action — so without these the
/// tabletop layout could only ever be looked at on a physical Duo.
///
/// DEBUG-only: none of this compiles into a release build.
enum DebugOverrides {
    private static let arguments = ProcessInfo.processInfo.arguments

    /// `-uiTestPosture tabletop|flat|closed|noHinge`
    static var posture: PostureState? {
        switch value(for: "-uiTestPosture") {
        case "tabletop": return .tabletop
        case "flat": return .flat
        case "closed": return .closed
        case "noHinge": return .noHinge
        default: return nil
        }
    }

    /// `-uiTestCreaseFraction 0.46` — fakes a crease that far down the
    /// container, standing in for the `ReservedRegion` a real fold reports.
    static func division(in size: CGSize) -> CGRect? {
        guard let raw = value(for: "-uiTestCreaseFraction"), let fraction = Double(raw),
              fraction > 0, fraction < 1 else { return nil }
        let thickness = max(8, size.height * 0.02)
        return CGRect(
            x: 0,
            y: size.height * fraction,
            width: size.width,
            height: thickness
        )
    }

    /// `-uiTestAutoStart` — drop straight into a round on launch, so a
    /// gameplay screen can be captured without driving taps.
    static var autoStartMatch: Bool {
        arguments.contains("-uiTestAutoStart")
    }

    private static func value(for flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
#endif
