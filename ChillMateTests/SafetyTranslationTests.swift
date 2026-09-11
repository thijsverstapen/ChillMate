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

/// Counted strings have to use the catalog's plural rules, not a Swift ternary.
///
/// `%lld days` was a plain string with a `streak == 1 ?` branch in Swift choosing
/// between it and a separate "1 day". That bakes the English rule into all five
/// languages, and the rules are not the same: French takes the singular at zero,
/// so a hand-rolled rule writes "0 jours". English had no catalog entry at all,
/// so it fell through to the key and the widget said "1 days".
@Suite("Counted strings")
struct PluralFormTests {

    /// The singular the catalog should produce at one, per language.
    static func singular(for language: AppLanguage) -> String {
        switch language {
        case .english: "1 day"
        case .dutch: "1 dag"
        case .german: "1 Tag"
        case .french: "1 jour"
        case .spanish: "1 día"
        }
    }

    static func plural(for language: AppLanguage) -> String {
        switch language {
        case .english: "5 days"
        case .dutch: "5 dagen"
        case .german: "5 Tage"
        case .french: "5 jours"
        case .spanish: "5 días"
        }
    }

    @Test("One day is singular in every language", .tags(.safety), arguments: AppLanguage.allCases)
    func oneIsSingular(language: AppLanguage) throws {
        let bundle = try #require(SafetyLine.bundle(for: language))
        let format = bundle.localizedString(forKey: "%lld days", value: nil, table: nil)
        let rendered = unsafe String(format: format, locale: Locale(identifier: language.rawValue), 1)
        #expect(rendered == Self.singular(for: language),
                "\(language.rawValue) renders one day as \"\(rendered)\"")
    }

    @Test("Five days is plural in every language", .tags(.safety), arguments: AppLanguage.allCases)
    func manyIsPlural(language: AppLanguage) throws {
        let bundle = try #require(SafetyLine.bundle(for: language))
        let format = bundle.localizedString(forKey: "%lld days", value: nil, table: nil)
        let rendered = unsafe String(format: format, locale: Locale(identifier: language.rawValue), 5)
        #expect(rendered == Self.plural(for: language),
                "\(language.rawValue) renders five days as \"\(rendered)\"")
    }

    /// French is the reason the Swift ternary had to go: it treats zero as
    /// singular, and an `== 1` check does not.
    @Test("French takes the singular at zero", .tags(.safety))
    func frenchZeroIsSingular() throws {
        let bundle = try #require(SafetyLine.bundle(for: .french))
        let format = bundle.localizedString(forKey: "%lld days", value: nil, table: nil)
        let rendered = unsafe String(format: format, locale: Locale(identifier: "fr"), 0)
        #expect(rendered == "0 jour", "French renders zero days as \"\(rendered)\"")
    }
}

/// Guards the defect that shipped `mainRisks` and `mixingRisks` in English to
/// every non-English user.
///
/// Those were bare Swift string literals, which reach
/// `Label(_:systemImage:)` as a `String` rather than a `LocalizedStringKey` and
/// are therefore not localized at all. The localization gate could not see them
/// because it reads `String(localized:)` calls and there were none.
///
/// So this checks the thing that actually matters rather than the shape of the
/// call: that the text differs between languages. A line that comes back
/// identical in Dutch, German, French and Spanish is either untranslated or a
/// proper noun, and there are no proper nouns in these two lists.
@Suite("Drug information is translated, not just localizable")
struct DrugInformationTranslationTests {

    private static let substances = Substance.allCases.filter { $0 != .unknown && $0 != .other }

    /// These checks read the English key and then look it up in each shipped
    /// `.lproj`, so they only mean anything in the English pass.
    ///
    /// `mainRisks` resolves through `String(localized:)` against `Bundle.main`.
    /// In the Dutch pass it therefore already returns Dutch, and looking a Dutch
    /// sentence up as a catalog key finds nothing and hands the same sentence
    /// back — which would fail for every language regardless of how well
    /// translated it is. The first version of this file did exactly that.
    ///
    /// CI runs the suite once per language, so the English pass covers all four
    /// translations and the other four passes skip.
    private static var isEnglishPass: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("en") ?? false
    }

    private static let translated = AppLanguage.allCases.filter { $0 != .english }

    @Test("Main risks are translated into every language", .tags(.safety))
    func mainRisksAreTranslated() throws {
        guard Self.isEnglishPass else { return }

        for language in Self.translated {
            let bundle = try #require(SafetyLine.bundle(for: language))
            for substance in Self.substances {
                for risk in substance.mainRisks {
                    let value = bundle.localizedString(forKey: risk, value: "\u{0}absent", table: nil)
                    #expect(value != "\u{0}absent",
                            "\(language.rawValue) has no translation for \(substance.rawValue): \"\(risk)\"")
                    #expect(value != risk,
                            "\(language.rawValue) shows \(substance.rawValue)'s risk in English: \"\(risk)\"")
                }
            }
        }
    }

    @Test("Mixing risks are translated into every language", .tags(.safety))
    func mixingRisksAreTranslated() throws {
        guard Self.isEnglishPass else { return }

        for language in Self.translated {
            let bundle = try #require(SafetyLine.bundle(for: language))
            for substance in Self.substances {
                for risk in substance.mixingRisks {
                    let value = bundle.localizedString(forKey: risk, value: "\u{0}absent", table: nil)
                    #expect(value != "\u{0}absent",
                            "\(language.rawValue) has no translation for \(substance.rawValue)'s mixing risk")
                    #expect(value != risk,
                            "\(language.rawValue) shows \(substance.rawValue)'s mixing risk in English")
                }
            }
        }
    }

    /// The substance's own name, which is the one place a raw value doubles as
    /// display text.
    ///
    /// English is excluded rather than skipped for convenience: a String Catalog
    /// stores no entry whose translation equals its key, so `en.lproj` genuinely
    /// holds a fraction of the keys and a lookup there reports perfectly good
    /// strings as missing.
    @Test("Every substance has a name in every translated language", .tags(.safety))
    func displayNamesResolve() throws {
        guard Self.isEnglishPass else { return }

        for language in Self.translated {
            let bundle = try #require(SafetyLine.bundle(for: language))
            for substance in Self.substances {
                let name = bundle.localizedString(forKey: substance.rawValue, value: "\u{0}absent", table: nil)
                #expect(name != "\u{0}absent",
                        "\(language.rawValue) has no name for \(substance.rawValue)")
            }
        }
    }
}
