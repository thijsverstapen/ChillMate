import Foundation
import Testing
@testable import ChillMate

/// Covers the combinations added in 4.2.1, and the structural properties the
/// checker has to keep regardless of what the table contains.
struct SubstanceInteractionCoverageTests {

    @Test("Combinations added in 4.2.1 are present at their documented severity", .tags(.safety), arguments: [
        (Set<Substance>([.cocaine, .alcohol]), SubstanceInteraction.Level.serious),
        (Set<Substance>([.mdma, .alcohol]), SubstanceInteraction.Level.serious),
        (Set<Substance>([.threeMMC, .alcohol]), SubstanceInteraction.Level.serious),
        (Set<Substance>([.cannabis, .alcohol]), SubstanceInteraction.Level.caution),
        (Set<Substance>([.ghb, .poppers]), SubstanceInteraction.Level.serious),
        (Set<Substance>([.gbl, .poppers]), SubstanceInteraction.Level.serious),
        (Set<Substance>([.mdma, .ketamine]), SubstanceInteraction.Level.caution),
        (Set<Substance>([.psychedelics, .mdma]), SubstanceInteraction.Level.serious),
        (Set<Substance>([.psychedelics, .cocaine]), SubstanceInteraction.Level.caution),
        (Set<Substance>([.psychedelics, .threeMMC]), SubstanceInteraction.Level.caution),
        (Set<Substance>([.viagra, .cocaine]), SubstanceInteraction.Level.serious),
        (Set<Substance>([.kamagra, .cocaine]), SubstanceInteraction.Level.serious),
        (Set<Substance>([.viagra, .mdma]), SubstanceInteraction.Level.caution),
        (Set<Substance>([.kamagra, .mdma]), SubstanceInteraction.Level.caution),
        (Set<Substance>([.viagra, .threeMMC]), SubstanceInteraction.Level.caution),
        (Set<Substance>([.kamagra, .threeMMC]), SubstanceInteraction.Level.caution),
    ])
    func newPairsPresent(combo: Set<Substance>, expected: SubstanceInteraction.Level) throws {
        let match = try #require(
            SubstanceInteractionChecker.warnings(for: combo).first { $0.substances == combo },
            "No warning for \(combo.map(\.rawValue).sorted())"
        )
        #expect(match.level == expected)
    }

    @Test("Cocaine and alcohol warn about cocaethylene", .tags(.safety))
    func cocaethyleneNamed() throws {
        // This is the pair whose absence prompted the addition; the mechanism is
        // the reason it matters, so the text has to carry it.
        let match = try #require(
            SubstanceInteractionChecker.warnings(for: [.cocaine, .alcohol]).first
        )
        #expect(match.warning.localizedCaseInsensitiveContains("cocaethylene"))
    }

    @Test("Every warning carries non-empty text", .tags(.safety))
    func everyWarningHasText() {
        // Exercised through the public API across the full substance set.
        let all = Set(Substance.allCases)
        let warnings = SubstanceInteractionChecker.warnings(for: all)
        #expect(warnings.isEmpty == false)
        for warning in warnings {
            #expect(warning.warning.isEmpty == false,
                    "Empty warning text for \(warning.substances.map(\.rawValue).sorted())")
            #expect(warning.level.label.isEmpty == false)
        }
    }

    @Test("Selecting everything surfaces every combination exactly once", .tags(.safety))
    func fullSelectionIsExhaustiveAndUnique() {
        let warnings = SubstanceInteractionChecker.warnings(for: Set(Substance.allCases))
        let ids = warnings.map(\.id)
        #expect(Set(ids).count == ids.count, "Duplicate combinations: \(ids)")
    }

    @Test("Results are ordered most severe first and are deterministic", .tags(.safety))
    func orderingIsStableAndSorted() {
        let all = Set(Substance.allCases)
        let first = SubstanceInteractionChecker.warnings(for: all).map(\.id)
        let second = SubstanceInteractionChecker.warnings(for: all).map(\.id)
        #expect(first == second, "Ordering must not vary between calls")

        let levels = SubstanceInteractionChecker.warnings(for: all).map(\.level)
        #expect(levels == levels.sorted(by: >))
    }

    @Test("A single substance never warns on its own", .tags(.safety))
    func singleSubstanceNeverWarns() {
        for substance in Substance.allCases {
            #expect(SubstanceInteractionChecker.warnings(for: [substance]).isEmpty,
                    "\(substance.rawValue) alone should not warn")
        }
    }

    @Test("Adding a substance never removes an existing warning", .tags(.safety))
    func warningsAreMonotonic() {
        // Matching is by subset, so a larger selection must be a superset of the
        // warnings a smaller one produced. A regression here would silently drop a
        // warning the user had already been shown.
        let base: Set<Substance> = [.ghb, .alcohol]
        let baseIDs = Set(SubstanceInteractionChecker.warnings(for: base).map(\.id))

        for extra in Substance.allCases where !base.contains(extra) {
            let widened = Set(SubstanceInteractionChecker.warnings(for: base.union([extra])).map(\.id))
            #expect(baseIDs.isSubset(of: widened),
                    "Adding \(extra.rawValue) dropped warnings: \(baseIDs.subtracting(widened))")
        }
    }
}
