#if os(iOS)
import AVFoundation
import Observation

/// Owns the `AVCaptureSession` whose existence is what makes the outer
/// display available at all (PRD §1.2.2, confirmed in `UISceneAccessory.h`:
/// the accessory "may be presented while the app is in the foreground and
/// has an active camera capture session").
///
/// M5 scope: **video only**, started for the duration of a round and torn
/// down at round end (PRD §5.2). M6 extends this into the real reaction
/// pipeline — audio input, the direction coordinator that picks whichever
/// cameras face the guessers, the rolling buffer and export. Deliberately
/// not built here: which camera faces the guessers must be resolved against
/// the *accessory scene's* root view (PRD §1.3), which only exists once M6
/// wires up the preview.
///
/// Every failure is silent (CLAUDE.md §4). There is no error surface: if a
/// session can't run, `state` becomes `.none`, the outer display never
/// appears, and the game plays on.
@MainActor
@Observable
public final class CaptureSessionController {
    public private(set) var state: CaptureState = .none
    public private(set) var isRunning = false

    private let session = SessionBox()
    private let deviceProvider: @Sendable () -> AVCaptureDevice?

    /// The device lookup is injectable so tests don't need a camera.
    public init(deviceProvider: @escaping @Sendable () -> AVCaptureDevice? = CaptureSessionController.defaultVideoDevice) {
        self.deviceProvider = deviceProvider
    }

    public static let defaultVideoDevice: @Sendable () -> AVCaptureDevice? = {
        AVCaptureDevice.default(for: .video)
    }

    /// Starts a video-only session for the round. A no-op when the resolved
    /// capture state rules the camera out.
    public func start(state: CaptureState) {
        self.state = state
        guard state.enablesOuterDisplay else {
            isRunning = false
            return
        }

        let provider = deviceProvider
        let box = session
        isRunning = true

        Task.detached(priority: .userInitiated) {
            let started = box.configureAndStart(using: provider)
            await MainActor.run {
                // A device that isn't there, an input that won't attach, a
                // session that won't run: all the same outcome, silently.
                self.isRunning = started
                if !started {
                    self.state = .none
                }
            }
        }
    }

    public func stop() {
        isRunning = false
        state = .none
        let box = session
        Task.detached(priority: .utility) {
            box.stop()
        }
    }
}

/// `AVCaptureSession` is not `Sendable` and its configuration and
/// start/stop calls block, so all access is confined to one serial queue and
/// the box vouches for that confinement.
private final class SessionBox: @unchecked Sendable {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.ryopang.partycharades.capture")
    private var isConfigured = false

    func configureAndStart(using provider: @Sendable () -> AVCaptureDevice?) -> Bool {
        queue.sync {
            if !isConfigured {
                guard let device = provider(),
                      let input = try? AVCaptureDeviceInput(device: device) else {
                    return false
                }
                session.beginConfiguration()
                // 720p30 capped (PRD §5.2); M6 steps this down under thermal
                // pressure via systemPressureCost.
                if session.canSetSessionPreset(.hd1280x720) {
                    session.sessionPreset = .hd1280x720
                }
                guard session.canAddInput(input) else {
                    session.commitConfiguration()
                    return false
                }
                session.addInput(input)
                session.commitConfiguration()
                isConfigured = true
            }

            if !session.isRunning {
                session.startRunning()
            }
            return session.isRunning
        }
    }

    func stop() {
        queue.sync {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }
}
#endif
