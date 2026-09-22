/// PRD §10.4 — `.ambient` with `mixWithOthers` when not recording, so the
/// party's music keeps playing from other apps. During a round with audio
/// capture the category must become `.playAndRecord` with `mixWithOthers`
/// **and** `defaultToSpeaker`. Return to `.ambient` the moment the round
/// ends — never hold a recording category across the summary screen.
///
/// Kept as a pure decision (no AVFoundation dependency) so the policy itself
/// is unit-testable; `CaptureSessionController` applies it to the real
/// `AVAudioSession`.
public enum AudioSessionPolicy: Sendable, Equatable {
    case ambient
    case recording

    public static func resolve(captureState: CaptureState) -> AudioSessionPolicy {
        captureState.recordsAudio ? .recording : .ambient
    }
}
