import Testing
@testable import Capture

/// PRD §5.3 / §7.3. The point of these is the asymmetry: losing the
/// microphone must never cost the outer display, because the accessory needs
/// a video session, not an audio one.
struct CaptureStateTests {
    @Test func fullRequiresBothGrants() {
        let state = CaptureStateResolver.resolve(
            reactionCameraEnabled: true,
            cameraAuthorized: true,
            audioEnabled: true,
            microphoneAuthorized: true
        )
        #expect(state == .full)
        #expect(state.enablesOuterDisplay)
        #expect(state.recordsAudio)
    }

    @Test func deniedMicrophoneCostsSoundAndNothingElse() {
        let state = CaptureStateResolver.resolve(
            reactionCameraEnabled: true,
            cameraAuthorized: true,
            audioEnabled: true,
            microphoneAuthorized: false
        )
        #expect(state == .silent)
        #expect(state.enablesOuterDisplay, "the accessory needs video, not audio")
        #expect(!state.recordsAudio)
    }

    @Test func audioToggleOffAlsoYieldsSilentNotNone() {
        let state = CaptureStateResolver.resolve(
            reactionCameraEnabled: true,
            cameraAuthorized: true,
            audioEnabled: false,
            microphoneAuthorized: true
        )
        #expect(state == .silent)
        #expect(state.enablesOuterDisplay)
    }

    @Test func deniedCameraCostsTheReelAndTheOuterDisplay() {
        let state = CaptureStateResolver.resolve(
            reactionCameraEnabled: true,
            cameraAuthorized: false,
            audioEnabled: true,
            microphoneAuthorized: true
        )
        #expect(state == .none)
        #expect(!state.enablesOuterDisplay)
    }

    @Test func masterToggleOffGivesUpTheOuterDisplayEvenWhenAuthorized() {
        let state = CaptureStateResolver.resolve(
            reactionCameraEnabled: false,
            cameraAuthorized: true,
            audioEnabled: true,
            microphoneAuthorized: true
        )
        #expect(state == .none)
    }
}

@MainActor
struct AccessoryAvailabilityTests {
    @Test func startsUnavailable() {
        #expect(AccessoryAvailability().isAvailable == false)
    }

    @Test func tracksSystemGrantAndRevocation() {
        let availability = AccessoryAvailability()
        availability.update(isAvailable: true)
        #expect(availability.isAvailable)
        // Mid-round revocation: the flag flips and that is the entire
        // consequence (PRD §3.4).
        availability.update(isAvailable: false)
        #expect(!availability.isAvailable)
    }
}
