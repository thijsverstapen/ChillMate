import XCTest
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
