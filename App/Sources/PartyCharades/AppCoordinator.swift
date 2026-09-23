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

    var isRecording: Bool {
        #if os(iOS)
        return captureSession.isRunning
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
    }

    /// PRD §3.1 — the *only* posture event that pauses a match is `.closed`.
    /// Tabletop ⇄ flat transitions just reflow the layout mid-round.
    func postureChanged(to posture: PostureState) {
        guard posture == .closed, screen == .gameplay, let engine, !engine.isPaused else { return }
        engine.pauseTurn()
        setIdleTimerDisabled(false)
        stopCapture()
    }

    func resumeFromPause() {
        guard let engine, engine.isPaused else { return }
        engine.resumeTurn()
        setIdleTimerDisabled(true)
        startCapture()
    }

    /// The pause button on the gameplay screens — a manual counterpart to
    /// `postureChanged(to: .closed)`. Lands on the same `PausedView`, which
    /// now offers both Resume and Exit regardless of which triggered it.
    func pauseMatch() {
        guard let engine, !engine.isPaused, screen == .gameplay else { return }
        engine.pauseTurn()
        setIdleTimerDisabled(false)
        stopCapture()
    }

    /// PRD §5.2 — capture runs only during an active round; the session is
    /// torn down at round end. Its only M5 job is making the outer display
    /// available (§1.2.2); M6 turns it into the actual reel.
    private func startCapture() {
        #if os(iOS)
        let state = CaptureStateResolver.resolve(
            reactionCameraEnabled: settings.reactionCameraEnabled,
            cameraAuthorized: CapturePermissions.cameraAuthorized,
            audioEnabled: settings.reactionAudioEnabled,
            microphoneAuthorized: CapturePermissions.microphoneAuthorized
        )
        captureSession.start(state: state)
        #endif
    }

    private func stopCapture() {
        #if os(iOS)
        captureSession.stop()
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
        stopCapture()
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
        stopCapture()
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
            language: settings.lastUsedLanguage,
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
        settings.lastUsedLanguage = configuration.language
        let words = contentStore.words(in: configuration.categories)
        do {
            let engine = try GameEngine(configuration: configuration, words: words)
            self.engine = engine
            self.startError = nil
            engine.startTurn()
            screen = .gameplay
            setIdleTimerDisabled(true)
            startCapture()
            #if canImport(UIKit)
            FeedbackPlayer.shared.resetTickTracking()
            #endif
        } catch {
            startError = "Not enough words in the selected categories to start a match."
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
        FeedbackPlayer.shared.tickIfNeeded(secondsRemaining: timer.displaySecondsRemaining(now: now))
        #endif
    }

    func endCurrentTurn() {
        guard let engine, engine.timer != nil else { return }
        lastTurnResult = engine.endTurn()
        screen = .roundSummary
        setIdleTimerDisabled(false)
        // Capture keeps running through round summary and Game Over now —
        // the outer display needs an active session to stay lit that whole
        // time (§1.2.2). It only stops in `returnHome()` /
        // `startNewCustomGame()`, or implicitly restarts for the next match.
    }

    func continueAfterRoundSummary() {
        guard let engine else { return }
        if engine.matchState.isMatchComplete {
            screen = .matchEnd
        } else {
            engine.startTurn()
            screen = .gameplay
            setIdleTimerDisabled(true)
            startCapture()
            #if canImport(UIKit)
            FeedbackPlayer.shared.resetTickTracking()
            #endif
        }
    }
}
