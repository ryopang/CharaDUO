import Content
import Foundation
import Observation

/// PRD §2.4 — Quick Play uses the last-used language. This is the only piece
/// of durable state M3 needs; match history/stats/custom decks (real
/// SwiftData territory per PRD §6.4) come later.
@MainActor
@Observable
final class AppSettings {
    private static let languageKey = "lastUsedContentLanguage"

    private let defaults: UserDefaults

    var lastUsedLanguage: ContentLanguage {
        didSet { defaults.set(lastUsedLanguage.rawValue, forKey: Self.languageKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.languageKey), let language = ContentLanguage(rawValue: raw) {
            self.lastUsedLanguage = language
        } else {
            self.lastUsedLanguage = .english
        }
    }
}
