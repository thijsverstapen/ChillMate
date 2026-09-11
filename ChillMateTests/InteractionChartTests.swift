import Testing
@testable import ChillMate

/// Holds the risk table to the source it claims to be checked against.
///
/// The risk checker now prints a line under every warning saying how its rating
/// compares with TripSit's drug combination chart. That claim is worth exactly
/// as much as whatever keeps it true, which is this file.
///
/// `InteractionChart` is generated from the chart's own data file by
/// `scripts/build_interaction_chart.py` and is never edited by hand.
@Suite("Interaction table against the source chart")
struct InteractionChartTests {

    private static let everyPair: [SubstanceInteraction] = {
        var seen: [String: SubstanceInteraction] = [:]
        let selectable = Substance.allCases.filter { $0 != .unknown && $0 != .other }
        for (index, first) in selectable.enumerated() {
            for second in selectable[(index + 1)...] {
                for interaction in SubstanceInteractionChecker.warnings(for: [first, second]) {
                    seen[interaction.id] = interaction
                }
            }
        }
        return seen.values.sorted { $0.id < $1.id }
    }()

    /// The one direction that is never acceptable.
    ///
    /// Rating a pair *above* the chart is a judgement ChillMate is entitled to
    /// make — it is used in chemsex settings, where the failure mode around GHB
    /// and sedation is not the one a general chart is weighing. Rating a pair
    /// *below* the chart is not a judgement, it is an under-warning, and it is
    /// the shape of mistake that reaches someone at four in the morning.
    @Test("No pair is rated below the published chart", .tags(.safety))
    func nothingIsRatedBelowTheChart() {
        for interaction in Self.everyPair {
            guard let entry = InteractionChart.entry(for: interaction.substances) else { continue }
            guard let ours = InteractionChart.Grading(rawValue: interaction.level.rawValue) else {
                Issue.record("\(interaction.id) has a level with no chart equivalent")
                continue
            }
            #expect(ours >= entry.grading,
                    "\(interaction.id) is rated \(interaction.level) here and \(entry.grading) on the chart")
        }
    }

    /// Every row says where it stands, and says it accurately.
    @Test("Each row's stated corroboration matches the chart", .tags(.safety))
    func corroborationIsDerivedNotAsserted() {
        for interaction in Self.everyPair {
            let entry = InteractionChart.entry(for: interaction.substances)
            switch interaction.corroboration {
            case .notOnChart:
                #expect(entry == nil, "\(interaction.id) says it is not on the chart, but the chart has it")
            case .matchesChart, .matchesChartApproximately:
                #expect(entry?.grading.rawValue == interaction.level.rawValue,
                        "\(interaction.id) claims to match the chart and does not")
            case .ratedAboveChart:
                #expect(entry != nil, "\(interaction.id) claims to be above the chart, which has no entry for it")
                if let entry { #expect(interaction.level.rawValue > entry.grading.rawValue) }
            }
        }
    }

    /// What the chart does not cover, kept explicit so that gaining coverage for
    /// one of these later is a decision rather than something nobody notices.
    ///
    /// Three reasons a pair is uncovered, and all three are legitimate:
    ///
    /// * Poppers, Viagra and Kamagra are not on the chart at all.
    /// * The chart files GHB and GBL as one substance, so it has no entry for the
    ///   two of them together — but ChillMate lets you select both, and stacking
    ///   them is the thing that row exists to warn about.
    /// * 3-MMC is read against mephedrone, and the chart's mephedrone row is
    ///   itself incomplete: it has MDMA, GHB/GBL and LSD, and nothing for cocaine,
    ///   alcohol, cannabis or ketamine.
    @Test("Every uncovered pair is uncovered for a known reason", .tags(.safety))
    func uncoveredSubstancesAreTheExpectedOnes() {
        let notOnChartAtAll: Set<Substance> = [.poppers, .viagra, .kamagra]
        let knownGaps: Set<String> = [
            "GBL+GHB",
            "3MMC+Alcohol", "3MMC+Benzodiazepines", "3MMC+Cannabis", "3MMC+Cocaine", "3MMC+Ketamine",
        ]

        for interaction in Self.everyPair where interaction.corroboration == .notOnChart {
            let isKnown = !interaction.substances.isDisjoint(with: notOnChartAtAll)
                || knownGaps.contains(interaction.id)
            #expect(isKnown,
                    "\(interaction.id) is not on the chart, and not for a reason this test knows about")
        }
    }

    /// Benzodiazepines arrived in 5.0.0 with the substance itself. The pairs that
    /// motivated it are the depressant ones, and they must actually be rated.
    @Test("Benzodiazepines warn against the depressants", .tags(.safety), arguments: [Substance.alcohol, .ghb, .gbl])
    func benzodiazepinesWarnAgainstDepressants(other: Substance) throws {
        let warnings = SubstanceInteractionChecker.warnings(for: [.benzodiazepines, other])
        let match = try #require(warnings.first { $0.substances == [.benzodiazepines, other] },
                                 "no row for benzodiazepines with \(other.rawValue)")
        #expect(match.level == .critical)
    }
}
