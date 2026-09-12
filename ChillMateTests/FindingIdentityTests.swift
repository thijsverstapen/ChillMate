import Foundation
import Testing
import ChillMateCore
@testable import ChillMate

/// Covers the two things a finding has to get right besides its wording: who it
/// is, and whether it admits what it could not check.
@Suite("Finding identity and unchecked medication")
struct FindingIdentityTests {

    private func assessment(_ substances: Set<Substance>, medication: String = "") -> CombinationAssessment {
        CombinationAssessment(
            substances: Array(substances),
            medicationText: medication,
            timing: .sameSession
        )
    }

    private static let selectable = Substance.allCases.filter { $0 != .unknown && $0 != .other }

    // MARK: Identity

    /// A finding's `id` used to be its own localized text, so a row's SwiftUI
    /// identity changed with the app's language and every row was rebuilt on a
    /// language switch.
    @Test("A finding's identity is never its own prose", .tags(.safety))
    func identityIsNotTheText() {
        let findings = assessment([.ghb, .alcohol, .cocaine], medication: "diazepam").interactionFindings
        #expect(findings.isEmpty == false)

        for finding in findings {
            #expect(finding.id != finding.text, "\(finding.id) is still keyed on its own wording")
            #expect(finding.id.isEmpty == false)
            // Identifiers are ASCII keys, never sentences.
            #expect(finding.id.contains(" ") == false, "\(finding.id) looks like prose, not an identifier")
        }
    }

    @Test("Findings in one assessment have unique identities", .tags(.safety))
    func identitiesAreUnique() {
        for pair in Self.selectable.flatMap({ a in Self.selectable.map { Set([a, $0]) } }) where pair.count == 2 {
            let ids = assessment(pair).interactionFindings.map(\.id)
            #expect(Set(ids).count == ids.count,
                    "\(pair.map(\.rawValue).sorted()) produces two findings with the same id: \(ids)")
        }
    }

    @Test("Table rows take their identity from the pairing", .tags(.safety))
    func tableRowsCarryTheirPairing() throws {
        let curated = try #require(SubstanceInteractionChecker.warnings(for: [.cocaine, .alcohol]).first)
        let findings = assessment([.cocaine, .alcohol]).interactionFindings
        let match = try #require(findings.first { $0.text == curated.warning })
        #expect(match.id == "table.\(curated.id)")
    }

    // MARK: Medication the app could not place

    /// Typing a medication we cannot match is not the same as typing nothing.
    /// Someone who misspells "diazepam" used to get the warnings their substances
    /// earned and no sign at all that the sedative they disclosed was never weighed.
    @Test("An unrecognised medication is reported, not passed over", .tags(.safety))
    func unrecognisedMedicationIsReported() {
        let findings = assessment([.alcohol], medication: "zzzznotamedicine").interactionFindings
        #expect(findings.contains { $0.text == SafetyLine.medicationNotRecognised.localized },
                "The user is not told their medication went unchecked: \(findings.map(\.text))")
    }

    @Test("The notice appears even when the substances did match something", .tags(.safety))
    func noticeSurvivesAlongsideRealWarnings() {
        let findings = assessment([.ghb, .alcohol], medication: "zzzznotamedicine").interactionFindings
        #expect(findings.contains { $0.level == .critical }, "The rated pairing still has to show")
        #expect(findings.contains { $0.text == SafetyLine.medicationNotRecognised.localized },
                "A matched pairing must not mask the unchecked medication")
    }

    @Test("A recognised medication produces no such notice", .tags(.safety), arguments: [
        "diazepam", "oxycodone", "sertraline", "phenelzine", "tamsulosin", "ritonavir",
    ])
    func recognisedMedicationIsSilent(medication: String) {
        let findings = assessment([.alcohol], medication: medication).interactionFindings
        #expect(findings.contains { $0.text == SafetyLine.medicationNotRecognised.localized } == false,
                "\(medication) is in the database but was reported as unrecognised")
    }

    @Test("No medication typed means no notice", .tags(.safety))
    func emptyMedicationIsSilent() {
        for combo: Set<Substance> in [[], [.alcohol], [.ghb, .alcohol]] {
            let findings = assessment(combo).interactionFindings
            #expect(findings.contains { $0.text == SafetyLine.medicationNotRecognised.localized } == false,
                    "\(combo.map(\.rawValue).sorted()) reports an unrecognised medication with none entered")
        }
    }

    @Test("Whitespace alone is not a medication", .tags(.safety))
    func whitespaceIsNotMedication() {
        let findings = assessment([.alcohol], medication: "   \n  ").interactionFindings
        #expect(findings.contains { $0.text == SafetyLine.medicationNotRecognised.localized } == false)
    }
}

/// The stack the pairwise table cannot see.
///
/// Every pair in a three-depressant selection has its own table row, so the old
/// output was three warnings about three pairs and nothing about the pile. The
/// mechanism that kills is the pile.
@Suite("Depressant load")
struct DepressantLoadTests {

    private func assessment(_ substances: Set<Substance>, medication: String = "") -> CombinationAssessment {
        CombinationAssessment(
            substances: Array(substances),
            medicationText: medication,
            timing: .sameSession
        )
    }

    private func hasLoadWarning(_ findings: [InteractionFinding]) -> Bool {
        findings.contains { $0.id == "depressantLoad" }
    }

    @Test("Three depressants are named as a stack, not just as pairs", .tags(.safety), arguments: [
        Set<Substance>([.alcohol, .ghb, .ketamine]),
        Set<Substance>([.alcohol, .gbl, .ketamine]),
        Set<Substance>([.ghb, .gbl, .alcohol]),
    ])
    func threeDepressantsWarn(combo: Set<Substance>) throws {
        let findings = assessment(combo).interactionFindings
        #expect(hasLoadWarning(findings),
                "\(combo.map(\.rawValue).sorted()) shows only pairwise warnings")

        let warning = try #require(findings.first { $0.id == "depressantLoad" })
        #expect(warning.level == .critical)
    }

    @Test("Sedative medication counts toward the pile", .tags(.safety))
    func medicationCounts() {
        // Two substances plus a prescribed sedative is three things slowing
        // breathing, and the table can see none of that third one.
        #expect(hasLoadWarning(assessment([.alcohol, .ketamine], medication: "diazepam").interactionFindings))
        #expect(hasLoadWarning(assessment([.alcohol, .ghb], medication: "oxycodone").interactionFindings))
    }

    @Test("Two depressants do not trip it", .tags(.safety), arguments: [
        Set<Substance>([.alcohol, .ketamine]),
        Set<Substance>([.ghb, .alcohol]),
    ])
    func twoDepressantsDoNotWarn(combo: Set<Substance>) {
        #expect(hasLoadWarning(assessment(combo).interactionFindings) == false,
                "\(combo.map(\.rawValue).sorted()) is a pair, which the table already covers")
    }

    @Test("Stimulants do not count as depressants", .tags(.safety))
    func stimulantsDoNotCount() {
        #expect(hasLoadWarning(assessment([.cocaine, .mdma, .threeMMC]).interactionFindings) == false)
    }

    @Test("The stack warning is never superseded by a table row", .tags(.safety))
    func neverSuperseded() {
        // GHB with alcohol is rated critical by the table, which supersedes the
        // generic GHB preset line. It must not take the load warning with it.
        let findings = assessment([.alcohol, .ghb, .ketamine]).interactionFindings
        #expect(hasLoadWarning(findings))
        #expect(findings.contains { $0.level == .critical })
    }

    @Test("It leads, because it describes the whole selection", .tags(.safety))
    func loadWarningComesFirst() throws {
        let findings = assessment([.alcohol, .ghb, .ketamine]).interactionFindings
        let first = try #require(findings.first)
        #expect(first.id == "depressantLoad", "The stack is stated after the pairs: \(findings.map(\.id))")
    }
}
