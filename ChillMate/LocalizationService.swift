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
/// nothing else. No code read that key to change the UI language: there was no
/// `AppleLanguages` write, no `Locale` override, no `.environment(\.locale)`
/// anywhere in the project. So the only thing it affected was the language passed
/// to on-device affirmation generation. Choosing "Deutsch" left the entire
/// interface in English.
///
/// `AppleLanguages` is the key iOS reads when it resolves which `.lproj` a bundle
/// serves, and it is the same key the system's per-app Language screen writes.
/// Setting it makes the choice real. Bundle resolution is fixed at process start,
/// so a language change takes effect on the next launch; `pendingRestart` lets the
/// UI say so plainly rather than leaving the user to wonder.
///
/// Sharing that key with iOS means the in-app picker and Settings > ChillMate >
/// Language are two controls over one value, so this type has to reconcile them
/// rather than assume it is the only writer. See `applyStoredLanguageIfNeeded()`.
enum LocalizationService {
    /// The system key controlling bundle localization resolution.
    private static let appleLanguagesKey = DefaultsKey.appleLanguages

    /// The language ChillMate itself last wrote into `AppleLanguages`.
    ///
    /// Remembering what we asserted is the only way to recognise a value we did
    /// not write, which is what a change made in Settings > ChillMate > Language
    /// looks like from in here. Without it the two controls cannot be told apart
    /// and the app can only ever re-assert its own stale copy.
    private static let assertedLanguageKey = DefaultsKey.languageAssertedByChillMate

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

    /// The language iOS currently has selected for this app, when it is one we
    /// ship.
    ///
    /// Nil on a device set to a sixth language: `AppleLanguages` then names
    /// something we have no `.lproj` for and the bundle picks its own fallback,
    /// so there is no system choice here for us to honour or compare against.
    private static var systemSelectedLanguage: AppLanguage? {
        guard let first = UserDefaults.standard.stringArray(forKey: appleLanguagesKey)?.first else {
            return nil
        }
        return AppLanguage.matching(first)
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
        defaults.set(language.rawValue, forKey: assertedLanguageKey)
    }

    /// Seeds, reconciles and re-asserts the language override. Safe to call on
    /// every launch, and must run before the first localized string is read.
    ///
    /// `launchLanguage` is read first on purpose. It is a lazy static and
    /// everything below can write `AppleLanguages`, so capturing it afterwards
    /// would record the language we are asking for instead of the one this
    /// process actually resolved, and `pendingRestart` could never be true.
    static func applyStoredLanguageIfNeeded() {
        let launched = launchLanguage
        let defaults = UserDefaults.standard

        guard let stored = defaults.string(forKey: DefaultsKey.appLanguage).flatMap(AppLanguage.matching) else {
            // First run. The picker binds the stored key directly, so leaving it
            // empty let a fresh Dutch install run in Dutch while the control read
            // "English", and tapping Nederlands changed nothing: the binding was
            // already at its stored value, so its onChange, which is where the
            // real work happens, could not fire.
            //
            // Only seed when iOS itself selected a language we ship. On a device
            // set to a sixth language the bundle falls back to English on its own;
            // recording that fallback as a choice would pin English into
            // `AppleLanguages` and drag date and number formatting to English with
            // it, which the user never asked for.
            if let system = systemSelectedLanguage, system == launched {
                defaults.set(launched.rawValue, forKey: DefaultsKey.appLanguage)
                defaults.set(launched.rawValue, forKey: assertedLanguageKey)
            }
            return
        }

        // `AppleLanguages` holding a language we did not write means it was
        // changed in Settings > ChillMate > Language since our last run. That is
        // the more recent decision, so it wins and becomes the stored choice.
        // Re-asserting our copy instead left a user who once picked Deutsch here
        // and later picked English in iOS Settings with English for exactly one
        // launch and German ever after, while the app told them to relaunch to
        // finish switching, which only put German back.
        if let system = systemSelectedLanguage,
           let asserted = defaults.string(forKey: assertedLanguageKey).flatMap(AppLanguage.matching),
           system != asserted {
            apply(system)
            return
        }

        apply(stored)
    }

    /// `Locale` to put in `.environment(\.locale)`.
    ///
    /// Dates, numbers and measurements honour this immediately. Only catalog
    /// string lookup is bound to the launch bundle and needs the relaunch.
    ///
    /// When the user has not picked a language in-app this is the system locale
    /// untouched. When they have, only the language is swapped and everything
    /// else is inherited: region, calendar, first weekday and the 24-hour-time
    /// preference. Imposing a bare `Locale(identifier: "en")` would discard all
    /// of those, so a UK phone with 24-Hour Time on would start rendering
    /// "10:00 PM" and US month/day ordering in every DatePicker, including the
    /// STI test dates and dose timestamps.
    static var effectiveLocale: Locale {
        guard let stored = UserDefaults.standard.string(forKey: DefaultsKey.appLanguage),
              let language = AppLanguage.matching(stored) else {
            return .autoupdatingCurrent
        }

        var components = Locale.Components(locale: .autoupdatingCurrent)
        components.languageComponents.languageCode = Locale.LanguageCode(language.rawValue)
        return Locale(components: components)
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
/// `EmergencyContactInfo.number(forCountry:)`. It stays English and stays stable
/// because it is storage, not display. Display names come from `Locale`, which
/// gives a correctly translated country name in all five languages for free; the
/// picker previously hard-coded English names like "Netherlands" and "Germany".
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
