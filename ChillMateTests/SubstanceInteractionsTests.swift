import Testing
@testable import ChillMate

extension Tag {
    /// Marks tests that verify harm-reduction / safety-critical behavior.
    @Tag static var safety: Self
}

// A struct with @Test methods is already a suite, so no @Suite is needed.
struct SubstanceInteractionCheckerTests {

    @Test("A combination only warns when every substance in it is present", .tags(.safety))
    func requiresFullCombination() {
        // GHB + alcohol is a known critical pair; GHB on its own must not warn.
        #expect(SubstanceInteractionChecker.warnings(for: [.ghb]).isEmpty)
        #expect(SubstanceInteractionChecker.warnings(for: []).isEmpty)
        #expect(SubstanceInteractionChecker.warnings(for: [.ghb, .alcohol]).isEmpty == false)
    }

    // One collection of tuples → no surprise Cartesian product.
    @Test("Known pairs surface at the documented severity", .tags(.safety), arguments: [
        (Set<Substance>([.ghb, .alcohol]), SubstanceInteraction.Level.critical),
        (Set<Substance>([.gbl, .alcohol]), SubstanceInteraction.Level.critical),
        (Set<Substance>([.poppers, .viagra]), SubstanceInteraction.Level.critical),
        (Set<Substance>([.poppers, .kamagra]), SubstanceInteraction.Level.critical),
        (Set<Substance>([.cocaine, .mdma]), SubstanceInteraction.Level.serious),
        // Raised in 5.0.0 to match TripSit's chart, which rates all three of the
        // ketamine-plus-depressant pairs as dangerous for the same stated reason:
        // ataxia and vomiting together, with aspiration as the thing that kills.
        (Set<Substance>([.alcohol, .ketamine]), SubstanceInteraction.Level.critical),
        (Set<Substance>([.ghb, .ketamine]), SubstanceInteraction.Level.critical),
        (Set<Substance>([.gbl, .ketamine]), SubstanceInteraction.Level.critical),
        // Also raised: the chart rates MDMA with mephedrone dangerous on serotonin
        // syndrome, and 3-MMC is read against mephedrone.
        (Set<Substance>([.mdma, .threeMMC]), SubstanceInteraction.Level.critical),
        // New in 5.0.0 with the substance.
        (Set<Substance>([.benzodiazepines, .alcohol]), SubstanceInteraction.Level.critical),
        (Set<Substance>([.benzodiazepines, .ghb]), SubstanceInteraction.Level.critical),
        (Set<Substance>([.ghb, .cocaine]), SubstanceInteraction.Level.caution),
    ])
    func pairProducesExpectedLevel(combo: Set<Substance>, expected: SubstanceInteraction.Level) throws {
        let result = SubstanceInteractionChecker.warnings(for: combo)
        let match = try #require(result.first { $0.substances == combo },
                                 "Expected a warning whose substances are exactly \(combo)")
        #expect(match.level == expected)
    }

    @Test("Warnings are ordered most-severe first", .tags(.safety))
    func warningsSortedBySeverity() {
        // This set triggers both a critical (GHB+alcohol) and a caution (GHB+cocaine).
        let levels = SubstanceInteractionChecker.warnings(for: [.ghb, .alcohol, .cocaine]).map(\.level)
        #expect(levels.count >= 2)
        #expect(levels == levels.sorted(by: >))
    }

    @Test("Severity ordering is critical > serious > caution", .tags(.safety))
    func levelComparable() {
        #expect(SubstanceInteraction.Level.caution < SubstanceInteraction.Level.serious)
        #expect(SubstanceInteraction.Level.serious < SubstanceInteraction.Level.critical)
    }
}
