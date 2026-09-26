import XCTest
import SwiftData
import ChillMateCore
@testable import ChillMate

/// Time and memory budgets for the work that grows with a person's history.
///
/// Written with XCTest rather than Swift Testing because `measure(metrics:)` is
/// the only sanctioned way to record a metric, and XCTMemoryMetric is the only
/// way to see peak footprint without attaching Instruments to a running app.
/// Both frameworks live in this target happily.
///
/// **These are ceilings, not benchmarks.** A shared CI runner is several times
/// slower than a laptop and noisy with it, so every number here has an order of
/// magnitude of headroom. They exist to catch a change that makes something
/// quadratic in the number of logged nights — the shape of regression that is
/// invisible on a developer's six test entries and unusable on a real user's
/// three years — not to police milliseconds.
///
/// Excluded from the five-language loop in CI, because they measure arithmetic
/// and the arithmetic does not have a language. They run once, on their own.
final class PerformanceTests: XCTestCase {

    /// Three years of nights, which is more than the App Store's oldest installs
    /// can have and therefore the right upper bound to design against.
    private static let entryCount = 1_095

    private static let calendar = Calendar(identifier: .gregorian)
    private static let now = Date(timeIntervalSince1970: 1_789_000_000)

    private static let substancePool: [[String]] = [
        [Substance.alcohol.rawValue],
        [Substance.mdma.rawValue, Substance.alcohol.rawValue],
        [Substance.ghb.rawValue, Substance.ketamine.rawValue],
        [Substance.cocaine.rawValue],
        [Substance.cannabis.rawValue, Substance.alcohol.rawValue],
        [],
    ]

    private lazy var entries: [NightEntry] = (0..<Self.entryCount).map { index in
        NightEntry(
            date: Self.calendar.date(byAdding: .day, value: -index, to: Self.now) ?? Self.now,
            hadSex: index % 3 == 0,
            skippedNight: index % 7 == 0,
            substances: Self.substancePool[index % Self.substancePool.count]
        )
    }

    /// Every combination the checker can be asked about, which is what a property
    /// test does and what a user does over a long enough period.
    private static var everyPair: [Set<Substance>] {
        let substances = Substance.allCases
        return substances.flatMap { first in
            substances.compactMap { second in
                first == second ? nil : Set([first, second])
            }
        }
    }

    private func assertUnder(_ seconds: Double, _ label: String, _ body: () -> Void) {
        let started = Date.now
        body()
        let elapsed = Date.now.timeIntervalSince(started)
        XCTAssertLessThan(elapsed, seconds, "\(label) took \(elapsed) s, ceiling is \(seconds) s")
    }

    // MARK: - The risk engine

    func testEveryPairIsAssessed() {
        let pairs = Self.everyPair
        measure {
            for pair in pairs {
                _ = CombinationAssessment(
                    substances: Array(pair), medicationText: "", timing: .sameSession
                ).interactionFindings
            }
        }
    }

    func testEveryPairIsAssessedInsideItsBudget() {
        let pairs = Self.everyPair
        assertUnder(2.0, "assessing \(pairs.count) pairs") {
            for pair in pairs {
                _ = CombinationAssessment(
                    substances: Array(pair), medicationText: "", timing: .sameSession
                ).interactionFindings
            }
        }
    }

    /// Medication matching scans free text against the whole database, and the
    /// assessment asks for it from several properties.
    func testAssessmentWithMedicationIsInsideItsBudget() {
        assertUnder(2.0, "assessing with medication") {
            for pair in Self.everyPair {
                _ = CombinationAssessment(
                    substances: Array(pair),
                    medicationText: "sertraline, lithium, diazepam, tamsulosin",
                    timing: .sameSession
                ).interactionFindings
            }
        }
    }

    // MARK: - Work that grows with history

    func testInsightsOverThreeYears() {
        measure {
            _ = ChillInsightCalculator.substanceCounts(entries: entries)
            _ = ChillInsightCalculator.triggerCounts(entries: entries)
        }
    }

    func testInsightsOverThreeYearsAreInsideTheirBudget() {
        assertUnder(1.0, "insights over \(entries.count) entries") {
            _ = ChillInsightCalculator.substanceCounts(entries: entries)
            _ = ChillInsightCalculator.triggerCounts(entries: entries)
        }
    }

    /// The patterns card reads the *unwindowed* list, because it compares one
    /// window against the one before it. That makes it the piece most exposed to
    /// a long history.
    func testNightPatternsOverThreeYears() {
        measure {
            _ = NightPatterns(entries: entries, windowDays: 30, now: Self.now, calendar: Self.calendar)
        }
    }

    func testNightPatternsOverThreeYearsAreInsideTheirBudget() {
        assertUnder(1.0, "patterns over \(entries.count) entries") {
            _ = NightPatterns(entries: entries, windowDays: 30, now: Self.now, calendar: Self.calendar)
        }
    }

    // MARK: - Opening the store

    /// What the app pays before it can draw anything.
    ///
    /// **This is not launch time**, and should not be quoted as it. A real launch
    /// budget needs `XCTApplicationLaunchMetric` in the UI bundle, and the UI
    /// bundle is advisory in CI — a number that cannot fail the build is not a
    /// budget. This measures the part of launch that can be gated here: building
    /// the schema and opening a store on disk with three years in it.
    ///
    /// It is the dominant cost of a SwiftData launch, it grows with the schema,
    /// and it is what a new `@Model`, a new index or a migration stage lands on.
    @MainActor
    func testOpeningAStoreWithThreeYearsInIt() throws {
        let url = try seededStoreURL()
        defer { try? FileManager.default.removeItem(at: url) }

        measure {
            _ = try? ModelContainer(
                for: Self.fullSchema,
                configurations: [ModelConfiguration(url: url)]
            )
        }
    }

    @MainActor
    func testOpeningAStoreIsInsideItsBudget() throws {
        let url = try seededStoreURL()
        defer { try? FileManager.default.removeItem(at: url) }

        assertUnder(2.0, "opening a store of \(Self.entryCount) nights") {
            _ = try? ModelContainer(
                for: Self.fullSchema,
                configurations: [ModelConfiguration(url: url)]
            )
        }
    }

    /// Every model the app registers, so the measurement covers the schema the
    /// app actually opens rather than a convenient subset of it.
    private static let fullSchema = Schema([
        NightEntry.self,
        LoggedSubstanceRecord.self,
        PartnerDetailRecord.self,
        TriggerTagRecord.self,
        UserProfile.self,
        STDTestRecord.self,
        DrugDoseTimerRecord.self,
        SaferSessionPlan.self,
        JournalEntry.self,
        RiskCheckRecord.self
    ])

    /// A store on disk holding the same three years the rest of this file uses.
    @MainActor
    private func seededStoreURL() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ChillMateLaunch-\(UUID().uuidString).store")
        let context = ModelContext(try ModelContainer(
            for: Self.fullSchema,
            configurations: [ModelConfiguration(url: url)]
        ))
        for entry in entries {
            context.insert(entry)
        }
        try context.save()
        return url
    }

    // MARK: - Reading a night's substances

    /// `entry.substances` is not stored: every read filters, sorts, dedupes and
    /// maps a relationship. The filters that decide which nights the insights,
    /// the helper summary and the weekly reflection count all used to call it
    /// once per entry, purely to ask whether the list was empty.
    ///
    /// `hasSubstances` answers that without the ordering. This is the measurement
    /// that says whether the swap was worth making, and the budget is what stops
    /// the cheap path quietly regressing into the expensive one.
    func testEmptinessCheckOverThreeYears() {
        measure {
            _ = entries.filter(\.hasSubstances).count
        }
    }

    func testEmptinessCheckIsInsideItsBudget() {
        assertUnder(0.5, "emptiness over \(entries.count) entries") {
            _ = entries.filter(\.hasSubstances).count
        }
    }

    /// The same count through the list, kept as the comparison. If this ever
    /// stops being the slower of the two, `hasSubstances` has lost its reason to
    /// exist and the call sites should go back to the obvious spelling.
    ///
    /// Measured over many rounds, alternating, after a warm-up. The first version
    /// of this timed one run of each with the cheap one first, so it paid every
    /// first-touch cost and handed the other warm data — and duly reported that
    /// the optimisation was not an optimisation. A benchmark that can be wrong in
    /// the flattering direction is worse than none.
    func testEmptinessViaTheListIsTheSlowerPath() {
        // Warm both paths so neither pays for the other's first touch.
        _ = entries.filter(\.hasSubstances).count
        _ = entries.filter { !$0.substances.isEmpty }.count

        var cheap: TimeInterval = 0
        var full: TimeInterval = 0
        for round in 0..<10 {
            // Alternate which goes first, so a systematic ordering effect cancels
            // instead of accumulating into the answer.
            if round.isMultiple(of: 2) {
                cheap += duration { _ = entries.filter(\.hasSubstances).count }
                full += duration { _ = entries.filter { !$0.substances.isEmpty }.count }
            } else {
                full += duration { _ = entries.filter { !$0.substances.isEmpty }.count }
                cheap += duration { _ = entries.filter(\.hasSubstances).count }
            }
        }

        XCTAssertLessThanOrEqual(
            cheap, full,
            "hasSubstances (\(cheap)s over 10 rounds) is no longer cheaper than reading the list (\(full)s)"
        )
        print("emptiness check: hasSubstances \(cheap)s vs list \(full)s over 10 rounds")
    }

    /// Wall-clock for one run of a block. Deliberately not `measure`, which
    /// reports rather than returns.
    private func duration(_ body: () -> Void) -> TimeInterval {
        let start = Date()
        body()
        return Date().timeIntervalSince(start)
    }

    /// The sheet a clinician reads, built from the whole history every time the
    /// view's `summary` is recomputed.
    func testHelperSummaryOverThreeYears() {
        measure {
            _ = HelperSummary.text(
                profile: nil, entries: entries, timers: [], stiTests: [], riskChecks: [], now: Self.now
            )
        }
    }

    // MARK: - Memory

    /// A peak-footprint ceiling for the same work.
    ///
    /// `XCTMemoryMetric` measures the test process, so the absolute number
    /// includes the harness and is not meaningful on its own — what it catches is
    /// a change that starts holding the whole history in a second form. The
    /// assertion below is the one with teeth: the derived values must not scale
    /// with the input.
    func testMemoryOverThreeYears() {
        measure(metrics: [XCTMemoryMetric(), XCTClockMetric()]) {
            _ = ChillInsightCalculator.substanceCounts(entries: entries)
            _ = NightPatterns(entries: entries, windowDays: 30, now: Self.now, calendar: Self.calendar)
        }
    }

    /// Insight output is a summary and must stay one. A change that returned a
    /// row per night instead of a row per substance would still pass every
    /// correctness test in the suite and would quietly make the screen unusable
    /// for anybody with a long history.
    func testInsightOutputDoesNotGrowWithHistory() {
        let counts = ChillInsightCalculator.substanceCounts(entries: entries)
        XCTAssertLessThanOrEqual(
            counts.count, Substance.allCases.count,
            "substance counts should be one row per substance, not per night"
        )

        let patterns = NightPatterns(entries: entries, windowDays: 30, now: Self.now, calendar: Self.calendar)
        XCTAssertLessThanOrEqual(patterns.loggedNights, entries.count)
    }
}
