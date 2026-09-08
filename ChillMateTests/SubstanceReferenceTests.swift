import Foundation
import Testing
@testable import ChillMate

/// Guards the sourced dose and duration reference, and the emergency signs.
///
/// These are numbers and sentences a person may act on with someone unconscious
/// in front of them, so the properties asserted here are about internal
/// coherence: a ladder that climbs, timings that run in order, and signs that
/// actually differ between substances. None of it can check the figures against
/// their source — that is what the attribution on screen is for.
@Suite("Sourced substance reference")
struct SubstanceReferenceTests {

    private static let selectable = Substance.allCases.filter { $0 != .unknown && $0 != .other }

    // MARK: Emergency signs

    /// `seekHelpSigns` ignored `self` entirely and returned the same three
    /// sentences for all fourteen substances. Someone checking this screen is
    /// looking at a specific person, and "blue lips, slow breathing" is no use
    /// when the answer for sildenafil is a four-hour erection.
    @Test("Emergency signs are not the same for every substance", .tags(.safety))
    func signsDifferBySubstance() {
        let groups = Set(Self.selectable.map { $0.seekHelpSigns })
        #expect(groups.count > 1, "Every substance still returns an identical list of signs")
        // Depressants, stimulants, poppers, ED medication, cannabis and
        // psychedelics each need their own answer.
        #expect(groups.count >= 6, "Only \(groups.count) distinct sign lists across \(Self.selectable.count) substances")
    }

    @Test("Every substance names at least three things to act on", .tags(.safety), arguments: Substance.allCases)
    func signsArePresent(substance: Substance) {
        let signs = substance.seekHelpSigns
        #expect(signs.count >= 3, "\(substance.rawValue) offers only \(signs.count) signs")
        for sign in signs {
            #expect(sign.isEmpty == false)
        }
        #expect(Set(signs).count == signs.count, "\(substance.rawValue) repeats a sign")
    }

    @Test("GHB names its own collapse pattern", .tags(.safety))
    func ghbNamesItsPattern() {
        // The distinguishing feature of a GHB emergency is how abruptly it
        // arrives, which no generic list conveys.
        for substance in [Substance.ghb, .gbl] {
            #expect(substance.seekHelpSigns != Substance.unknown.seekHelpSigns,
                    "\(substance.rawValue) still falls back to the generic list")
        }
    }

    // MARK: The reference itself

    @Test("Categories that cannot carry one dose ladder do not pretend to", .tags(.safety))
    func categoriesHaveNoLadder() throws {
        #expect(Substance.unknown.reference == nil)
        #expect(Substance.other.reference == nil)

        // Psychedelics spans micrograms to grams; poppers has no measured dose.
        for substance in [Substance.psychedelics, .poppers] {
            let reference = try #require(substance.reference)
            #expect(reference.doses.isEmpty)
            #expect(reference.noDoseReason != nil,
                    "\(substance.rawValue) shows no doses and does not say why")
        }
    }

    @Test("A dose ladder always climbs", .tags(.safety), arguments: Substance.allCases)
    func laddersClimb(substance: Substance) {
        guard let reference = substance.reference else { return }

        for dose in reference.doses {
            #expect(dose.light.lowerBound > 0, "\(substance.rawValue) starts a ladder at or below zero")
            #expect(dose.light.upperBound <= dose.common.lowerBound,
                    "\(substance.rawValue) \(dose.route): light overlaps common")
            #expect(dose.common.upperBound <= dose.strong.lowerBound,
                    "\(substance.rawValue) \(dose.route): common overlaps strong")
            #expect(dose.heavyFrom >= dose.strong.lowerBound,
                    "\(substance.rawValue) \(dose.route): heavy begins below strong")
        }
    }

    @Test("Timings run in order", .tags(.safety), arguments: Substance.allCases)
    func timingsAreOrdered(substance: Substance) {
        guard let timing = substance.reference?.timing else { return }

        #expect(timing.onset.lowerBound >= 0)
        #expect(timing.onset.lowerBound <= timing.onset.upperBound)
        #expect(timing.peak.lowerBound <= timing.peak.upperBound)
        #expect(timing.total.lowerBound <= timing.total.upperBound)
        #expect(timing.onset.lowerBound <= timing.peak.lowerBound,
                "\(substance.rawValue) peaks before it starts")
        #expect(timing.peak.lowerBound <= timing.total.upperBound,
                "\(substance.rawValue) peaks after it is over")
    }

    @Test("Every figure carries a named source", .tags(.safety), arguments: Substance.allCases)
    func figuresAreAttributed(substance: Substance) {
        guard let reference = substance.reference else { return }
        #expect(reference.source.name.isEmpty == false,
                "\(substance.rawValue) shows figures with no attribution")
    }

    @Test("Anything a user can pick has a reference or a stated reason", .tags(.safety))
    func selectableSubstancesAreCovered() {
        for substance in Self.selectable {
            let reference = substance.reference
            #expect(reference != nil, "\(substance.rawValue) is selectable but has no reference at all")
            guard let reference else { continue }
            #expect(reference.doses.isEmpty == false || reference.noDoseReason != nil,
                    "\(substance.rawValue) shows nothing and explains nothing")
        }
    }

    // MARK: Formatting

    @Test("Ranges format without losing the unit", .tags(.safety))
    func rangesCarryTheirUnit() {
        let milligrams = SubstanceReference.Unit.milligrams.range(80...120)
        #expect(milligrams.contains("80"))
        #expect(milligrams.contains("120"))

        // A range whose bounds are equal states one figure, not "50–50".
        let single = SubstanceReference.Unit.milligrams.range(50...50)
        #expect(single.contains("–") == false, "A single value is written as a range: \(single)")
    }

    @Test("Timings switch to hours once they pass an hour", .tags(.safety))
    func timingsReadNaturally() {
        let short = SubstanceReference.Timing.describe(3...10)
        #expect(short.contains("3"))

        let long = SubstanceReference.Timing.describe(180...360)
        #expect(long.contains("180") == false, "A six-hour span is still being written in minutes: \(long)")
    }
}
