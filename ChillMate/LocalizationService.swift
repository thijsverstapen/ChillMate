import Foundation
import SwiftUI

/// The languages ChillMate ships a String Catalog translation for.
///
/// `rawValue` is the ISO code written into `AppleLanguages`, which is the key iOS
/// itself uses to pick a bundle's `.lproj`. Display names come from `Locale`, so
/// each language names itself the way its own speakers write it and no hand-kept
/// list of endonyms can drift.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case dutch = "nl"
    case german = "de"
    case french = "fr"
    case spanish = "es"

    var id: String { rawValue }

    /// The language's name in its own language ("Nederlands", "Deutsch").
    var endonym: String {
        let locale = Locale(identifier: rawValue)
        let name = locale.localizedString(forLanguageCode: rawValue) ?? rawValue
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    /// The language's name in the language currently on screen, for a subtitle.
    var localizedName: String {
        Locale.current.localizedString(forLanguageCode: rawValue) ?? rawValue
    }

    static func matching(_ code: String) -> AppLanguage? {
        // Tolerates region-qualified codes such as "en-GB" or "nl-BE".
        let base = code.split(separator: "-").first.map(String.init) ?? code
        return AppLanguage(rawValue: base.lowercased())
    }
}

/// Applies and reports the app's language override.
///
/// The in-app Language picker used to write `@AppStorage(DefaultsKey.appLanguage)` and
/// nothing else. No code read that key to change the UI language — there was no
/// `AppleLanguages` write, no `Locale` override, no `.environment(\.locale)`
/// anywhere in the project — so the only thing it affected was the language passed
/// to on-device affirmation generation. Choosing "Deutsch" left the entire
/// interface in English.
///
/// `AppleLanguages` is the key iOS reads when it resolves which `.lproj` a bundle
/// serves, and it is the same key the system's per-app Language screen writes.
/// Setting it makes the choice real. Bundle resolution is fixed at process start,
/// so a language change takes effect on the next launch; `pendingRestart` lets the
/// UI say so plainly rather than leaving the user to wonder.
enum LocalizationService {
    /// The system key controlling bundle localization resolution.
    private static let appleLanguagesKey = "AppleLanguages"

    /// The language the running process actually resolved its bundle against.
    /// Captured once at launch, before any override is written, so comparing
    /// against it tells us whether a restart is outstanding.
    private static let launchLanguage: AppLanguage = {
        let preferred = Bundle.main.preferredLocalizations.first
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
        return AppLanguage.matching(preferred) ?? .english
    }()

    /// The user's stored choice, defaulting to whatever the system resolved.
    static var selected: AppLanguage {
        let stored = UserDefaults.standard.string(forKey: DefaultsKey.appLanguage)
        return stored.flatMap(AppLanguage.matching) ?? launchLanguage
    }

    /// True when the stored choice differs from the language this process launched
    /// in, i.e. the user needs to relaunch for it to take effect.
    static var pendingRestart: Bool {
        selected != launchLanguage
    }

    /// Records the choice and pushes it into `AppleLanguages`.
    ///
    /// Call this from the picker and once at launch, so a choice made on a previous
    /// run survives anything that resets the system key.
    static func apply(_ language: AppLanguage) {
        let defaults = UserDefaults.standard
        defaults.set(language.rawValue, forKey: DefaultsKey.appLanguage)

        // Put the chosen language first and keep the rest as fallbacks, so any
        // string missing a translation still resolves rather than showing its key.
        var ordered = [language.rawValue]
        ordered.append(contentsOf: AppLanguage.allCases.map(\.rawValue).filter { $0 != language.rawValue })
        defaults.set(ordered, forKey: appleLanguagesKey)
    }

    /// Re-asserts the stored choice. Safe to call on every launch.
    static func applyStoredLanguageIfNeeded() {
        guard let stored = UserDefaults.standard.string(forKey: DefaultsKey.appLanguage),
              let language = AppLanguage.matching(stored) else { return }
        apply(language)
    }

    /// `Locale` for the selected language, for `.environment(\.locale)`.
    ///
    /// Dates, numbers and measurements honour this immediately — only catalog
    /// string lookup is bound to the launch bundle and needs the relaunch.
    static var selectedLocale: Locale {
        Locale(identifier: selected.rawValue)
    }

    /// Deep link to this app's page in Settings, where iOS offers the same
    /// per-app language control.
    static var systemSettingsURL: URL? {
        URL(string: UIApplication.openSettingsURLString)
    }
}

/// The countries ChillMate has a curated support directory and emergency number for.
///
/// `rawValue` is the exact string persisted in UserDefaults under
/// `DefaultsKey.country` and matched by `SupportResource.resources(for:)` and
/// `EmergencyContactInfo.number(forCountry:)`. It stays English and stays stable —
/// it is storage, not display. Display names come from `Locale`, which gives a
/// correctly translated country name in all five languages for free; the picker
/// previously hard-coded English names like "Netherlands" and "Germany".
enum SupportedCountry: String, CaseIterable, Identifiable {
    case netherlands = "Netherlands"
    case belgium = "Belgium"
    case germany = "Germany"
    case unitedKingdom = "United Kingdom"
    case ireland = "Ireland"
    case france = "France"
    case spain = "Spain"
    case unitedStates = "United States"
    case australia = "Australia"
    case other = "Other"

    var id: String { rawValue }

    /// ISO 3166-1 alpha-2 code, or nil for the catch-all "Other".
    var regionCode: String? {
        switch self {
        case .netherlands: "NL"
        case .belgium: "BE"
        case .germany: "DE"
        case .unitedKingdom: "GB"
        case .ireland: "IE"
        case .france: "FR"
        case .spain: "ES"
        case .unitedStates: "US"
        case .australia: "AU"
        case .other: nil
        }
    }

    /// Country name in the language currently on screen.
    var displayName: String {
        guard let regionCode,
              let localized = Locale.current.localizedString(forRegionCode: regionCode) else {
            return String(localized: "Other")
        }
        return localized
    }
}
