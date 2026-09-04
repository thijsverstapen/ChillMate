import Foundation
import Testing
@testable import ChillMate

/// What the risk checker actually says, in each of the five languages ChillMate
/// ships.
///
/// The rest of the suite deliberately asserts nothing about wording: it names a
/// line by its catalog key and compares against whatever that key resolves to,
/// so every test passes in any language and proves branch *selection* rather
/// than prose. That is the right trade there, but it leaves the prose itself
/// unguarded, and the prose is the product: a warning that reaches a Dutch user
/// in English, or that loses "GHB" somewhere in translation, has failed at the
/// only job it has.
///
/// So these read the shipped `.lproj` bundles directly rather than going through
/// the app's own lookup. That covers all five languages from a single run,
/// instead of whichever one the simulator happens to be set to.
@Suite("Safety text in all five languages")
struct SafetyTranslationTests {

    /// Terms that must survive translation because they are names, not words.
    ///
    /// A user picks "GHB" and "Viagra" from a grid; if the warning about that
    /// pairing calls them something else, they cannot tell it is about them.
    /// Deliberately excludes acronyms that genuinely localize: "MAOI" correctly
    /// becomes "MAO-remmers", "MAO-Hemmer" and "IMAO", so the invariant is the
    /// "MAO" stem rather than the English abbreviation.
    static let protectedTerms = [
        "GHB", "GBL", "Viagra", "Kamagra", "MDMA", "3-MMC", "3MMC",
        "MAO", "Ritonavir", "cobicistat", "riociguat", "nicorandil",
    ]

    /// The curated table's entry for cocaine with alcohol, and the term each
    /// language uses for the mechanism it names.
    ///
    /// This is the pair whose absence prompted the 4.2.1 table work, and the
    /// mechanism is the reason it matters, so every translation has to carry it.
    /// The spelling is genuinely different in each language, which is exactly why
    /// the old `contains("cocaethylene")` check could only ever hold in English.
    static let cocaethyleneKey = "Cocaine and alcohol together form cocaethylene in the liver. It puts more strain on the heart than cocaine alone and stays in the body longer, raising the risk of chest pain and irregular heartbeat. Alcohol also masks how much cocaine you have taken."

    static func cocaethyleneTerm(for language: AppLanguage) -> String {
        switch language {
        case .english: "cocaethylene"
        case .dutch: "cocaethyleen"
        case .german: "Cocaethylen"
        case .french: "cocaéthylène"
        case .spanish: "cocaetileno"
        }
    }

    // MARK: Every language is actually shipped

    @Test("Every supported language ships a bundle in the app", .tags(.safety), arguments: AppLanguage.allCases)
    func languageBundleIsShipped(language: AppLanguage) throws {
        let bundle = try #require(SafetyLine.bundle(for: language),
                                  "\(language.rawValue).lproj is missing from the built app")
        // The source language legitimately carries only the keys whose value
        // differs from the key, so only its presence is asserted here.
        #expect(bundle.bundlePath.hasSuffix("\(language.rawValue).lproj"))
    }

    // MARK: Every safety line reaches every language

    @Test("Every safety line is translated in every language", .tags(.safety), arguments: AppLanguage.allCases)
    func everySafetyLineIsTranslated(language: AppLanguage) throws {
        for line in SafetyLine.allCases {
            let translation = try #require(
                line.translation(in: language),
                "\(language.rawValue) has no translation for \(line): a user on this language is shown English"
            )
            #expect(translation.isEmpty == false, "\(language.rawValue) translates \(line) to nothing")

            if language != .english {
                #expect(translation != line.rawValue,
                        "\(language.rawValue) leaves \(line) in English")
            }
        }
    }

    // MARK: Names survive translation

    @Test("Substance and medication names survive translation", .tags(.safety), arguments: AppLanguage.allCases)
    func protectedTermsSurvive(language: AppLanguage) throws {
        for line in SafetyLine.allCases {
            let translation = try #require(line.translation(in: language))

            for term in Self.protectedTerms where line.rawValue.localizedCaseInsensitiveContains(term) {
                #expect(translation.localizedCaseInsensitiveContains(term),
                        "\(language.rawValue) drops \"\(term)\" from \(line), so the warning no longer names what the user selected")
            }
        }
    }

    // MARK: The mechanism that prompted the table

    @Test("Cocaine with alcohol names cocaethylene in every language", .tags(.safety), arguments: AppLanguage.allCases)
    func cocaethyleneIsNamed(language: AppLanguage) throws {
        let text: String
        if language == .english {
            text = Self.cocaethyleneKey
        } else {
            let bundle = try #require(SafetyLine.bundle(for: language))
            let sentinel = "\u{0}absent"
            let value = bundle.localizedString(forKey: Self.cocaethyleneKey, value: sentinel, table: nil)
            #expect(value != sentinel, "\(language.rawValue) has no translation for the cocaethylene warning")
            text = value
        }

        let term = Self.cocaethyleneTerm(for: language)
        #expect(text.localizedCaseInsensitiveContains(term),
                "\(language.rawValue) states the risk without naming the mechanism (\(term)): \(text)")
    }

    // MARK: The table is translated at runtime, not just in the catalog

    /// `check_localization.py` already proves the catalog has every translation,
    /// but it reads the source JSON and never runs the app. This asserts the
    /// other half: that the running app actually *serves* them, rather than
    /// silently falling back to English on a language it ships.
    ///
    /// It can only speak for the language this run resolved, so CI runs the whole
    /// suite once per language. See the "Unit tests" matrix in .github/workflows/ci.yml.
    @Test("The curated table is served in the run's own language", .tags(.safety))
    func curatedTableIsServedInTheRunLanguage() throws {
        let resolved = Bundle.main.preferredLocalizations.first ?? "en"
        let language = try #require(AppLanguage.matching(resolved),
                                    "The app resolved to \(resolved), which it ships no catalog for")

        let warnings = SubstanceInteractionChecker.warnings(for: Set(Substance.allCases))
        #expect(warnings.isEmpty == false)

        guard language != .english else {
            // English strings are their own keys, so there is no fallback to
            // detect: any value the table returns is by definition the English one.
            return
        }

        let translations = Set(try Self.catalog(for: language).values)
        for warning in warnings {
            #expect(translations.contains(warning.warning),
                    "Running in \(language.rawValue), the table served text that is not in the \(language.rawValue) catalog, so it fell back to English: \(warning.warning)")
        }
    }

    /// The compiled `Localizable.strings` for a language, as a dictionary.
    ///
    /// Read off disk rather than through `Bundle.localizedString`, because the
    /// question here is which strings a language has at all, not what one key
    /// resolves to.
    static func catalog(for language: AppLanguage) throws -> [String: String] {
        let bundle = try #require(SafetyLine.bundle(for: language))
        let path = try #require(bundle.path(forResource: "Localizable", ofType: "strings"),
                                "\(language.rawValue).lproj has no compiled Localizable.strings")
        return try #require(NSDictionary(contentsOfFile: path) as? [String: String])
    }
}
