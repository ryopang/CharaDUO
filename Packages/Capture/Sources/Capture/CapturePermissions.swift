#if os(iOS)
import AVFoundation

/// PRD §7.1 — camera and microphone are requested **together, once**, from
/// the consent card, never mid-round. Denying the microphone costs sound on
/// the reel; denying the camera costs the reel and the outer display.
/// Neither blocks the game.
public enum CapturePermissions {
    public static var cameraAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    public static var microphoneAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    public static var hasBeenAsked: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) != .notDetermined
    }

    /// Requests both in one pass. The result is only ever used to pick a
    /// `CaptureState`; a denial is never surfaced as an error.
    @discardableResult
    public static func requestCameraAndMicrophone() async -> (camera: Bool, microphone: Bool) {
        let camera = await AVCaptureDevice.requestAccess(for: .video)
        let microphone = await AVCaptureDevice.requestAccess(for: .audio)
        return (camera, microphone)
    }
}
#endif
