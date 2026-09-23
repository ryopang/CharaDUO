import Content
import Foundation
import Observation

/// Durable user preferences. Still UserDefaults-sized — match history,
/// stats and custom decks are the SwiftData territory PRD §6.4 describes.
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let language = "lastUsedContentLanguage"
        static let reactionCamera = "reactionCameraEnabled"
        static let reactionAudio = "reactionAudioEnabled"
        static let consentShown = "captureConsentShown"
        static let tickSound = "tickSoundEnabled"
    }

    private let defaults: UserDefaults

    /// PRD §2.4 — Quick Play uses the last-used language.
    /// Design refresh — this one setting is both the word language and the
    /// UI language.
    var lastUsedLanguage: ContentLanguage {
        didSet {
            defaults.set(lastUsedLanguage.rawValue, forKey: Key.language)
            L10n.apply(lastUsedLanguage)
        }
    }

    /// PRD §7.3 — the Reaction Camera master toggle. Turning it off means
    /// giving up the outer display too, which the settings copy says plainly.
    var reactionCameraEnabled: Bool {
        didSet { defaults.set(reactionCameraEnabled, forKey: Key.reactionCamera) }
    }

    /// PRD §7.3 — the audio-off sub-toggle, for groups who want the reel
    /// without voices. Drops the microphone and leaves the outer display
    /// working, since the accessory needs a video session.
    var reactionAudioEnabled: Bool {
        didSet { defaults.set(reactionAudioEnabled, forKey: Key.reactionAudio) }
    }

    /// PRD §7.3 — the one-time consent card is shown before the first match,
    /// never mid-round.
    var hasShownCaptureConsent: Bool {
        didSet { defaults.set(hasShownCaptureConsent, forKey: Key.consentShown) }
    }

    /// The per-second clock tick. Respects the silent switch regardless.
    var tickSoundEnabled: Bool {
        didSet { defaults.set(tickSoundEnabled, forKey: Key.tickSound) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let raw = defaults.string(forKey: Key.language), let language = ContentLanguage(rawValue: raw) {
            self.lastUsedLanguage = language
        } else {
            self.lastUsedLanguage = L10n.initialLanguage()
        }

        // Both capture toggles default on; consent is what actually gates
        // the camera, and it hasn't been given yet.
        self.reactionCameraEnabled = defaults.object(forKey: Key.reactionCamera) as? Bool ?? true
        self.reactionAudioEnabled = defaults.object(forKey: Key.reactionAudio) as? Bool ?? true
        self.hasShownCaptureConsent = defaults.bool(forKey: Key.consentShown)
        self.tickSoundEnabled = defaults.object(forKey: Key.tickSound) as? Bool ?? true

        L10n.apply(lastUsedLanguage)

        #if DEBUG
        // UserDefaults outlives a launch in the simulator, so tests pin this
        // explicitly rather than inheriting whatever ran before them.
        if DebugOverrides.skipConsent {
            self.hasShownCaptureConsent = true
            self.reactionCameraEnabled = false
        } else if DebugOverrides.forceConsent {
            self.hasShownCaptureConsent = false
            self.reactionCameraEnabled = true
        }
        if let raw = DebugOverrides.contentLanguageRawValue, let language = ContentLanguage(rawValue: raw) {
            self.lastUsedLanguage = language
        }
        #endif
    }
}
