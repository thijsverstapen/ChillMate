import Testing
import ChillMateCore
@testable import ChillMate

/// Finding a substance by the name people actually use for it.
///
/// The picker grew to fourteen chips in 5.0.0 and gained a search field. The
/// search is only worth having if it answers to "ket" and "G" rather than only to
/// "Ketamine" and "GHB", which is what somebody types at two in the morning.
@Suite("Substance aliases")
struct SubstanceAliasTests {

    private static let selectable = Substance.allCases.filter { $0 != .unknown && $0 != .other }

    @Test("Street names find the right substance", arguments: [
        ("ket", Substance.ketamine),
        ("k", Substance.ketamine),
        ("tina", Substance.methamphetamine),
        ("crystal", Substance.methamphetamine),
        ("xtc", Substance.mdma),
        ("mandy", Substance.mdma),
        ("coke", Substance.cocaine),
        ("xanax", Substance.benzodiazepines),
        ("benzo", Substance.benzodiazepines),
        ("weed", Substance.cannabis),
        ("wiet", Substance.cannabis),
        ("shrooms", Substance.psychedelics),
        ("acid", Substance.psychedelics),
        ("rush", Substance.poppers),
        ("sildenafil", Substance.viagra),
        ("mmc", Substance.threeMMC),
    ])
    func aliasFindsSubstance(query: String, expected: Substance) {
        #expect(expected.matches(query), "\(expected.rawValue) does not answer to \"\(query)\"")
    }

    /// Case and accents must not matter: somebody typing fast does neither.
    @Test("Matching ignores case and accents", arguments: ["KET", "Ket", "kÉt"])
    func matchingIsForgiving(query: String) {
        #expect(Substance.ketamine.matches(query))
    }

    @Test("An empty query matches everything, so clearing the field restores the grid")
    func emptyQueryMatchesEverything() {
        for substance in Self.selectable {
            #expect(substance.matches(""))
            #expect(substance.matches("   "))
        }
    }

    @Test("A query that means nothing matches nothing")
    func nonsenseMatchesNothing() {
        #expect(Self.selectable.contains { $0.matches("qzxvwk") } == false)
    }

    /// Every selectable substance has to be findable by its own name, or the
    /// search field hides it.
    @Test("Every substance answers to its own display name", arguments: Substance.allCases)
    func displayNameAlwaysMatches(substance: Substance) {
        #expect(substance.matches(substance.localizedDisplayName))
        #expect(substance.matches(substance.rawValue))
    }

    /// "G" is GHB and GBL both, which is correct: they are sold and spoken of
    /// interchangeably, and the table rates combining them as critical.
    @Test("G finds both GHB and GBL")
    func gFindsBoth() {
        #expect(Substance.ghb.matches("g"))
        #expect(Substance.gbl.matches("g"))
    }

    @Test("No substance is left without aliases", arguments: Substance.allCases)
    func everySubstanceHasAliases(substance: Substance) {
        #expect(substance.aliases.isEmpty == false, "\(substance.rawValue) has no aliases")
        #expect(substance.aliases.allSatisfy { $0 == $0.lowercased() },
                "\(substance.rawValue) has an alias that is not lower-cased")
    }
}
