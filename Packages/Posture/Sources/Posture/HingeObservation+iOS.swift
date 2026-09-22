#if os(iOS)
import SwiftUI

// Everything in this file is gated on iOS 27.1, which is where the hinge API
// actually lands — verified against the installed SDK, not assumed:
//   SwiftUICore.swiftinterface:
//     @available(anyAppleOS 27.1, *)
//     func onHingeChange(isEnabled: Bool = true,
//                        _ action: @escaping (_ oldContext: DeviceHingeContext,
//                                             _ newContext: DeviceHingeContext) -> Void) -> some View
//     struct DeviceHingeContext { var hinge: DeviceHinge? }
//     struct DeviceHinge { var status: Status; var angle: Angle }
//
// Note `onHingeChange` hands back BOTH the old and new context, and
// `DeviceHingeContext.hinge` is OPTIONAL — a nil hinge is how a non-Duo
// iPhone reports itself. Below 27.1 the modifier is a no-op and posture
// stays `.noHinge`, which is the same single-screen path a non-Duo device
// takes (PRD §8).

public extension View {
    func observingHinge(_ observer: HingeObserver) -> some View {
        modifier(HingeObservationModifier(observer: observer))
    }
}

private struct HingeObservationModifier: ViewModifier {
    let observer: HingeObserver

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, newContext in
                observer.apply(newContext)
            }
        } else {
            content
        }
    }
}

@available(iOS 27.1, *)
extension HingeObserver {
    func apply(_ context: DeviceHingeContext) {
        guard let hinge = context.hinge else {
            clearHinge()
            return
        }
        update(status: HingeStatusKind(hinge.status), angleDegrees: hinge.angle.degrees)
    }
}

@available(iOS 27.1, *)
extension HingeStatusKind {
    /// `DeviceHinge.Status` is a *struct with static members*, not an enum —
    /// so this compares rather than switches, and an unrecognised value falls
    /// through to `.unknown` instead of trapping.
    init(_ status: DeviceHinge.Status) {
        if status == .closed {
            self = .closed
        } else if status == .partiallyOpen {
            self = .partiallyOpen
        } else if status == .fullyOpen {
            self = .fullyOpen
        } else {
            self = .unknown
        }
    }
}

/// Reads the crease out of a `GeometryProxy`. `ReservedRegion.Kind` is also a
/// struct with static members; `.division` is the fold. Returns nil below
/// 27.1 or when the system reports no active division, which routes the
/// caller to the single-screen layout.
public func activeDivisionFrame(in proxy: GeometryProxy) -> CGRect? {
    if #available(iOS 27.1, *) {
        return proxy.reservedRegions(kind: .division).first { $0.isActive }?.frame
    }
    return nil
}
#endif
