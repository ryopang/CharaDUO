#if os(iOS)
import AVFoundation
import CoreMedia
import Observation

/// Owns the `AVCaptureSession` and the reaction reel it feeds.
///
/// Two jobs, in PRD §5.1's order: film the guessing team for the highlight
/// reel, and — because `UISceneAccessory.h` only presents the camera-capture
/// accessory "while the app is in the foreground and has an active camera
/// capture session" — keep the outer display available.
///
/// **Lifecycle.** The session spans the whole match (CLAUDE.md §4) so the
/// outer display can mirror the round summary and Game Over; it stops only
/// when the player leaves the match or pauses. *Recording* is narrower: only
/// during a live, unpaused round, only once the direction coordinator has
/// said which camera faces the guessers (PRD §1.3), and never after thermal
/// pressure has ruled it out. The microphone input and `.playAndRecord` are
/// attached per round, so neither is held across the summary (PRD §10.4).
///
/// **Camera choice.** Nothing is hardcoded. The session starts on a
/// bootstrap camera purely so the accessory scene can appear; the
/// `AVCaptureDeviceDirectionCoordinator` living in that scene then reports
/// the forward-facing cameras through `forwardFacingCamerasChanged(_:)`, and
/// the input is swapped to the preferred one. Until that first report,
/// nothing is written to disk.
///
/// Every failure is silent (CLAUDE.md §4). There is no error surface.
@MainActor
@Observable
public final class CaptureSessionController {
    public private(set) var state: CaptureState = .none
    public private(set) var isSessionRunning = false
    /// Frames are going to disk right now. Drives the recording indicators on
    /// both displays (PRD §7.3), so it is deliberately the narrow meaning.
    public private(set) var isRecording = false

    public let store: ReelStore
    private let recorder = ReactionRecorder()
    private let box: SessionBox

    private var matchDirectory: URL?
    private var roundActive = false
    private var roundPaused = false
    private var cameraResolved = false
    private var thermal: ThermalPolicy = .full
    private var currentCameraID: String?
    private var clock: CMClock = CMClockGetHostTimeClock()
    private var pressureObservation: NSKeyValueObservation?
    private var rotationObservation: NSKeyValueObservation?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var lastCandidates: [CameraDirectionResolver.Candidate]?

    #if DEBUG
    /// `-uiTestSyntheticCamera` — generated frames through the real
    /// recorder, so the reel is exercisable on the simulator (CLAUDE.md §6).
    public var usesSyntheticCamera = false
    private var synthetic: SyntheticFrameSource?
    #endif

    public init(store: ReelStore = ReelStore()) {
        self.store = store
        self.box = SessionBox(recorder: recorder)
    }

    /// PRD §1.2.4 — there is no Duo capability key, so this is detected
    /// rather than declared: only Duo hardware reports the outer ultra-wide
    /// device type. On anything else the camera never switches on, so no
    /// privacy indicator lights up for a feature that can't exist there.
    public static var isDuoHardware: Bool {
        guard #available(iOS 27.1, *) else { return false }
        return !AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInOuterUltraWideCamera],
            mediaType: .video,
            position: .unspecified
        ).devices.isEmpty
    }

    // MARK: Match lifecycle

    public func beginMatch(state requested: CaptureState) {
        endMatch()
        store.purgeAll()
        thermal = .full
        recorder.setEncoding(.full)
        state = requested
        guard requested.enablesOuterDisplay, let directory = store.makeMatchDirectory() else {
            state = .none
            return
        }
        matchDirectory = directory

        #if DEBUG
        if usesSyntheticCamera {
            let source = SyntheticFrameSource(recorder: recorder, includeAudio: requested.recordsAudio)
            synthetic = source
            clock = source.clock
            cameraResolved = true
            source.start()
            return
        }
        #endif

        guard Self.isDuoHardware else {
            state = .none
            return
        }
        startSession()
    }

    /// Leaving the match: home, a new custom game, rematch. Everything
    /// unsaved is deleted here (PRD §4.2, §7.2.3).
    public func endMatch() {
        roundActive = false
        roundPaused = false
        recorder.discardRound()
        stopSession()
        #if DEBUG
        synthetic?.stop()
        synthetic = nil
        #endif
        cameraResolved = false
        currentCameraID = nil
        lastCandidates = nil
        matchDirectory = nil
        state = .none
        updateRecording()
        store.purgeAll()
    }

    // MARK: Round lifecycle

    public func beginRound() {
        guard let matchDirectory, state.enablesOuterDisplay else { return }
        roundActive = true
        roundPaused = false
        let roundDirectory = matchDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: roundDirectory, withIntermediateDirectories: true)
        // Unarmed: `updateRecording()` arms it only once the camera facing
        // the guessers is known, so the bootstrap camera never reaches disk.
        recorder.beginRound(directory: roundDirectory, recordsAudio: state.recordsAudio, armed: false)
        isRecording = false
        attachRoundAudio(true)
        updateRecording()
    }

    /// Only a `.closed` fold or the pause button get here. The session stops
    /// (as it always has on pause); the round's footage so far is kept.
    public func pauseRound() {
        guard roundActive else { return }
        roundPaused = true
        attachRoundAudio(false)
        stopSession()
        #if DEBUG
        synthetic?.stop()
        #endif
        updateRecording()
    }

    public func resumeRound() {
        guard roundActive, roundPaused else { return }
        roundPaused = false
        #if DEBUG
        if let synthetic {
            synthetic.start()
            attachRoundAudio(true)
            updateRecording()
            return
        }
        #endif
        if state.enablesOuterDisplay { startSession() }
        attachRoundAudio(true)
        updateRecording()
    }

    /// Round over: close the buffer and hand back the highlights, if any.
    /// The session keeps running for the outer display; the microphone and
    /// recording category do not.
    public func endRound() async -> RoundReel? {
        guard roundActive else { return nil }
        roundActive = false
        roundPaused = false
        attachRoundAudio(false)
        updateRecording()
        return await recorder.endRound()
    }

    /// A Correct tap. Stamped here, on the capture clock, so the highlight
    /// window lines up with the frames regardless of queue latency.
    public func markHighlight() {
        guard isRecording else { return }
        recorder.markHighlight(at: CMClockGetTime(clock).seconds)
    }

    // MARK: Camera direction (PRD §1.3)

    /// Called by the direction coordinator in the accessory scene, on main,
    /// every time the set of cameras facing the outer display changes.
    public func forwardFacingCamerasChanged(_ candidates: [CameraDirectionResolver.Candidate]) {
        #if DEBUG
        if synthetic != nil { return }
        #endif
        lastCandidates = candidates
        guard isSessionRunning, state.enablesOuterDisplay else { return }
        guard let choice = CameraDirectionResolver.preferred(from: candidates) else {
            // Nothing faces the guessers (e.g. the hinge moved). No reel
            // until something does — PRD §5.7, silently.
            cameraResolved = false
            updateRecording()
            return
        }
        guard choice.uniqueID != currentCameraID || !cameraResolved else { return }
        let box = self.box
        Task.detached(priority: .userInitiated) {
            let device = box.swapVideoDevice(uniqueID: choice.uniqueID)
            await MainActor.run {
                guard let device else {
                    self.cameraResolved = false
                    self.updateRecording()
                    return
                }
                self.currentCameraID = choice.uniqueID
                self.cameraResolved = true
                self.observe(device: device)
                self.recorder.requestNewSegment()
                self.updateRecording()
            }
        }
    }

    // MARK: Private

    private func updateRecording() {
        let shouldRecord = roundActive && !roundPaused && cameraResolved
            && thermal != .stopRecording && state.enablesOuterDisplay
        if shouldRecord == isRecording { return }
        isRecording = shouldRecord
        if shouldRecord {
            recorder.resume(recordsAudio: state.recordsAudio)
        } else if roundActive {
            recorder.suspend()
        }
    }

    private func startSession() {
        let box = self.box
        let wantsAudioInput = roundActive && state.recordsAudio
        isSessionRunning = true
        Task.detached(priority: .userInitiated) {
            let result = box.configureAndStart(includeAudio: wantsAudioInput)
            await MainActor.run {
                self.isSessionRunning = result.running
                if let clock = result.clock { self.clock = clock }
                if let device = result.device { self.observe(device: device) }
                if !result.running {
                    // No device, no input, no session: all the same outcome.
                    self.state = .none
                    self.cameraResolved = false
                }
                self.updateRecording()
                // The coordinator may have reported before the session was
                // configured enough to swap inputs; apply that report now.
                if result.running, !self.cameraResolved, let candidates = self.lastCandidates {
                    self.forwardFacingCamerasChanged(candidates)
                }
            }
        }
    }

    private func stopSession() {
        isSessionRunning = false
        pressureObservation = nil
        rotationObservation = nil
        rotationCoordinator = nil
        let box = self.box
        Task.detached(priority: .utility) { box.stop() }
    }

    /// PRD §10.4 — `.playAndRecord` only while a round is actually taking
    /// audio; `.ambient` the moment it isn't.
    private func attachRoundAudio(_ attach: Bool) {
        let recordsAudio = attach && state.recordsAudio
        let policy: AudioSessionPolicy = recordsAudio ? .recording : .ambient
        let box = self.box
        #if DEBUG
        let isSynthetic = synthetic != nil
        #else
        let isSynthetic = false
        #endif
        Task.detached(priority: .userInitiated) {
            box.applyAudioSession(policy)
            if !isSynthetic { box.setAudioInput(enabled: recordsAudio) }
        }
    }

    /// Thermal pressure (PRD §5.3) and horizon-level rotation for whichever
    /// camera is currently live.
    private func observe(device: AVCaptureDevice) {
        let recorder = self.recorder
        pressureObservation = Self.observePressure(of: device) { [weak self] level in
            Task { @MainActor [weak self] in self?.applyPressure(level) }
        }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        rotationCoordinator = coordinator
        recorder.setRotationAngle(degrees: coordinator.videoRotationAngleForHorizonLevelCapture)
        rotationObservation = Self.observeRotation(of: coordinator) { angle in
            recorder.setRotationAngle(degrees: angle)
        }
    }

    // AVFoundation fires these KVO handlers on its own capture threads.
    // Written inline in this @MainActor class, Swift 6 would infer main-actor
    // isolation for the closures and trap there at runtime (the simulator
    // never exercises this path — only hardware does), so they are built in
    // nonisolated functions and hop to main explicitly.

    private nonisolated static func observePressure(
        of device: AVCaptureDevice,
        onChange: @escaping @Sendable (ThermalPolicy.Level) -> Void
    ) -> NSKeyValueObservation {
        device.observe(\.systemPressureState, options: [.initial, .new]) { device, _ in
            onChange(level(device.systemPressureState.level))
        }
    }

    private nonisolated static func observeRotation(
        of coordinator: AVCaptureDevice.RotationCoordinator,
        onChange: @escaping @Sendable (Double) -> Void
    ) -> NSKeyValueObservation {
        coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { coordinator, _ in
            onChange(coordinator.videoRotationAngleForHorizonLevelCapture)
        }
    }

    private func applyPressure(_ level: ThermalPolicy.Level) {
        let next = ThermalPolicy.next(current: thermal, level: level)
        guard next != thermal else { return }
        thermal = next
        switch next {
        case .full: recorder.setEncoding(.full)
        case .reduced: recorder.setEncoding(.reduced)
        case .stopRecording: break
        }
        updateRecording()
    }

    private nonisolated static func level(_ level: AVCaptureDevice.SystemPressureState.Level) -> ThermalPolicy.Level {
        switch level {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        case .shutdown: return .shutdown
        default: return .serious
        }
    }
}

/// `AVCaptureSession` is not `Sendable` and its configuration and
/// start/stop calls block, so all access is confined to one serial queue and
/// the box vouches for that confinement.
private final class SessionBox: @unchecked Sendable {
    struct StartResult: @unchecked Sendable {
        let running: Bool
        let device: AVCaptureDevice?
        let clock: CMClock?
    }

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.ryopang.partycharades.capture")
    private let recorder: ReactionRecorder
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var isConfigured = false

    init(recorder: ReactionRecorder) {
        self.recorder = recorder
    }

    /// The bootstrap camera: whatever gets the session running so the
    /// accessory scene can appear. It is *not* a claim about which camera
    /// faces the guessers — the direction coordinator replaces it.
    private func bootstrapDevice() -> AVCaptureDevice? {
        if #available(iOS 27.1, *),
           let outer = AVCaptureDevice.default(.builtInOuterUltraWideCamera, for: .video, position: .unspecified) {
            return outer
        }
        return AVCaptureDevice.default(for: .video)
    }

    func configureAndStart(includeAudio: Bool) -> StartResult {
        queue.sync {
            if !isConfigured {
                guard let device = bootstrapDevice(),
                      let input = try? AVCaptureDeviceInput(device: device) else {
                    return StartResult(running: false, device: nil, clock: nil)
                }
                session.beginConfiguration()
                // The app owns the audio session category (PRD §10.4); the
                // capture session must not reconfigure it behind our back.
                session.automaticallyConfiguresApplicationAudioSession = false
                // 720p30 capped (PRD §5.2); thermal step-down is done in the
                // encoder so the preset never has to change mid-round.
                if session.canSetSessionPreset(.hd1280x720) {
                    session.sessionPreset = .hd1280x720
                }
                guard session.canAddInput(input) else {
                    session.commitConfiguration()
                    return StartResult(running: false, device: nil, clock: nil)
                }
                session.addInput(input)
                videoInput = input

                let videoOutput = AVCaptureVideoDataOutput()
                videoOutput.alwaysDiscardsLateVideoFrames = true
                videoOutput.setSampleBufferDelegate(recorder, queue: recorder.queue)
                if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

                let audioOutput = AVCaptureAudioDataOutput()
                audioOutput.setSampleBufferDelegate(recorder, queue: recorder.queue)
                if session.canAddOutput(audioOutput) { session.addOutput(audioOutput) }

                session.commitConfiguration()
                isConfigured = true
            }

            setAudioInputLocked(enabled: includeAudio)
            if !session.isRunning {
                session.startRunning()
            }
            return StartResult(running: session.isRunning, device: videoInput?.device, clock: session.synchronizationClock)
        }
    }

    func stop() {
        queue.sync {
            setAudioInputLocked(enabled: false)
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    /// Swaps to the camera the direction coordinator chose. Returns the live
    /// device, or nil if the swap failed (the old input is restored).
    func swapVideoDevice(uniqueID: String) -> AVCaptureDevice? {
        queue.sync {
            guard isConfigured else { return nil }
            if videoInput?.device.uniqueID == uniqueID { return videoInput?.device }
            guard let device = AVCaptureDevice(uniqueID: uniqueID),
                  let input = try? AVCaptureDeviceInput(device: device) else { return nil }
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            let old = videoInput
            if let old { session.removeInput(old) }
            guard session.canAddInput(input) else {
                if let old, session.canAddInput(old) { session.addInput(old) }
                return nil
            }
            session.addInput(input)
            videoInput = input
            return device
        }
    }

    func setAudioInput(enabled: Bool) {
        queue.sync { setAudioInputLocked(enabled: enabled) }
    }

    /// PRD §5.3 — denying the microphone costs sound on the reel and nothing
    /// else, so a failure here is simply "no audio input".
    private func setAudioInputLocked(enabled: Bool) {
        guard isConfigured else { return }
        if enabled, audioInput == nil {
            guard let microphone = AVCaptureDevice.default(for: .audio),
                  let input = try? AVCaptureDeviceInput(device: microphone) else { return }
            session.beginConfiguration()
            if session.canAddInput(input) {
                session.addInput(input)
                audioInput = input
            }
            session.commitConfiguration()
        } else if !enabled, let input = audioInput {
            session.beginConfiguration()
            session.removeInput(input)
            session.commitConfiguration()
            audioInput = nil
        }
    }

    /// Silent on failure (CLAUDE.md §4) — an audio session error never
    /// blocks gameplay, it just means routing/ducking behaves like whatever
    /// the system's previous category was.
    func applyAudioSession(_ policy: AudioSessionPolicy) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            switch policy {
            case .ambient:
                try audioSession.setCategory(.ambient, options: [.mixWithOthers])
            case .recording:
                try audioSession.setCategory(.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker])
            }
            try audioSession.setActive(true)
        } catch {
            // Intentionally silent.
        }
    }
}
#endif
