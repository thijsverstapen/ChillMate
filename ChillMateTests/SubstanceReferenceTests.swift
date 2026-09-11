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
        for timing in substance.reference?.timings ?? [] {
            let route = timing.route.map { " (\($0))" } ?? ""

            #expect(timing.onset.lowerBound >= 0)
            #expect(timing.onset.lowerBound <= timing.onset.upperBound)
            #expect(timing.peak.lowerBound <= timing.peak.upperBound)
            #expect(timing.total.lowerBound <= timing.total.upperBound)
            #expect(timing.onset.lowerBound <= timing.peak.lowerBound,
                    "\(substance.rawValue)\(route) peaks before it starts")
            #expect(timing.peak.lowerBound <= timing.total.upperBound,
                    "\(substance.rawValue)\(route) peaks after it is over")
        }
    }

    /// A substance whose dose table separates routes must separate its timings the
    /// same way, or one route's figures stand in for the other's.
    ///
    /// This is the shape of the cannabis bug: two dose rows, one set of timings,
    /// and the smoked onset presented as if it were the edible's.
    @Test("Routes that differ on dose also differ on timing", .tags(.safety), arguments: Substance.allCases)
    func routedDosesHaveRoutedTimings(substance: Substance) {
        guard let reference = substance.reference, reference.doses.count > 1 else { return }
        guard !reference.timings.isEmpty else { return }

        #expect(reference.timings.count > 1,
                "\(substance.rawValue) lists \(reference.doses.count) routes but one set of timings")
        #expect(reference.timings.allSatisfy { $0.route != nil },
                "\(substance.rawValue) has per-route timings that do not say which route")
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

    // MARK: Redosing

    /// Redosing guidance exists where it is documented and is absent where it is
    /// not. Absence is the correct answer for most of these, and a confident
    /// sentence about cocaine redosing would be the app inventing one.
    @Test("Redose guidance appears only where a source supports it", .tags(.safety))
    func redoseGuidanceIsSourced() throws {
        for substance in [Substance.ghb, .gbl, .mdma] {
            let reference = try #require(substance.reference)
            let guidance = try #require(reference.redoseGuidance,
                                        "\(substance.rawValue) has published redose guidance and does not show it")
            #expect(guidance.isEmpty == false)
        }

        // Added in 5.0.0, each with something citable behind it: NHS medicines
        // guidance gives sildenafil a hard one-a-day rule, and PsychonautWiki
        // gives cannabis a twenty-to-sixty-minute oral onset and records cocaine's
        // compulsive redosing as more prevalent than any other common stimulant.
        for substance in [Substance.cocaine, .cannabis, .viagra, .kamagra, .methamphetamine] {
            let guidance = try #require(substance.reference?.redoseGuidance,
                                        "\(substance.rawValue) has a source for redosing and does not show it")
            #expect(guidance.isEmpty == false)
        }

        // Still not an oversight: nothing citable to say.
        for substance in [Substance.ketamine, .poppers, .psychedelics, .benzodiazepines] {
            #expect(substance.reference?.redoseGuidance == nil,
                    "\(substance.rawValue) states a redose interval with no source behind it")
        }
    }

    @Test("The substances with redose guidance name the source it came from", .tags(.safety))
    func redoseGuidanceIsAttributed() throws {
        for substance in [Substance.ghb, .gbl] {
            let reference = try #require(substance.reference)
            #expect(reference.source.name == "Drugs and Me",
                    "\(substance.rawValue) shows redose guidance under the wrong attribution")
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

/// Frequency is what tolerance actually tracks, and the only pattern these logs
/// can see clearly without asking anyone to weigh anything.
@Suite("Consecutive active weeks")
struct ActiveWeeksTests {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return c
    }

    private func entry(daysAgo: Int, substances: [String], skipped: Bool = false, from now: Date) -> NightEntry {
        NightEntry(
            date: calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now,
            hadSex: false,
            skippedNight: skipped,
            substances: substances
        )
    }

    /// A fixed Wednesday, so the week arithmetic never straddles a boundary
    /// differently depending on when the suite runs.
    private var now: Date {
        DateComponents(calendar: calendar, year: 2026, month: 6, day: 10, hour: 12).date ?? .now
    }

    @Test("No logs means no streak", .tags(.safety))
    func emptyIsZero() {
        #expect(ChillInsightCalculator.consecutiveActiveWeeks(entries: [], now: now, calendar: calendar) == 0)
    }

    @Test("Skipped nights do not count as use", .tags(.safety))
    func skipsDoNotCount() {
        let skip = entry(daysAgo: 1, substances: [], skipped: true, from: now)
        #expect(ChillInsightCalculator.consecutiveActiveWeeks(entries: [skip], now: now, calendar: calendar) == 0)
    }

    @Test("Three consecutive weeks count as three", .tags(.safety))
    func consecutiveWeeksCount() {
        let entries = [0, 7, 14].map { entry(daysAgo: $0, substances: ["MDMA"], from: now) }
        #expect(ChillInsightCalculator.consecutiveActiveWeeks(entries: entries, now: now, calendar: calendar) == 3)
    }

    @Test("A clear week ends the run", .tags(.safety))
    func aClearWeekStops() {
        // This week and last, then nothing, then one three weeks further back.
        let entries = [0, 7, 28].map { entry(daysAgo: $0, substances: ["Alcohol"], from: now) }
        #expect(ChillInsightCalculator.consecutiveActiveWeeks(entries: entries, now: now, calendar: calendar) == 2)
    }

    @Test("Two logs in one week are still one week", .tags(.safety))
    func sameWeekCountsOnce() {
        let entries = [0, 1].map { entry(daysAgo: $0, substances: ["Cocaine"], from: now) }
        #expect(ChillInsightCalculator.consecutiveActiveWeeks(entries: entries, now: now, calendar: calendar) == 1)
    }

    /// A quiet Monday is not a broken streak: the current week may simply not
    /// have happened yet, so the count starts from the last week that did.
    @Test("A quiet current week does not zero last week's run", .tags(.safety))
    func currentWeekMayBeEmpty() {
        let entries = [8, 15].map { entry(daysAgo: $0, substances: ["Ketamine"], from: now) }
        #expect(ChillInsightCalculator.consecutiveActiveWeeks(entries: entries, now: now, calendar: calendar) == 2)
    }

    @Test("The walk is bounded", .tags(.safety))
    func doesNotRunAway() {
        let entries = (0..<200).map { entry(daysAgo: $0 * 7, substances: ["GHB"], from: now) }
        let weeks = ChillInsightCalculator.consecutiveActiveWeeks(entries: entries, now: now, calendar: calendar)
        #expect(weeks <= 104, "The week walk is unbounded: \(weeks)")
        #expect(weeks > 0)
    }
}
