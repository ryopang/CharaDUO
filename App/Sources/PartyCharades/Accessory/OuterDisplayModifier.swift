import Capture
import Core
import SwiftUI

/// Attaches the Duo outer-display scene accessory (PRD §3.4).
///
/// Verified against the iOS 27.1 SDK rather than assumed:
///   SwiftUI.swiftinterface:
///     @available(iOS 27.0) extension View
///       func sceneAccessory<C>(@ContentBuilder content: () -> C) -> some View
///         where C: SceneAccessoryContent
///     @available(iOS 27.1) struct CameraCaptureAccessory<Content>: SceneAccessoryContent
///       init(isEnabled: Binding<Bool>, @ContentBuilder content: @escaping () -> Content)
///     @available(iOS 27.0) extension SceneAccessoryContent
///       func onAvailabilityChange(perform: @escaping (Bool) -> Void) -> some SceneAccessoryContent
///
/// Two things memory would get wrong: `onAvailabilityChange` modifies
/// `SceneAccessoryContent`, not `View`, so it chains onto the accessory
/// rather than the host view; and although `sceneAccessory` is iOS 27.0,
/// `CameraCaptureAccessory` is 27.1, so the whole block gates on 27.1.
///
/// `isEnabled` is the only lever we own. Per `UISceneAccessoryRegistration.h`
/// the system owns `isAvailable`; we own only whether we draw.
///
/// The snapshot arrives as a closure because the countdown has to advance on
/// the outer display independently of whatever is redrawing the inner one —
/// the accessory runs its own tick.
struct OuterDisplayModifier: ViewModifier {
    let isActive: Bool
    let snapshot: () -> ScoreboardSnapshot?
    let availability: AccessoryAvailability

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            content.sceneAccessory {
                CameraCaptureAccessory(isEnabled: .constant(isActive)) {
                    TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                        if let snapshot = snapshot() {
                            GuesserScoreboard(snapshot: snapshot)
                        } else {
                            // Between rounds there is nothing for the
                            // guessers to watch; drawing nothing is the
                            // whole behaviour.
                            Color.black.ignoresSafeArea()
                        }
                    }
                }
                .onAvailabilityChange { isAvailable in
                    // PRD §3.4: record it and do nothing else. No error, no
                    // pause, no reconnect prompt — mid-round revocation must
                    // be invisible to the match.
                    availability.update(isAvailable: isAvailable)
                }
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

extension View {
    /// No-op on anything that isn't a Duo running 27.1+ with an active
    /// capture session — which is the same path a non-Duo iPhone takes.
    func outerDisplay(
        isActive: Bool,
        availability: AccessoryAvailability,
        snapshot: @escaping () -> ScoreboardSnapshot?
    ) -> some View {
        modifier(OuterDisplayModifier(isActive: isActive, snapshot: snapshot, availability: availability))
    }
}
