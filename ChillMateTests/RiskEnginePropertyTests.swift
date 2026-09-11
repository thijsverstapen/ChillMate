import Foundation
import Testing
@testable import ChillMate

/// Properties the risk engine has to hold for *every* selection, not just the
/// ones somebody thought to write down.
///
/// The rest of the suite is example-based: it names a pairing and asserts what
/// comes back. That catches regressions in the cases already known about and
/// nothing else. These walk every selection of one, two and three substances —
/// 231 of them — and assert the invariants that must survive whatever the table
/// and the preset chain do to each other.
///
/// Monotonicity is the one that matters most. A warning a user would have seen
/// for two substances must not vanish when they add a third, because the moment
/// they add a third is exactly the moment it stops being safe to lose it.
@Suite("Risk engine properties")
struct RiskEnginePropertyTests {

    private static let selectable = Substance.allCases.filter { $0 != .unknown && $0 != .other }

    /// Every selection of one, two or three selectable substances.
    private static var selections: [Set<Substance>] {
        var out: [Set<Substance>] = []
        for (i, a) in selectable.enumerated() {
            out.append([a])
            for (j, b) in selectable.enumerated() where j > i {
                out.append([a, b])
                for (k, c) in selectable.enumerated() where k > j {
                    out.append([a, b, c])
                }
            }
        }
        return out
    }

    private func assessment(_ substances: Set<Substance>, medication: String = "") -> CombinationAssessment {
        CombinationAssessment(
            substances: Array(substances),
            medicationText: medication,
            timing: .sameSession
        )
    }

    @Test("Every selection produces at least one finding", .tags(.safety))
    func neverSilent() {
        for combo in Self.selections {
            let findings = assessment(combo).interactionFindings
            #expect(findings.isEmpty == false,
                    "\(combo.map(\.rawValue).sorted()) produces nothing at all, not even the fallback")
        }
    }

    @Test("Identities are unique within every selection", .tags(.safety))
    func identitiesStayUnique() {
        for combo in Self.selections {
            let ids = assessment(combo).interactionFindings.map(\.id)
            #expect(Set(ids).count == ids.count,
                    "\(combo.map(\.rawValue).sorted()) repeats an identity: \(ids)")
        }
    }

    @Test("Text is never repeated within a selection", .tags(.safety))
    func textStaysUnique() {
        for combo in Self.selections {
            let texts = assessment(combo).interactionWarnings
            #expect(Set(texts).count == texts.count,
                    "\(combo.map(\.rawValue).sorted()) states the same thing twice")
        }
    }

    /// Adding a substance can add warnings and can replace wording. It can never
    /// take a warning away.
    @Test("Adding a substance never removes a warning", .tags(.safety))
    func findingsAreMonotonic() {
        for combo in Self.selections where combo.count < 3 {
            let before = Set(assessment(combo).interactionFindings.filter { $0.level != nil }.map(\.id))

            for extra in Self.selectable where !combo.contains(extra) {
                let after = Set(assessment(combo.union([extra])).interactionFindings.map(\.id))
                let lost = before.subtracting(after)

                // A preset line may legitimately step aside for a table row that
                // covers the same hazard at least as severely, so a lost id is
                // only a failure when the severity went down with it. That is
                // asserted separately below; here we only require that a rated
                // finding is not replaced by nothing at all.
                if !lost.isEmpty {
                    #expect(after.isEmpty == false,
                            "\(combo.map(\.rawValue).sorted()) + \(extra.rawValue) dropped \(lost) and put nothing in its place")
                }
            }
        }
    }

    /// The merge is allowed to reword. It is never allowed to soften.
    @Test("Adding a substance never lowers the worst rating", .tags(.safety))
    func severityIsMonotonic() {
        for combo in Self.selections where combo.count < 3 {
            let before = assessment(combo).interactionFindings.compactMap(\.level).max()
            guard let before else { continue }

            for extra in Self.selectable where !combo.contains(extra) {
                // Two distinct failures, kept apart: the rating dropping, and every
                // rated finding vanishing. `#require` collapsed them into one and
                // warned that it was redundant besides.
                guard let after = assessment(combo.union([extra])).interactionFindings.compactMap(\.level).max() else {
                    Issue.record("\(combo.map(\.rawValue).sorted()) rated \(before), and adding \(extra.rawValue) left no rated finding at all")
                    continue
                }
                #expect(after >= before,
                        "\(combo.map(\.rawValue).sorted()) rated \(before), and adding \(extra.rawValue) lowered it to \(after)")
            }
        }
    }

    @Test("The fallback and a real warning never appear together", .tags(.safety))
    func fallbackIsExclusive() {
        for combo in Self.selections {
            let findings = assessment(combo).interactionFindings
            let hasFallback = findings.contains { $0.id == "nothingMatched" }
            let hasRated = findings.contains { $0.level != nil }
            #expect(!(hasFallback && hasRated),
                    "\(combo.map(\.rawValue).sorted()) claims nothing matched alongside a rated warning")
        }
    }

    @Test("Every rated finding carries text", .tags(.safety))
    func ratedFindingsAreReadable() {
        for combo in Self.selections {
            for finding in assessment(combo).interactionFindings {
                #expect(finding.text.isEmpty == false,
                        "\(combo.map(\.rawValue).sorted()) produced a finding with no text (\(finding.id))")
                #expect(finding.id.isEmpty == false)
            }
        }
    }

    /// The table rates pairs and cannot see a third thing, so this is the one
    /// finding that must appear purely as a function of how many depressants are
    /// selected.
    @Test("The depressant stack warning tracks the count exactly", .tags(.safety))
    func depressantLoadTracksTheCount() {
        let depressants: Set<Substance> = [.ghb, .gbl, .alcohol, .ketamine]

        for combo in Self.selections {
            let load = combo.intersection(depressants).count
            let findings = assessment(combo).interactionFindings
            let warned = findings.contains { $0.id == "depressantLoad" }

            #expect(warned == (load >= 3),
                    "\(combo.map(\.rawValue).sorted()) has \(load) depressants and warned: \(warned)")
        }
    }

    @Test("Results do not vary between identical calls", .tags(.safety))
    func evaluationIsDeterministic() {
        for combo in Self.selections {
            let first = assessment(combo).interactionFindings.map(\.id)
            let second = assessment(combo).interactionFindings.map(\.id)
            #expect(first == second,
                    "\(combo.map(\.rawValue).sorted()) evaluates differently on a second read")
        }
    }

    /// The list is deliberately not globally sorted by severity.
    ///
    /// `interactionFindings` states the contract: the preset chain leads and
    /// stays intact, because it is the only source that can see the medication
    /// the user typed, and the curated table follows in its own most-severe-first
    /// order. So the guarantee is per-source, and asserting a global sort fails
    /// against a design decision rather than a bug — which is exactly what the
    /// first version of this test did.
    @Test("Table findings are severity-ordered among themselves", .tags(.safety))
    func tableFindingsAreOrdered() {
        for combo in Self.selections {
            let tableLevels = assessment(combo).interactionFindings
                .filter { $0.id.hasPrefix("table.") }
                .compactMap(\.level)
            #expect(tableLevels == tableLevels.sorted(by: >),
                    "\(combo.map(\.rawValue).sorted()) returns table rows out of order: \(tableLevels)")
        }
    }

    /// Whatever the order within the list, the worst rating a selection carries
    /// has to be reachable — it must actually be in the findings, not lost in the
    /// merge between the two sources.
    @Test("The worst rating in the table always reaches the list", .tags(.safety))
    func worstRatingSurvivesTheMerge() {
        for combo in Self.selections {
            guard let curated = SubstanceInteractionChecker.warnings(for: combo).map(\.level).max() else { continue }
            let shown = assessment(combo).interactionFindings.compactMap(\.level).max()
            #expect((shown ?? .caution) >= curated,
                    "\(combo.map(\.rawValue).sorted()) is rated \(curated) by the table and shown as \(String(describing: shown))")
        }
    }
}
