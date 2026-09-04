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
        (Set<Substance>([.viagra, .kamagra]), SubstanceInteraction.Level.serious),
    ])
    func newPairsPresent(combo: Set<Substance>, expected: SubstanceInteraction.Level) throws {
        let match = try #require(
            SubstanceInteractionChecker.warnings(for: combo).first { $0.substances == combo },
            "No warning for \(combo.map(\.rawValue).sorted())"
        )
        #expect(match.level == expected)
    }

    // "Cocaine and alcohol name cocaethylene" now lives in SafetyTranslationTests,
    // which makes the same claim about all five languages. Asserting it here meant
    // asserting it about English, and the Dutch text says "cocaethyleen".

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

/// One medication branch of the preset chain, paired with wording it has to keep
/// producing. Spelled as a named type rather than a tuple so the parameterised
/// test takes a single argument.
/// Internal, not private: it is a parameter type of a `@Test` method, and Swift
/// requires the method to be at least as visible as its parameters.
struct MedicationBranchCase: Sendable {
    let medication: String
    let substances: Set<Substance>
    /// The warning the branch is responsible for, named by its catalog key so the
    /// expectation holds in whichever language the run resolved.
    let expectedLine: SafetyLine
}

/// Asserts on what `CombinationRiskCheckerView` actually renders, rather than on
/// the interaction table in isolation.
///
/// The table above was fully covered and entirely dead: nothing on screen read it,
/// so a selection the table rates serious reached the user as "no known major
/// preset warning matched". These tests go through `CombinationAssessment`, the
/// type the screen builds its warning list from, so that failure mode cannot
/// happen again behind a green suite.
struct RiskCheckerScreenTests {

    /// The substances the picker actually offers. `unknown` and `other` are
    /// filtered out of the grid, so they can never form a selection.
    private static let selectable = Substance.allCases.filter { $0 != .unknown && $0 != .other }

    private static var selectablePairs: [Set<Substance>] {
        var pairs: [Set<Substance>] = []
        for (index, first) in selectable.enumerated() {
            for second in selectable.dropFirst(index + 1) {
                pairs.append([first, second])
            }
        }
        return pairs
    }

    private func assessment(_ substances: Set<Substance>, medication: String = "") -> CombinationAssessment {
        CombinationAssessment(
            substances: Array(substances),
            medicationText: medication,
            timing: .sameSession
        )
    }

    // MARK: The gap that started this

    @Test("Alcohol with ketamine no longer reports that nothing matched", .tags(.safety))
    func alcoholWithKetamineReachesTheScreen() throws {
        // Traced by hand before the fix: this pair matched no branch of the preset
        // chain and so hit the fallback, while the table rated it serious.
        let findings = assessment([.alcohol, .ketamine]).interactionFindings

        #expect(findings.contains { $0.level == nil } == false,
                "The nothing matched line is still showing for a rated depressant stack")

        // Identify the line by the table row it has to come from, not by a word
        // that only appears in it in English.
        let curated = try #require(SubstanceInteractionChecker.warnings(for: [.alcohol, .ketamine]).first,
                                   "Alcohol with ketamine is no longer in the table")
        let match = try #require(
            findings.first { $0.text == curated.warning },
            "The depressant risk never reaches the user: \(findings.map(\.text))"
        )
        #expect(match.level == .serious)
    }

    @Test("Pairs the table rates but the preset chain misses now show on screen", .tags(.safety), arguments: [
        Set<Substance>([.alcohol, .ketamine]),
        Set<Substance>([.cannabis, .alcohol]),
        Set<Substance>([.mdma, .ketamine]),
        Set<Substance>([.ghb, .poppers]),
        Set<Substance>([.viagra, .cocaine]),
        Set<Substance>([.kamagra, .cocaine]),
        Set<Substance>([.psychedelics, .cocaine]),
        Set<Substance>([.psychedelics, .threeMMC]),
        Set<Substance>([.viagra, .kamagra]),
    ])
    func previouslySilentPairsNowWarn(combo: Set<Substance>) throws {
        let findings = assessment(combo).interactionFindings
        let curated = try #require(SubstanceInteractionChecker.warnings(for: combo).first,
                                   "\(combo.map(\.rawValue).sorted()) is no longer in the table")

        #expect(findings.contains { $0.text == curated.warning },
                "\(combo.map(\.rawValue).sorted()) does not show its curated warning")
        #expect(findings.contains { $0.level == nil } == false,
                "\(combo.map(\.rawValue).sorted()) still shows the nothing matched line")
    }

    // MARK: The table reaches the screen for every pair, not just the traced ones

    @Test("Every curated warning for a selection reaches the screen", .tags(.safety))
    func everyCuratedWarningIsRendered() {
        for pair in Self.selectablePairs {
            let shown = assessment(pair).interactionWarnings
            for curated in SubstanceInteractionChecker.warnings(for: pair) {
                #expect(shown.contains(curated.warning),
                        "\(pair.map(\.rawValue).sorted()) hides a curated warning from the user")
            }
        }
    }

    @Test("The screen never rates a pair below the table", .tags(.safety))
    func screenSeverityNeverFallsBelowTheTable() {
        // The merge is allowed to replace wording, never to soften it.
        for pair in Self.selectablePairs {
            guard let curatedHighest = SubstanceInteractionChecker.warnings(for: pair).map(\.level).max() else { continue }
            let shownHighest = assessment(pair).interactionFindings.compactMap(\.level).max()
            #expect((shownHighest ?? .caution) >= curatedHighest,
                    "\(pair.map(\.rawValue).sorted()) is shown below its rated severity")
        }
    }

    // MARK: Coverage

    @Test("Every selectable pair has a curated warning", .tags(.safety))
    func everySelectablePairIsCurated() {
        let uncovered = Self.selectablePairs.filter {
            SubstanceInteractionChecker.warnings(for: $0).isEmpty
        }
        #expect(uncovered.isEmpty,
                "Uncurated pairs: \(uncovered.map { $0.map(\.rawValue).sorted().joined(separator: "+") }.sorted())")
    }

    // MARK: The fallback

    // [.cannabis, .psychedelics] used to live here. It was only ever silent
    // because the table had a hole, and it stopped being silent once the hole
    // was filled. Every selectable pair is now curated, so a genuinely silent
    // multi-substance case has to involve Unknown or Other.
    @Test("The fallback appears only when both sources are silent", .tags(.safety), arguments: [
        Set<Substance>([]),
        Set<Substance>([.cannabis]),
        Set<Substance>([.psychedelics]),
        Set<Substance>([.cannabis, .unknown]),
        Set<Substance>([.unknown, .other]),
    ])
    func fallbackAppearsWhenNothingMatched(combo: Set<Substance>) throws {
        #expect(SubstanceInteractionChecker.warnings(for: combo).isEmpty,
                "This case is only meaningful while the table stays silent for it")

        let findings = assessment(combo).interactionFindings
        #expect(findings.count == 1)
        let only = try #require(findings.first)
        #expect(only.level == nil)
        #expect(only.text == SafetyLine.nothingMatched.localized)
    }

    @Test("No selection ever falls back while either source has something", .tags(.safety))
    func fallbackNeverHidesAWarning() {
        for pair in Self.selectablePairs where SubstanceInteractionChecker.warnings(for: pair).isEmpty == false {
            let findings = assessment(pair).interactionFindings
            #expect(findings.contains { $0.level == nil } == false,
                    "\(pair.map(\.rawValue).sorted()) claims nothing matched despite a rated warning")
        }
    }

    // MARK: Deduplication

    // These assert a line is ABSENT. Spelled as an English fragment, that held
    // trivially in every other language, so the four of them passed on a Dutch
    // run without ever exercising the merge they exist to check.
    @Test("The same hazard is never stated twice", .tags(.safety), arguments: [
        // Preset line, and the selection where the table supersedes it.
        (SafetyLine.alcoholWithCocaine, Set<Substance>([.cocaine, .alcohol])),
        (SafetyLine.poppersWithErectileMedication, Set<Substance>([.poppers, .viagra])),
        (SafetyLine.multipleStimulants, Set<Substance>([.cocaine, .mdma])),
        (SafetyLine.ghbWithDepressants, Set<Substance>([.ghb, .alcohol])),
    ])
    func supersededPresetLinesDisappear(line: SafetyLine, combo: Set<Substance>) {
        let findings = assessment(combo).interactionFindings

        #expect(findings.contains { $0.text == line.localized } == false,
                "\(combo.map(\.rawValue).sorted()) still shows the generic preset line as well as the rated one")
        #expect(findings.isEmpty == false)
        #expect(findings.contains { $0.level == nil } == false)
    }

    @Test("Superseding a preset line never lowers what the user sees", .tags(.safety), arguments: [
        (Set<Substance>([.cocaine, .alcohol]), SubstanceInteraction.Level.serious),
        (Set<Substance>([.poppers, .viagra]), SubstanceInteraction.Level.critical),
        (Set<Substance>([.poppers, .kamagra]), SubstanceInteraction.Level.critical),
        (Set<Substance>([.cocaine, .mdma]), SubstanceInteraction.Level.serious),
        (Set<Substance>([.ghb, .alcohol]), SubstanceInteraction.Level.critical),
        (Set<Substance>([.gbl, .alcohol]), SubstanceInteraction.Level.critical),
    ])
    func supersededLinesKeepTheirSeverity(combo: Set<Substance>, atLeast: SubstanceInteraction.Level) throws {
        let highest = try #require(assessment(combo).interactionFindings.compactMap(\.level).max())
        #expect(highest >= atLeast,
                "\(combo.map(\.rawValue).sorted()) dropped from \(atLeast) to \(highest) through the merge")
    }

    @Test("No warning text is repeated in one assessment", .tags(.safety))
    func noRepeatedWarnings() {
        for pair in Self.selectablePairs {
            let texts = assessment(pair).interactionWarnings
            #expect(Set(texts).count == texts.count,
                    "\(pair.map(\.rawValue).sorted()) repeats a warning")
        }

        // Also with everything selected at once and a medication that trips several
        // branches, which is where duplicates would be easiest to miss by eye.
        let everything = Set(Self.selectable)
        let texts = assessment(everything, medication: "diazepam").interactionWarnings
        #expect(Set(texts).count == texts.count, "The full selection repeats a warning")
    }

    // MARK: The medication branches the table cannot see

    @Test("Every medication branch of the preset chain still fires", .tags(.safety), arguments: [
        MedicationBranchCase(
            medication: "isosorbide mononitrate",
            substances: [.viagra],
            expectedLine: .nitratesWithErectileMedication
        ),
        MedicationBranchCase(
            medication: "isosorbide mononitrate",
            substances: [.poppers],
            expectedLine: .nitratesWithErectileMedication
        ),
        MedicationBranchCase(
            medication: "tamsulosin",
            substances: [.kamagra],
            expectedLine: .alphaBlockersWithErectileMedication
        ),
        MedicationBranchCase(
            medication: "diazepam",
            substances: [.alcohol],
            expectedLine: .sedativesWithDepressants
        ),
        MedicationBranchCase(
            medication: "oxycodone",
            substances: [.cannabis],
            expectedLine: .sedativesWithDepressants
        ),
        MedicationBranchCase(
            medication: "oxycodone",
            substances: [.ghb],
            expectedLine: .ghbWithDepressants
        ),
        MedicationBranchCase(
            medication: "methylphenidate",
            substances: [.cocaine],
            expectedLine: .prescribedStimulants
        ),
        MedicationBranchCase(
            medication: "phenelzine",
            substances: [.mdma],
            expectedLine: .maoiWithSerotonergics
        ),
        MedicationBranchCase(
            medication: "sertraline",
            substances: [.mdma],
            expectedLine: .antidepressantsWithSerotonergics
        ),
        MedicationBranchCase(
            medication: "ritonavir",
            substances: [.viagra],
            expectedLine: .ritonavirBooster
        ),
    ])
    func medicationBranchesSurvive(branch: MedicationBranchCase) {
        let findings = assessment(branch.substances, medication: branch.medication).interactionFindings
        #expect(findings.contains { $0.text == branch.expectedLine.localized },
                "\(branch.medication) with \(branch.substances.map(\.rawValue).sorted()) lost its warning: \(findings.map(\.text))")
    }

    @Test("Sedating medication keeps the GHB line even when the table also speaks", .tags(.safety))
    func sedatingMedicationKeepsTheGHBLine() {
        // The table cannot see medication, so the preset line is the only place
        // sedatives and opioids are named. It must not be superseded here even
        // though the table rates GHB with alcohol critical.
        let findings = assessment([.ghb, .alcohol], medication: "diazepam").interactionFindings
        #expect(findings.contains { $0.text == SafetyLine.ghbWithDepressants.localized },
                "The sedative branch was superseded by a table row that knows nothing about medication")
        #expect(findings.contains { $0.level == .critical })
    }

    @Test("Medication only checks still work with no substance selected", .tags(.safety))
    func medicationOnlyStillWarns() {
        // Nothing for the table to match, so this is purely the preset chain.
        let findings = assessment([], medication: "isosorbide mononitrate").interactionFindings
        #expect(findings.contains { $0.level == nil },
                "With no substances there is nothing for either source to match")

        let withSubstance = assessment([.viagra], medication: "isosorbide mononitrate").interactionFindings
        #expect(withSubstance.contains { $0.level == .critical })
    }

    // MARK: Generic preset lines that have no table equivalent

    @Test("Generic single substance preset lines are untouched", .tags(.safety), arguments: [
        (Set<Substance>([.ghb]), SafetyLine.ghbAlone),
        (Set<Substance>([.gbl]), SafetyLine.ghbAlone),
        (Set<Substance>([.poppers]), SafetyLine.poppersAlone),
    ])
    func genericPresetLinesRemain(combo: Set<Substance>, line: SafetyLine) {
        let findings = assessment(combo).interactionFindings
        #expect(findings.contains { $0.text == line.localized },
                "\(combo.map(\.rawValue).sorted()) lost its generic preset line")
    }

    // MARK: What gets saved matches what was shown

    @Test("The saved warning list is the list that was displayed", .tags(.safety))
    func savedWarningsMatchDisplayed() {
        let subject = assessment([.ghb, .alcohol, .cocaine], medication: "sertraline")
        #expect(subject.interactionWarnings == subject.interactionFindings.map(\.text))
    }
}
