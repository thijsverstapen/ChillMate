import Foundation
import Testing
@testable import ChillMate

/// The one document in ChillMate that a professional reads and acts on.
///
/// It had no tests, because it lived as a `private enum` inside its view. It also
/// took a `riskChecks` parameter it never read, and was written in English while
/// the rest of the app speaks five languages — neither of which anything could
/// have caught.
@Suite("Helper summary")
struct HelperSummaryTests {

    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func daysAgo(_ days: Int) -> Date {
        now.addingTimeInterval(-Double(days) * 86_400)
    }

    private func check(medication: String, daysAgo days: Int) -> RiskCheckRecord {
        RiskCheckRecord(
            medicationText: medication,
            timing: .sameSession,
            substanceNames: [Substance.mdma.rawValue],
            serotoninLevel: "",
            dehydrationLevel: "",
            stimulantLevel: "",
            warnings: [],
            createdAt: daysAgo(days)
        )
    }

    private func summary(
        entries: [NightEntry] = [],
        timers: [DrugDoseTimerRecord] = [],
        tests: [STDTestRecord] = [],
        checks: [RiskCheckRecord] = []
    ) -> String {
        HelperSummary.text(
            profile: nil,
            entries: entries,
            timers: timers,
            stiTests: tests,
            riskChecks: checks,
            now: now
        )
    }

    // MARK: - The dropped parameter

    /// `riskChecks` was queried, passed in, and never read. Somebody who had
    /// checked every combination they took handed over a sheet that said nothing
    /// about it — which is the part a prescriber would most want to see.
    @Test("Combination checks reach the sheet")
    func riskChecksAreReported() {
        let text = summary(checks: [check(medication: "sertraline", daysAgo: 3)])
        #expect(text.contains("sertraline"))
        #expect(text.contains(HelperSummary.sectionTitleForTesting))
    }

    @Test("Medication entered more than once is listed once")
    func medicationIsDeduplicated() {
        let text = summary(checks: [
            check(medication: "Sertraline", daysAgo: 1),
            check(medication: "sertraline", daysAgo: 2),
            check(medication: "lithium", daysAgo: 3)
        ])
        #expect(text.components(separatedBy: "ertraline").count - 1 == 1)
        #expect(text.contains("lithium"))
    }

    /// Everything under the heading is counted over the same window. A check from
    /// four months ago appearing under "Past 90 days" is the kind of quiet error
    /// that makes a clinician reading the sheet draw the wrong conclusion.
    @Test("Checks outside the window are excluded")
    func oldChecksAreExcluded() {
        let text = summary(checks: [check(medication: "citalopram", daysAgo: 120)])
        #expect(!text.contains("citalopram"))
    }

    @Test("An empty history produces a sheet rather than nothing")
    func emptyHistoryStillProducesASheet() {
        let text = summary()
        #expect(!text.isEmpty)
        // Every section survives an empty history: a sheet missing its headings
        // reads as a broken export rather than as a quiet period.
        #expect(text.contains(HelperSummary.sectionTitleForTesting))
    }

    // MARK: - Language

    /// The sheet is handed to a doctor who speaks the reader's language. Every
    /// label goes through the catalog, so this passes in English by construction
    /// and fails in the other four the moment one is added as a bare literal.
    @Test("Every heading resolves through the catalog")
    func headingsAreLocalized() {
        let text = summary()
        for heading in HelperSummary.headingsForTesting {
            #expect(text.contains(heading), "missing heading: \(heading)")
        }
    }
}
