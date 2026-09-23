import Content
import Foundation
import Observation

/// Durable user preferences. Still UserDefaults-sized — match history,
/// stats and custom decks are the SwiftData territory PRD §6.4 describes.
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        /// Set only when the player picks a language in Settings.
        static let appLanguageOverride = "appLanguageOverride"
        /// Pre-2026-09-23 key, written automatically on first launch and at
        /// every match start, so it can't tell a real choice from a default.
        /// Discarded on launch.
        static let legacyLanguage = "lastUsedContentLanguage"
        static let reactionCamera = "reactionCameraEnabled"
        static let reactionAudio = "reactionAudioEnabled"
        static let consentShown = "captureConsentShown"
        static let tickSound = "tickSoundEnabled"
    }

    private let defaults: UserDefaults

    /// The app's UI language. It follows the phone's language until the
    /// player picks one in Settings (`chooseAppLanguage`), and that choice
    /// is kept from then on. Quick Play deals words in this language too;
    /// Custom Game can pick a different word language for one match without
    /// touching this.
    private(set) var appLanguage: ContentLanguage

    /// True once the player has picked a language in Settings.
    private(set) var hasChosenAppLanguage: Bool

    /// The only path that saves a language. Nothing else — first launch,
    /// match start, Custom Game — writes one.
    func chooseAppLanguage(_ language: ContentLanguage) {
        defaults.set(language.rawValue, forKey: Key.appLanguageOverride)
        hasChosenAppLanguage = true
        appLanguage = language
        L10n.apply(language, pinSystemLanguage: true)
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

        defaults.removeObject(forKey: Key.legacyLanguage)
        #if DEBUG
        if DebugOverrides.resetAppLanguage {
            defaults.removeObject(forKey: Key.appLanguageOverride)
        }
        #endif
        if let raw = defaults.string(forKey: Key.appLanguageOverride),
           let language = ContentLanguage(rawValue: raw) {
            self.appLanguage = language
            self.hasChosenAppLanguage = true
        } else {
            // No choice yet: follow the phone. Drop any app-level
            // AppleLanguages pin first (older builds wrote one on first
            // launch), so the lookup below sees the phone's own list.
            defaults.removeObject(forKey: L10n.appleLanguagesKey)
            self.appLanguage = L10n.initialLanguage(
                preferred: defaults.stringArray(forKey: L10n.appleLanguagesKey) ?? Locale.preferredLanguages
            )
            self.hasChosenAppLanguage = false
        }

        // Both capture toggles default on; consent is what actually gates
        // the camera, and it hasn't been given yet.
        self.reactionCameraEnabled = defaults.object(forKey: Key.reactionCamera) as? Bool ?? true
        self.reactionAudioEnabled = defaults.object(forKey: Key.reactionAudio) as? Bool ?? true
        self.hasShownCaptureConsent = defaults.bool(forKey: Key.consentShown)
        self.tickSoundEnabled = defaults.object(forKey: Key.tickSound) as? Bool ?? true

        L10n.apply(appLanguage, pinSystemLanguage: hasChosenAppLanguage)

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
        // For this launch only: never saved, never pins AppleLanguages.
        if let raw = DebugOverrides.contentLanguageRawValue, let language = ContentLanguage(rawValue: raw) {
            self.appLanguage = language
            L10n.apply(language, pinSystemLanguage: false)
        }
        #endif
    }
}
