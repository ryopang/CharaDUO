import AudioToolbox
import Core
import Design
import UIKit

/// PRD §10.4 — Correct: heavy impact + ascending chime. Skip: error
/// notification + low buzz. Final 10s: a tick per second, escalating.
/// "Respect the silent switch. Haptics must carry the full interaction on
/// their own, because they will be the only feedback much of the time" —
/// haptics fire unconditionally; `AudioServicesPlaySystemSound` already
/// respects the silent switch on its own.
///
/// Correct and Skip play the bundled `correct.caf` / `skip.caf` (converted
/// from `Sound files/*.mp3`, which stay as the editable sources). If a file
/// fails to load, the built-in system sound IDs stand in.
///
/// `UIImpactFeedbackGenerator(style:)` is soft-deprecated in this SDK in
/// favor of `feedbackGeneratorWithStyle:forView:` (iOS 17.5+), which scopes
/// haptics to a specific view. That needs a `UIView` handle SwiftUI doesn't
/// expose cleanly from a button action; the plain initializer still works
/// (not removed, not unavailable), so this uses it rather than restructure
/// every call site to capture a view for a soft warning.
@MainActor
final class FeedbackPlayer {
    static let shared = FeedbackPlayer()

    private let correctSound = FeedbackPlayer.loadSound("correct")
    private let skipSound = FeedbackPlayer.loadSound("skip")
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private var lastTickSecond: Int?

    func play(_ event: FeedbackEvent) {
        switch event.haptic {
        case .impactHeavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
        case .notificationError:
            notificationGenerator.prepare()
            notificationGenerator.notificationOccurred(.error)
        case .escalatingTick(let secondsRemaining):
            let generator = UIImpactFeedbackGenerator(style: impactStyle(forSecondsRemaining: secondsRemaining))
            generator.impactOccurred()
        }
        AudioServicesPlaySystemSound(chimeSoundID(for: event.chime))
    }

    /// Called every tick; fires at most once per integer-second boundary.
    /// A soft tick sounds every second of the round, a more present one in
    /// the final 10 seconds, where the haptic also escalates. Resets at the
    /// start of each turn so a new round always starts un-ticked.
    func tickIfNeeded(secondsRemaining: Int, soundEnabled: Bool) {
        guard secondsRemaining > 0, secondsRemaining != lastTickSecond else { return }
        lastTickSecond = secondsRemaining
        let urgent = secondsRemaining <= 10
        if urgent {
            let generator = UIImpactFeedbackGenerator(style: impactStyle(forSecondsRemaining: secondsRemaining))
            generator.impactOccurred()
        }
        if soundEnabled { TickSound.shared.play(urgent: urgent) }
    }

    func resetTickTracking() {
        lastTickSecond = nil
    }

    /// Escalating: lighter with more time left in the final window, heavier
    /// as it runs out.
    private func impactStyle(forSecondsRemaining seconds: Int) -> UIImpactFeedbackGenerator.FeedbackStyle {
        switch seconds {
        case 8...10: return .light
        case 4...7: return .medium
        default: return .heavy
        }
    }

    private nonisolated static func loadSound(_ name: String) -> SystemSoundID? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else { return nil }
        var id: SystemSoundID = 0
        return AudioServicesCreateSystemSoundID(url as CFURL, &id) == noErr ? id : nil
    }

    private func chimeSoundID(for style: ChimeStyle) -> SystemSoundID {
        switch style {
        case .ascending: return correctSound ?? 1103
        case .lowBuzz: return skipSound ?? 1107
        case .tick: return 1104
        }
    }
}

extension GameEngine {
    /// The Correct/Skip hit zones call these rather than `markCorrect()` /
    /// `markSkip()` directly, so every tap site gets PRD §10.4's feedback
    /// pairing without repeating it at each call site.
    @MainActor
    func markCorrectWithFeedback() {
        markCorrect()
        FeedbackPlayer.shared.play(.correct)
        postFeedback(delta: 1)
    }

    @MainActor
    func markSkipWithFeedback() {
        markSkip()
        FeedbackPlayer.shared.play(.skip)
        // Only post a "-1" overlay when the skip actually costs a point —
        // otherwise skipping would misleadingly look penalized.
        if configuration.skipPenaltyEnabled {
            postFeedback(delta: -1)
        }
    }
}
