import Testing
@testable import Capture

/// PRD §10.4 — `.ambient`/`mixWithOthers` unless the app is actively
/// recording audio, in which case `.playAndRecord`. The `.silent` and
/// `.none` capture states never record audio, so they must never trigger
/// the recording session policy even though `.silent` still runs video.
struct AudioSessionPolicyTests {
    @Test func fullCaptureRecordsAudio() {
        #expect(AudioSessionPolicy.resolve(captureState: .full) == .recording)
    }

    @Test func silentCaptureStaysAmbientDespiteRunningVideo() {
        #expect(AudioSessionPolicy.resolve(captureState: .silent) == .ambient)
    }

    @Test func noneStaysAmbient() {
        #expect(AudioSessionPolicy.resolve(captureState: .none) == .ambient)
    }
}
