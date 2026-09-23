import Content
import Core
import Foundation

/// One language setting drives both the word bank and the whole UI
/// (design refresh, 2026-09-23). The player's choice overrides the system
/// language, so SwiftUI `Text("literal")` sites follow `\.locale` in the
/// environment while plain-`String` sites go through `tr(_:)`, which reads
/// from the matching `.lproj` bundle directly.
///
/// Catalog language codes: `en`, `zh-HK` (Cantonese), `zh-Hant` (Taiwan),
/// `zh-Hans` (Mainland). "CharaDUO" stays Latin in every language.
enum L10n {
    // Written only on the main actor (AppSettings), read from view bodies.
    nonisolated(unsafe) private(set) static var bundle: Bundle = .main
    nonisolated(unsafe) private(set) static var locale: Locale = Locale(identifier: "en")

    static func apply(_ language: ContentLanguage) {
        locale = language.locale
        if let path = Bundle.main.path(forResource: language.catalogCode, ofType: "lproj"),
           let localized = Bundle(path: path) {
            bundle = localized
        } else {
            bundle = .main
        }
        Team.defaultName = { number in tr("Team \(number)") }
        // Takes effect next launch — this is what makes the system-owned
        // permission prompts (Info.plist strings) follow the setting too.
        UserDefaults.standard.set([language.catalogCode], forKey: "AppleLanguages")
    }

    /// Maps the device's preferred language to a starting `ContentLanguage`
    /// on first launch: zh-HK/yue → Cantonese, zh-TW → Taiwan, zh-CN →
    /// Mainland, anything else → English.
    static func initialLanguage(preferred: [String] = Locale.preferredLanguages) -> ContentLanguage {
        guard let first = preferred.first?.lowercased() else { return .english }
        if first.hasPrefix("yue") || first.hasPrefix("zh-hk") || first.hasPrefix("zh-hant-hk") || first.hasPrefix("zh-mo") || first.hasPrefix("zh-hant-mo") {
            return .cantonese
        }
        if first.hasPrefix("zh-tw") || first.hasPrefix("zh-hant") { return .taiwanChinese }
        if first.hasPrefix("zh") { return .mainlandChinese }
        return .english
    }
}

extension ContentLanguage {
    var catalogCode: String {
        switch self {
        case .english: return "en"
        case .cantonese: return "zh-HK"
        case .taiwanChinese: return "zh-Hant"
        case .mainlandChinese: return "zh-Hans"
        }
    }

    var locale: Locale {
        switch self {
        case .english: return Locale(identifier: "en")
        case .cantonese: return Locale(identifier: "zh-HK")
        case .taiwanChinese: return Locale(identifier: "zh-Hant-TW")
        case .mainlandChinese: return Locale(identifier: "zh-Hans-CN")
        }
    }
}

/// Localized `String` in the player's chosen language, for every place a
/// plain `String` (rather than a SwiftUI `Text` literal) is needed.
func tr(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: L10n.bundle, locale: L10n.locale)
}
