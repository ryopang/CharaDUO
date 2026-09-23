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
    let content: () -> OuterDisplayContent?
    let availability: AccessoryAvailability
    let onForwardCameras: @MainActor ([CameraDirectionResolver.Candidate]) -> Void

    func body(content hostContent: Content) -> some View {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            hostContent.sceneAccessory {
                CameraCaptureAccessory(isEnabled: .constant(isActive)) {
                    TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                        switch content() {
                        case .liveRound(let snapshot):
                            GuesserScoreboard(snapshot: snapshot)
                        case .roundSummary(let snapshot):
                            GuesserRoundSummaryView(snapshot: snapshot)
                        case .matchEnd(let snapshot):
                            GuesserMatchEndView(snapshot: snapshot)
                        case nil:
                            // Nothing to show right now (e.g. mid-pause);
                            // drawing nothing is the whole behaviour.
                            Color.black.ignoresSafeArea()
                        }
                    }
                    // PRD §1.3 — the camera facing the guessers is, by
                    // definition, whatever faces *this* scene's view.
                    .background { CameraDirectionProbe(onChange: onForwardCameras) }
                }
                .onAvailabilityChange { isAvailable in
                    // PRD §3.4: record it and do nothing else. No error, no
                    // pause, no reconnect prompt — mid-round revocation must
                    // be invisible to the match.
                    availability.update(isAvailable: isAvailable)
                }
            }
        } else {
            hostContent
        }
        #else
        hostContent
        #endif
    }
}

extension View {
    /// No-op on anything that isn't a Duo running 27.1+ with an active
    /// capture session — which is the same path a non-Duo iPhone takes.
    func outerDisplay(
        isActive: Bool,
        availability: AccessoryAvailability,
        onForwardCameras: @escaping @MainActor ([CameraDirectionResolver.Candidate]) -> Void,
        content: @escaping () -> OuterDisplayContent?
    ) -> some View {
        modifier(OuterDisplayModifier(
            isActive: isActive,
            content: content,
            availability: availability,
            onForwardCameras: onForwardCameras
        ))
    }
}

#if os(iOS)
import AVKit

/// Hosts an `AVCaptureDeviceDirectionCoordinator` bound to a view inside the
/// **outer accessory scene** (PRD §1.3). Its `forwardFacingDeviceDescriptors`
/// are the cameras pointed at whatever is in front of the outer display —
/// the guessers — recomputed live as the hinge moves.
///
/// Verified in the iOS 27.1 SDK, AVKit/AVCaptureDeviceDirectionCoordinator.h:
///   - initWithView:deviceTypes:changeHandler: — "Initialize the coordinator
///     only on the main thread"; the handler "is called on the main queue".
///   - deviceDirections "Returns an empty map until the coordinator fires
///     its first callback" — so nothing is read eagerly; we wait to be told.
///
/// The coordinator is created in `didMoveToWindow`, not `init`: until the
/// view is in the accessory scene's window there is no display for the
/// directions to be relative to.
private struct CameraDirectionProbe: UIViewRepresentable {
    let onChange: @MainActor ([CameraDirectionResolver.Candidate]) -> Void

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.onChange = onChange
    }

    final class ProbeView: UIView {
        var onChange: (@MainActor ([CameraDirectionResolver.Candidate]) -> Void)?
        private var coordinator: AnyObject?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else {
                coordinator = nil
                return
            }
            guard coordinator == nil, #available(iOS 27.1, *) else { return }
            coordinator = AVCaptureDeviceDirectionCoordinator(
                view: self,
                deviceTypes: [
                    .builtInOuterUltraWideCamera,
                    .builtInInnerUltraWideCamera,
                    .builtInUltraWideCamera,
                    .builtInWideAngleCamera,
                ]
            ) { [weak self] directions in
                let candidates = directions.forwardFacingDeviceDescriptors.map {
                    CameraDirectionResolver.Candidate(uniqueID: $0.uniqueID, deviceType: $0.deviceType.rawValue)
                }
                MainActor.assumeIsolated { self?.onChange?(candidates) }
            }
        }
    }
}
#endif
