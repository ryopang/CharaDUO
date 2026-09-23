import Capture
import Content
import Core
import Foundation
import Observation
import Posture
#if canImport(UIKit)
import UIKit
#endif

/// Owns navigation between the setup, gameplay, round-summary and match-end
/// screens, and creates/discards the `GameEngine` for each match. No UI code.
@MainActor
@Observable
final class AppCoordinator {
    enum Screen: Equatable {
        case home
        case customGame
        case captureConsent
        case gameplay
        case roundSummary
        case matchEnd
    }

    private(set) var screen: Screen = .home
    private(set) var engine: GameEngine?
    private(set) var lastTurnResult: TurnResult?
    var startError: String?

    let settings: AppSettings
    let hinge = HingeObserver()
    let accessoryAvailability = AccessoryAvailability()
    private let contentStore: ContentStore
    #if os(iOS)
    private let captureSession = CaptureSessionController()
    #endif

    /// PRD §5.5 — one highlight reel per completed turn that produced one,
    /// keyed by the turn's index in `matchState.completedTurns`. Arrives a
    /// moment after the turn ends (the last segment has to finish writing),
    /// so the round summary shows its clip section when it lands rather than
    /// ever waiting for it. Deleted with the match (PRD §7.2).
    private(set) var reels: [Int: RoundReel] = [:]

    /// The reel for the round summary currently on screen, if any.
    var lastTurnReel: RoundReel? {
        guard let engine, !engine.matchState.completedTurns.isEmpty else { return nil }
        return reels[engine.matchState.completedTurns.count - 1]
    }

    /// Every reel of the match, in play order — the Game Over reel.
    var matchReels: [(turn: TurnResult, reel: RoundReel)] {
        guard let engine else { return [] }
        return engine.matchState.completedTurns.enumerated().compactMap { index, turn in
            reels[index].map { (turn, $0) }
        }
    }

    /// A pending configuration held while the consent card is up, so
    /// accepting or declining resumes the exact match the player asked for.
    private var pendingConfiguration: MatchConfiguration?

    /// PRD §3.4 — what the outer display draws, or nil when there's nothing
    /// to show. Read-only projection; see `OuterDisplayContent`. Stays lit
    /// through round summary and Game Over now, not just the live round, so
    /// the capture session that makes the accessory available has to
    /// survive that long too — see `endCurrentTurn()`.
    var outerDisplayContent: OuterDisplayContent? {
        switch screen {
        case .gameplay:
            guard let engine, !engine.isPaused,
                  let snapshot = engine.scoreboardSnapshot(isRecording: isRecording) else { return nil }
            return .liveRound(snapshot)
        case .roundSummary:
            guard let engine, let lastTurnResult else { return nil }
            return .roundSummary(engine.roundSummarySnapshot(for: lastTurnResult))
        case .matchEnd:
            guard let engine else { return nil }
            return .matchEnd(engine.matchState.matchEndSnapshot)
        case .home, .customGame, .captureConsent:
            return nil
        }
    }

    /// Whether the outer-display scene accessory should be presented at all.
    var isOuterDisplayActive: Bool {
        switch screen {
        case .gameplay, .roundSummary, .matchEnd: return true
        case .home, .customGame, .captureConsent: return false
        }
    }

    /// Frames are going to disk right now — drives the recording
    /// indicators on both displays (PRD §7.3).
    var isRecording: Bool {
        #if os(iOS)
        return captureSession.isRecording
        #else
        return false
        #endif
    }

    var posture: PostureState {
        #if DEBUG
        if let forced = DebugOverrides.posture { return forced }
        #endif
        return hinge.posture
    }

    init(contentStore: ContentStore, settings: AppSettings = AppSettings()) {
        self.contentStore = contentStore
        self.settings = settings
        #if os(iOS) && DEBUG
        captureSession.usesSyntheticCamera = DebugOverrides.syntheticCamera
        #endif
    }

    /// PRD §3.1 — the *only* posture event that pauses a match is `.closed`.
    /// Tabletop ⇄ flat transitions just reflow the layout mid-round.
    func postureChanged(to posture: PostureState) {
        guard posture == .closed, screen == .gameplay, let engine, !engine.isPaused else { return }
        engine.pauseTurn()
        setIdleTimerDisabled(false)
        pauseCapture()
    }

    func resumeFromPause() {
        guard let engine, engine.isPaused else { return }
        engine.resumeTurn()
        setIdleTimerDisabled(true)
        resumeCapture()
    }

    /// The pause button on the gameplay screens — a manual counterpart to
    /// `postureChanged(to: .closed)`. Lands on the same `PausedView`, which
    /// now offers both Resume and Exit regardless of which triggered it.
    func pauseMatch() {
        guard let engine, !engine.isPaused, screen == .gameplay else { return }
        engine.pauseTurn()
        setIdleTimerDisabled(false)
        pauseCapture()
    }

    /// A Correct tap: score it, give feedback, and mark the reaction reel's
    /// highlight at the same instant (PRD §5.5). Core stays capture-free.
    func recordCorrect() {
        guard let engine else { return }
        engine.markCorrectWithFeedback()
        #if os(iOS)
        captureSession.markHighlight()
        #endif
    }

    /// From the direction coordinator living in the outer accessory scene
    /// (PRD §1.3) — which cameras face the guessers, live as the hinge moves.
    func forwardFacingCamerasChanged(_ candidates: [CameraDirectionResolver.Candidate]) {
        #if os(iOS)
        captureSession.forwardFacingCamerasChanged(candidates)
        #endif
    }

    #if os(iOS)
    /// PRD §5.6 — render once, at Save, at the chosen speed.
    func save(_ reels: [RoundReel], speed: ReelSpeed) async -> ReelSaver.Outcome {
        await ReelSaver.save(reels, speed: speed, store: captureSession.store)
    }
    #endif

    // MARK: Capture lifecycle
    //
    // The session spans the match (CLAUDE.md §4 — the outer display mirrors
    // summary and Game Over); recording spans only live rounds. Everything
    // here degrades silently.

    /// PRD §5.3 — resolved once, at match start.
    private func resolvedCaptureState() -> CaptureState {
        #if DEBUG
        if let forced = DebugOverrides.captureState { return forced }
        #endif
        #if os(iOS)
        return CaptureStateResolver.resolve(
            reactionCameraEnabled: settings.reactionCameraEnabled,
            cameraAuthorized: CapturePermissions.cameraAuthorized,
            audioEnabled: settings.reactionAudioEnabled,
            microphoneAuthorized: CapturePermissions.microphoneAuthorized
        )
        #else
        return .none
        #endif
    }

    private func beginMatchCapture() {
        reels = [:]
        #if os(iOS)
        captureSession.beginMatch(state: resolvedCaptureState())
        #endif
    }

    private func beginRoundCapture() {
        #if os(iOS)
        captureSession.beginRound()
        #endif
    }

    private func endRoundCapture(turnIndex: Int) {
        #if os(iOS)
        let session = captureSession
        Task { [weak self] in
            guard let reel = await session.endRound() else { return }
            // The match may have been left while the last segment finished;
            // footage for a match that no longer exists is deleted, not kept.
            guard let self, self.engine != nil, self.engine?.matchState.completedTurns.count ?? 0 > turnIndex else {
                for segment in reel.segments { try? FileManager.default.removeItem(at: segment.url) }
                return
            }
            self.reels[turnIndex] = reel
        }
        #endif
    }

    private func pauseCapture() {
        #if os(iOS)
        captureSession.pauseRound()
        #endif
    }

    private func resumeCapture() {
        #if os(iOS)
        captureSession.resumeRound()
        #endif
    }

    /// Leaving the match: anything unsaved is deleted (PRD §4.2, §7.2.3).
    private func endMatchCapture() {
        reels = [:]
        #if os(iOS)
        captureSession.endMatch()
        #endif
    }

    /// PRD §10.3 — the screen must not sleep mid-round, and must be allowed
    /// to sleep at every other moment.
    private func setIdleTimerDisabled(_ disabled: Bool) {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = disabled
        #endif
    }

    func presentCustomGame() {
        screen = .customGame
    }

    func returnHome() {
        engine = nil
        lastTurnResult = nil
        startError = nil
        pendingConfiguration = nil
        screen = .home
        setIdleTimerDisabled(false)
        endMatchCapture()
    }

    /// Game Over → "New Custom Game": leaves the finished match behind (same
    /// cleanup as `returnHome()`) but lands on Custom Game instead of Home.
    func startNewCustomGame() {
        engine = nil
        lastTurnResult = nil
        startError = nil
        pendingConfiguration = nil
        screen = .customGame
        setIdleTimerDisabled(false)
        endMatchCapture()
    }

    /// Game Over → "Rematch": same configuration, fresh scores. Safe to
    /// reuse `engine.configuration` directly — `MatchState` copies
    /// `configuration.teams` on init rather than mutating them in place, so
    /// the original teams are still sitting at `score: 0`.
    func rematch() {
        guard let engine else { return }
        start(with: engine.configuration)
    }

    /// PRD §2.4 Quick Play: one tap, 2 teams, 1 random category, 60s, 2
    /// rounds, last-used language. No naming, no toggles.
    func startQuickPlay() {
        let category = GameCategory.allCases.randomElement() ?? .movie
        start(with: MatchConfiguration(
            teams: [Team(), Team()],
            roundsPerTeam: 2,
            roundDuration: .default,
            categories: [category],
            language: settings.appLanguage,
            skipPenaltyEnabled: false
        ))
    }

    func startCustomGame(_ configuration: MatchConfiguration) {
        start(with: configuration)
    }

    /// PRD §7.3 — the consent card appears once, before the first match,
    /// never mid-round. After that the camera is governed by the settings
    /// toggle alone.
    private func start(with configuration: MatchConfiguration) {
        if !settings.hasShownCaptureConsent, settings.reactionCameraEnabled {
            pendingConfiguration = configuration
            screen = .captureConsent
            return
        }
        beginMatch(with: configuration)
    }

    func acceptCaptureConsent() async {
        settings.hasShownCaptureConsent = true
        #if os(iOS)
        // Camera and microphone together, once (PRD §7.1). A denial is never
        // surfaced as an error — it only picks a narrower CaptureState.
        await CapturePermissions.requestCameraAndMicrophone()
        #endif
        resumePendingMatch()
    }

    func declineCaptureConsent() {
        settings.hasShownCaptureConsent = true
        settings.reactionCameraEnabled = false
        resumePendingMatch()
    }

    private func resumePendingMatch() {
        guard let configuration = pendingConfiguration else {
            screen = .home
            return
        }
        pendingConfiguration = nil
        beginMatch(with: configuration)
    }

    private func beginMatch(with configuration: MatchConfiguration) {
        let words = contentStore.words(in: configuration.categories)
        do {
            let engine = try GameEngine(configuration: configuration, words: words)
            self.engine = engine
            self.startError = nil
            engine.startTurn()
            screen = .gameplay
            setIdleTimerDisabled(true)
            beginMatchCapture()
            beginRoundCapture()
            #if canImport(UIKit)
            FeedbackPlayer.shared.resetTickTracking()
            #endif
        } catch {
            startError = tr("Not enough words in the selected categories to start a match.")
        }
    }

    /// Called from the countdown view whenever the clock ticks; a no-op
    /// unless the current turn's timer has actually expired (PRD §10.3 —
    /// the tick is just a redraw prompt, expiry is decided from wall-clock
    /// elapsed time, never from tick count).
    func checkForTurnExpiry(now: ContinuousClock.Instant) {
        guard screen == .gameplay, let engine, let timer = engine.timer, !timer.isPaused else { return }
        if timer.isExpired(now: now) {
            endCurrentTurn()
            return
        }
        #if canImport(UIKit)
        // PRD §10.4 — a tick per second for the final 10s, escalating.
        FeedbackPlayer.shared.tickIfNeeded(secondsRemaining: timer.displaySecondsRemaining(now: now), soundEnabled: settings.tickSoundEnabled)
        #endif
    }

    func endCurrentTurn() {
        guard let engine, engine.timer != nil else { return }
        lastTurnResult = engine.endTurn()
        screen = .roundSummary
        setIdleTimerDisabled(false)
        // Recording stops here; the session itself keeps running through
        // round summary and Game Over — the outer display needs an active
        // session to stay lit that whole time (§1.2.2). It only stops in
        // `returnHome()` / `startNewCustomGame()`, or restarts for a rematch.
        endRoundCapture(turnIndex: engine.matchState.completedTurns.count - 1)
    }

    func continueAfterRoundSummary() {
        guard let engine else { return }
        if engine.matchState.isMatchComplete {
            screen = .matchEnd
        } else {
            engine.startTurn()
            screen = .gameplay
            setIdleTimerDisabled(true)
            beginRoundCapture()
            #if canImport(UIKit)
            FeedbackPlayer.shared.resetTickTracking()
            #endif
        }
    }
}
