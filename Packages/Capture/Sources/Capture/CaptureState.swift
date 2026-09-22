/// PRD §5.3 — three states, resolved at match start, each degrading silently.
public enum CaptureState: Sendable, Equatable {
    /// Camera + microphone granted. Reel with sound, outer display active.
    case full
    /// Camera granted, microphone denied or audio switched off. Silent reel,
    /// outer display still active — the accessory needs a *video* session,
    /// so losing the microphone costs sound and nothing else.
    case silent
    /// No camera. No reel, no outer display. The game plays normally.
    case none

    /// PRD §1.2.2 — the outer display exists only while a video capture
    /// session is running.
    public var enablesOuterDisplay: Bool { self != .none }

    public var recordsAudio: Bool { self == .full }
}

public enum CaptureStateResolver {
    /// `reactionCameraEnabled` is the §7.3 master toggle; `audioEnabled` is
    /// its audio-off sub-toggle. Turning the master off is a deliberate
    /// choice to give up the outer display, which the settings copy explains.
    public static func resolve(
        reactionCameraEnabled: Bool,
        cameraAuthorized: Bool,
        audioEnabled: Bool,
        microphoneAuthorized: Bool
    ) -> CaptureState {
        guard reactionCameraEnabled, cameraAuthorized else { return .none }
        return audioEnabled && microphoneAuthorized ? .full : .silent
    }
}
