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
///
/// Orientation: neither `CameraCaptureAccessory` nor `UISceneAccessory.h`
/// exposes any orientation control (checked in the 27.1 SDK), so the
/// tabletop quarter turn is ours — see `QuarterTurn`. Posture arrives as a
/// closure for the same reason the content does: read-only, read per tick.
struct OuterDisplayModifier: ViewModifier {
    let isActive: Bool
    let content: () -> OuterDisplayContent?
    let isQuarterTurned: () -> Bool
    let availability: AccessoryAvailability
    let locale: Locale
    let onForwardCameras: @MainActor ([CameraDirectionResolver.Candidate]) -> Void

    func body(content hostContent: Content) -> some View {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            hostContent.sceneAccessory {
                CameraCaptureAccessory(isEnabled: .constant(isActive)) {
                    TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                        let current = content()
                        QuarterTurn(isTurned: isQuarterTurned()) {
                            OuterDisplayBackdrop(content: current)
                        } content: {
                            switch current {
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
                    }
                    // PRD §1.3 — the camera facing the guessers is, by
                    // definition, whatever faces *this* scene's view.
                    .background { CameraDirectionProbe(onChange: onForwardCameras) }
                    // The accessory is its own scene: it does not inherit the
                    // host's environment, so `Text("literal")` would follow
                    // the system language instead of the in-app choice.
                    .environment(\.locale, locale)
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
        locale: Locale,
        onForwardCameras: @escaping @MainActor ([CameraDirectionResolver.Candidate]) -> Void,
        isQuarterTurned: @escaping () -> Bool,
        content: @escaping () -> OuterDisplayContent?
    ) -> some View {
        modifier(OuterDisplayModifier(
            isActive: isActive,
            content: content,
            isQuarterTurned: isQuarterTurned,
            availability: availability,
            locale: locale,
            onForwardCameras: onForwardCameras
        ))
    }
}

/// Turns the outer display's content a quarter turn in tabletop posture.
/// Folded into a tent, the outer panel faces the guessers on its side, so
/// without this every line of text would read sideways to them.
///
/// The content is laid out with width and height swapped, then rotated
/// about the **panel's** centre, with equal margins at both ends wide enough
/// to clear the camera cluster's inset. The backdrop
/// is drawn separately, unrotated and full-bleed — a rotated view's own
/// `ignoresSafeArea` would compute the insets in the wrong frame.
///
/// The accessory scene reports `.portrait` (checked with a probe on the
/// Duo simulator), so `angle` is relative to the panel's own up. Note that
/// `simctl io screenshot` returns that panel's framebuffer turned a further
/// 180°; that is the capture, not the app. Whether a clockwise turn is right
/// on a real Duo can only be confirmed on hardware (M8 checklist) — `angle`
/// is the one place to correct it.
struct QuarterTurn<Backdrop: View, Content: View>: View {
    static var angle: Angle { .degrees(90) }

    let isTurned: Bool
    @ViewBuilder let backdrop: () -> Backdrop
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            backdrop()
                .ignoresSafeArea()
            if isTurned {
                GeometryReader { proxy in
                    let insets = proxy.safeAreaInsets
                    let panel = CGSize(
                        width: proxy.size.width + insets.leading + insets.trailing,
                        height: proxy.size.height + insets.top + insets.bottom
                    )
                    // After the turn the panel's top and bottom become the
                    // left and right ends. Give both ends the larger inset,
                    // so the content clears the camera cluster and still
                    // sits dead centre on the glass. Centring in the safe
                    // area instead pushed everything away from the camera.
                    let endMargin = max(insets.top, insets.bottom)
                    // The other two sides report no inset, but a strip of
                    // breathing room keeps the layout from touching the
                    // rounded corners.
                    let sideMargin: CGFloat = 20
                    content()
                        .ignoresSafeArea()
                        .frame(width: panel.height - 2 * endMargin, height: panel.width - 2 * sideMargin)
                        .rotationEffect(Self.angle)
                        .frame(width: panel.width, height: panel.height)
                        .offset(x: -insets.leading, y: -insets.top)
                }
            } else {
                content()
            }
        }
    }
}

/// The full-bleed colour behind whatever the outer display shows: the
/// countdown colour during a live round, black otherwise.
private struct OuterDisplayBackdrop: View {
    let content: OuterDisplayContent?

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        switch content {
        case .liveRound(let snapshot):
            CountdownColor.background(
                fractionElapsed: snapshot.fractionElapsed,
                increaseContrast: colorSchemeContrast == .increased
            )
        case .roundSummary, .matchEnd, nil:
            Color.black
        }
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
