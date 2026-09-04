import Foundation
@testable import ChillMate

/// Every safety line the risk checker can put on screen, named by its String
/// Catalog key.
///
/// In a String Catalog the key *is* the English source string, so each raw value
/// below is at once the lookup key and the English wording. Naming them here is
/// what lets a test assert "this branch fired" without also asserting "this
/// branch fired in English".
///
/// That distinction is not academic. Twenty-one assertions in
/// `SubstanceInteractionCoverageTests` used to read
/// `text.contains("GHB/GBL with alcohol…")`, and every one of them failed on a
/// simulator set to Dutch while the risk engine was behaving perfectly. Four
/// more asserted a fragment was *absent*, and those passed for the worst
/// possible reason: an English fragment is never present in Dutch output, so
/// they could not have caught the duplicated line they exist to catch. The
/// suite only ever proved anything at all in English, and CI hid that because
/// GitHub's runners are en_US.
///
/// Anything that reaches the user with a severity badge belongs in this list.
enum SafetyLine: String, CaseIterable, Sendable {

    // MARK: Medication branches, which the curated table cannot see

    case nitratesWithErectileMedication = "Nitrates, nicorandil, or riociguat with Viagra, Kamagra, or poppers can cause a severe blood pressure drop. Do not combine."
    case alphaBlockersWithErectileMedication = "Alpha blockers with Viagra or Kamagra can increase dizziness or fainting risk. Check with a clinician before combining."
    case sedativesWithDepressants = "Sedatives or opioids with alcohol, ketamine, cannabis, or GHB/GBL can make breathing, memory, and consent clarity worse."
    case prescribedStimulants = "Prescribed stimulant medication with MDMA, 3MMC, or cocaine can increase stimulant overload risk."
    case maoiWithSerotonergics = "Certain antidepressants (MAOIs) with MDMA, 3-MMC, cocaine, or psychedelics can be dangerous. Avoid this and get professional advice."
    case antidepressantsWithSerotonergics = "Some antidepressants or mood medication can interact with MDMA, 3-MMC, cocaine, or psychedelics."
    case ritonavirBooster = "Ritonavir or cobicistat can raise levels of some substances and erectile dysfunction medication. Ask a clinician or pharmacist."

    // MARK: Substance branches

    case ghbWithDepressants = "GHB/GBL with alcohol, ketamine, sedatives, or opioids can cause unconsciousness or breathing problems."
    case ghbAlone = "GHB/GBL effects can be hard to predict and can become serious quickly."
    case poppersWithErectileMedication = "Poppers with Viagra or Kamagra can drop blood pressure sharply. Avoid this combination."
    case poppersAlone = "Poppers can drop blood pressure sharply, especially with Viagra, Kamagra, or similar medication."
    case multipleStimulants = "Multiple stimulants can stack heart strain, anxiety, and overheating."
    case alcoholWithCocaine = "Alcohol and cocaine together can increase strain on the heart and reduce judgment."

    // MARK: The line shown when neither source matched

    case nothingMatched = "No known major preset warning matched. Unknown amount, contents, health conditions, and medication changes can still matter."
}

extension SafetyLine {

    /// The line as the running app renders it, in whichever language this test
    /// run resolved.
    ///
    /// `Bundle.main` is the host app (`ChillMateTests` sets `TEST_HOST`), and
    /// bundle localization is fixed at process start from `AppleLanguages`, so
    /// this resolves through exactly the path `String(localized:)` takes in
    /// `CombinationAssessment`. Falling back to `rawValue` matches the source
    /// language, where the catalog legitimately stores no entry because the key
    /// and the value would be identical.
    var localized: String {
        Bundle.main.localizedString(forKey: rawValue, value: rawValue, table: nil)
    }

    /// The line's translation in one specific language, or nil when the catalog
    /// carries none.
    ///
    /// English is the raw value by definition and needs no lookup: a String
    /// Catalog omits every entry whose translation equals its key, so
    /// `en.lproj` genuinely holds only a fraction of the keys and a lookup there
    /// would report perfectly good strings as missing.
    func translation(in language: AppLanguage) -> String? {
        guard language != .english else { return rawValue }
        guard let bundle = Self.bundle(for: language) else { return nil }

        // A sentinel no catalog value can collide with, so "absent" is
        // distinguishable from "translated to something short".
        let sentinel = "\u{0}absent"
        let value = bundle.localizedString(forKey: rawValue, value: sentinel, table: nil)
        return value == sentinel ? nil : value
    }

    /// The `.lproj` bundle shipped inside the host app for `language`.
    static func bundle(for language: AppLanguage) -> Bundle? {
        Bundle.main
            .path(forResource: language.rawValue, ofType: "lproj")
            .flatMap(Bundle.init(path:))
    }
}
