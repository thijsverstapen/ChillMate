import Foundation
import Testing
@testable import ChillMate

/// The medication matcher feeds the risk checker's clinical warnings, and it was
/// entirely untested. Both directions matter: a missed match withholds a warning,
/// and a spurious match trains the user to ignore warnings.
struct MedicationRiskDatabaseTests {

    @Test("Known medications match their category", .tags(.safety), arguments: [
        ("sertraline 50mg", MedicationRiskCategory.serotonergic),
        ("Escitalopram", MedicationRiskCategory.serotonergic),
        ("phenelzine", MedicationRiskCategory.maoi),
        ("diazepam 5mg at night", MedicationRiskCategory.sedative),
        ("oxycodone", MedicationRiskCategory.opioid),
        ("isosorbide mononitrate", MedicationRiskCategory.nitrateLike),
        ("tamsulosin", MedicationRiskCategory.alphaBlocker),
        ("methylphenidate 20mg", MedicationRiskCategory.stimulantMedication),
        ("ritonavir", MedicationRiskCategory.ritonavirBooster),
    ])
    func knownMedicationsMatch(text: String, expected: MedicationRiskCategory) {
        let categories = MedicationRiskDatabase.matches(in: text).map(\.category)
        #expect(categories.contains(expected),
                "\(text.debugDescription) should match \(expected); got \(categories)")
    }

    @Test("Matching ignores case and diacritics", .tags(.safety))
    func matchingIsInsensitive() {
        for spelling in ["SERTRALINE", "Sertraline", "sertralinē"] {
            let categories = MedicationRiskDatabase.matches(in: spelling).map(\.category)
            #expect(categories.contains(.serotonergic), "\(spelling) should match")
        }
    }

    @Test("Aliases match on whole words, not substrings", .tags(.safety))
    func matchingIsWholeWord() {
        // A substring match would fire on any word merely containing an alias, and
        // an over-eager clinical warning teaches people to dismiss them.
        #expect(MedicationRiskDatabase.matches(in: "benzoyl peroxide").isEmpty,
                "'benzoyl peroxide' must not match the 'benzo' alias")
        #expect(MedicationRiskDatabase.matches(in: "codeine-free painkiller").isEmpty == false,
                "'codeine' as a hyphen-separated word should still match")
    }

    @Test("Everyday non-interacting medications produce no warning", .tags(.safety))
    func benignMedicationsDoNotMatch() {
        for benign in ["paracetamol", "ibuprofen 400mg", "vitamin D", "cetirizine", "omeprazole"] {
            #expect(MedicationRiskDatabase.matches(in: benign).isEmpty,
                    "\(benign) should not produce a risk match")
        }
    }

    @Test("Empty and whitespace input matches nothing")
    func emptyInputMatchesNothing() {
        for empty in ["", "   ", "\n\t"] {
            #expect(MedicationRiskDatabase.matches(in: empty).isEmpty)
        }
    }

    @Test("Tramadol reports both of the categories it belongs to", .tags(.safety))
    func tramadolIsBothOpioidAndSerotonergic() {
        // Tramadol is deliberately listed under both serotonergic and opioid; it
        // genuinely is both, and dropping either warning would understate the risk.
        let categories = Set(MedicationRiskDatabase.matches(in: "tramadol").map(\.category))
        #expect(categories.contains(.serotonergic))
        #expect(categories.contains(.opioid))
    }

    @Test("A category is reported at most once regardless of how many aliases hit", .tags(.safety))
    func categoriesAreNotDuplicated() {
        let text = "sertraline and fluoxetine and citalopram"
        let serotonergic = MedicationRiskDatabase.matches(in: text).filter { $0.category == .serotonergic }
        #expect(serotonergic.count == 1, "Expected one serotonergic match, got \(serotonergic.count)")
    }

    @Test("A multi-drug list reports every distinct category", .tags(.safety))
    func multipleMedicationsAllReported() {
        let categories = Set(MedicationRiskDatabase.matches(in: "sertraline, diazepam, tamsulosin").map(\.category))
        #expect(categories.contains(.serotonergic))
        #expect(categories.contains(.sedative))
        #expect(categories.contains(.alphaBlocker))
    }

    @Test("Every category has aliases and a label")
    func everyCategoryIsPopulated() {
        for category in MedicationRiskCategory.allCases {
            #expect(category.aliases.isEmpty == false, "\(category) has no aliases")
            #expect(category.label.isEmpty == false, "\(category) has no label")
        }
    }
}
