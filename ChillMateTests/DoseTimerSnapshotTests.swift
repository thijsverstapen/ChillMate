import Foundation
import Testing
@testable import ChillMate

/// What crosses from the app into the Lock Screen widget.
///
/// This is a process boundary: the app writes into an App Group suite and a
/// separate extension reads it back, with no shared memory and no compiler
/// checking that one end agrees with the other. `WidgetSharedKey` stops the key
/// names drifting; these stop the meaning drifting.
@Suite("Dose timer snapshot", .serialized)
struct DoseTimerSnapshotTests {

    private let suiteName = "group.com.codex.ChillMate.tests.dosetimer"
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func freshSuite() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func snapshot(comedownHours: Double?) -> DoseTimerSnapshot {
        DoseTimerSnapshot(
            substanceName: "MDMA",
            startedAt: start,
            endsAt: start.addingTimeInterval(4 * 3600),
            comedownEndsAt: comedownHours.map { start.addingTimeInterval($0 * 3600) }
        )
    }

    @Test("A snapshot survives the crossing unchanged")
    func roundTrip() throws {
        let defaults = freshSuite()
        let written = snapshot(comedownHours: 30)
        DoseTimerSnapshot.write(written, to: defaults)

        let read = try #require(DoseTimerSnapshot.read(from: defaults, now: start))
        #expect(read == written)
    }

    /// A substance with no published after-effects window must come back with
    /// none, not with a zero date that renders as 1970.
    @Test("An absent comedown stays absent")
    func absentComedownRoundTrips() throws {
        let defaults = freshSuite()
        DoseTimerSnapshot.write(snapshot(comedownHours: nil), to: defaults)

        let read = try #require(DoseTimerSnapshot.read(from: defaults, now: start))
        #expect(read.comedownEndsAt == nil)
        #expect(read.lastMoment == read.endsAt)
    }

    /// Nothing wakes the app to tidy up after itself, so a snapshot has to expire
    /// on the way out. Otherwise a force-quit on Saturday leaves a Lock Screen
    /// insisting on Tuesday that a dose is still running.
    @Test("An expired snapshot reads as nothing")
    func expiredSnapshotsAreNotReturned() {
        let defaults = freshSuite()
        DoseTimerSnapshot.write(snapshot(comedownHours: 30), to: defaults)

        #expect(DoseTimerSnapshot.read(from: defaults, now: start.addingTimeInterval(29 * 3600)) != nil)
        #expect(DoseTimerSnapshot.read(from: defaults, now: start.addingTimeInterval(31 * 3600)) == nil)
    }

    @Test("Writing nothing clears what was there")
    func writingNilClears() {
        let defaults = freshSuite()
        DoseTimerSnapshot.write(snapshot(comedownHours: 30), to: defaults)
        DoseTimerSnapshot.write(nil, to: defaults)

        #expect(DoseTimerSnapshot.read(from: defaults, now: start) == nil)
        #expect(defaults.string(forKey: WidgetSharedKey.doseTimerSubstance) == nil)
    }

    @Test("An empty suite reads as nothing rather than as a dose at 1970")
    func emptySuiteReadsAsNothing() {
        #expect(DoseTimerSnapshot.read(from: freshSuite(), now: start) == nil)
    }

    /// The whole reason the widget outlives the check-in timer.
    @Test("The comedown phase begins when the check-in window ends")
    func comedownPhaseBoundary() {
        let snapshot = snapshot(comedownHours: 30)
        #expect(!snapshot.isInComedown(at: start.addingTimeInterval(3 * 3600)))
        #expect(snapshot.isInComedown(at: start.addingTimeInterval(5 * 3600)))
        #expect(!snapshot.isInComedown(at: start.addingTimeInterval(31 * 3600)))
    }

    // MARK: - Picking which timer

    private func record(
        substance: Substance = .mdma,
        startedAt: Date,
        hours: Double = 4,
        person: String = "",
        route: AdministrationRoute = .swallowed
    ) -> DrugDoseTimerRecord {
        DrugDoseTimerRecord(
            substanceName: substance.rawValue,
            startedAt: startedAt,
            durationHours: hours,
            administrationRoute: route,
            personName: person
        )
    }

    /// A timer kept for somebody else is that person's substance use, on a screen
    /// anybody standing nearby can read without unlocking the phone.
    @Test("A timer kept for someone else never reaches the Lock Screen")
    func trackedPeopleAreNotShown() {
        let mine = record(startedAt: start)
        let theirs = record(startedAt: start.addingTimeInterval(600), person: "Sam")

        let chosen = ActiveDoseTimer.mostRelevant(in: [mine, theirs], now: start.addingTimeInterval(900))
        #expect(chosen?.personName.isEmpty == true)
        #expect(ActiveDoseTimer.mostRelevant(in: [theirs], now: start.addingTimeInterval(900)) == nil)
    }

    @Test("The most recently started timer wins")
    func newestWins() throws {
        let older = record(startedAt: start)
        let newer = record(substance: .ketamine, startedAt: start.addingTimeInterval(3600))

        let chosen = try #require(
            ActiveDoseTimer.mostRelevant(in: [older, newer], now: start.addingTimeInterval(4000))
        )
        #expect(chosen.substanceName == Substance.ketamine.rawValue)
    }

    /// The check-in window is a reminder the user chose the length of. The
    /// published window is what the sources say. A two-hour reminder on an MDMA
    /// dose must not take the Lock Screen down 46 hours early.
    @Test("A finished check-in stays on the Lock Screen while its comedown runs")
    func comedownOutlivesTheCheckIn() throws {
        let timer = record(startedAt: start, hours: 2)
        let afterTheTimer = start.addingTimeInterval(6 * 3600)

        #expect(timer.endsAt < afterTheTimer)
        let chosen = try #require(ActiveDoseTimer.mostRelevant(in: [timer], now: afterTheTimer))
        #expect(ActiveDoseTimer.snapshot(for: chosen).isInComedown(at: afterTheTimer))
    }

    /// A substance with no published window falls off when its own timer does,
    /// rather than lingering on a window that was never published.
    @Test("Without a published window, the timer ending is the end of it")
    func noPublishedWindowMeansNoExtension() {
        let timer = record(substance: .cocaine, startedAt: start, hours: 2, route: .sniffed)
        let snapshot = ActiveDoseTimer.snapshot(for: timer)

        #expect(snapshot.comedownEndsAt == nil)
        #expect(ActiveDoseTimer.mostRelevant(in: [timer], now: start.addingTimeInterval(3 * 3600)) == nil)
    }

    /// The route has to reach the published curve, or an edible gets the smoked
    /// window on the Lock Screen too.
    @Test("The logged route picks the published curve")
    func routeReachesTheCurve() throws {
        let smoked = ActiveDoseTimer.snapshot(
            for: record(substance: .cannabis, startedAt: start, route: .smoked)
        )
        let eaten = ActiveDoseTimer.snapshot(
            for: record(substance: .cannabis, startedAt: start, route: .swallowed)
        )
        let smokedEnd = try #require(smoked.comedownEndsAt)
        let eatenEnd = try #require(eaten.comedownEndsAt)
        #expect(eatenEnd > smokedEnd)
    }
}
