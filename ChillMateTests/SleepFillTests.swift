import Foundation
import Testing
import ChillMateCore

/// Reading how long somebody slept, and deciding when to write it into their log.
@Suite("Sleep fill")
struct SleepFillTests {

    private let night = Date(timeIntervalSince1970: 1_790_000_000)   // the night ends

    private func hours(_ h: Double) -> TimeInterval { h * 3600 }

    private func interval(from start: Double, to end: Double) -> DateInterval {
        DateInterval(start: night.addingTimeInterval(hours(start)), end: night.addingTimeInterval(hours(end)))
    }

    private var window: DateInterval { SleepFill.window(forNightEndingAt: night) }

    // MARK: How long

    /// The bug this replaces: the same night recorded by two devices was added up,
    /// so seven hours read as fourteen.
    @Test("The same night from two devices counts once")
    func overlappingSourcesCountOnce() {
        let watch = interval(from: 5, to: 12)
        let sleepApp = interval(from: 5, to: 12)
        #expect(SleepFill.asleepDuration(of: [watch, sleepApp], within: window) == hours(7))
    }

    @Test("Partly overlapping records are merged, not summed")
    func partialOverlapMerges() {
        // 05:00–10:00 from one source, 09:00–12:00 from another: 05:00–12:00.
        let total = SleepFill.asleepDuration(of: [interval(from: 5, to: 10), interval(from: 9, to: 12)], within: window)
        #expect(total == hours(7))
    }

    /// A watch writes a night as stages that butt up against each other.
    @Test("Touching stages join into one stretch")
    func touchingStagesJoin() {
        let stages = [interval(from: 5, to: 6), interval(from: 6, to: 8), interval(from: 8, to: 12)]
        #expect(SleepFill.asleepDuration(of: stages, within: window) == hours(7))
    }

    @Test("Separate sleeps add up")
    func separateSleepsAdd() {
        let total = SleepFill.asleepDuration(of: [interval(from: 5, to: 9), interval(from: 11, to: 13)], within: window)
        #expect(total == hours(6))
    }

    @Test("Sleep outside the window is not counted, and sleep across its edge is clipped")
    func windowClips() {
        // During the night, and running past the eighteen-hour mark.
        let before = interval(from: -3, to: -1)
        let across = interval(from: 16, to: 22)
        #expect(SleepFill.asleepDuration(of: [before, across], within: window) == hours(2))
    }

    @Test("No intervals is no sleep")
    func nothingIsZero() {
        #expect(SleepFill.asleepDuration(of: [], within: window) == 0)
    }

    // MARK: When to write it

    private func decide(
        _ intervals: [DateInterval],
        at hoursAfterEnd: Double,
        alreadyHasSleep: Bool = false,
        skipped: Bool = false
    ) -> SleepFill.Decision {
        SleepFill.decide(
            nightEnd: night,
            alreadyHasSleep: alreadyHasSleep,
            skipped: skipped,
            intervals: intervals,
            now: night.addingTimeInterval(hours(hoursAfterEnd))
        )
    }

    /// Up for more than the grace period: the figure is settled.
    @Test("Once somebody has been up a while, their sleep is written")
    func writesOnceAwake() {
        #expect(decide([interval(from: 5, to: 12)], at: 13) == .record(hours: 7))
    }

    /// Never lock in half a night: it is never replaced automatically afterwards.
    @Test("Nothing is written while they may still be asleep")
    func waitsWhileAsleep() {
        #expect(decide([interval(from: 5, to: 12)], at: 12.25) == .wait)
    }

    @Test("A closed window is written even without the grace period")
    func closedWindowWrites() {
        // The last sleep ends exactly at the window's edge.
        #expect(decide([interval(from: 12, to: 18)], at: 18) == .record(hours: 6))
    }

    /// The rule that protects anything somebody typed themselves.
    @Test("A night that already has sleep is never overwritten")
    func neverOverwrites() {
        #expect(decide([interval(from: 5, to: 12)], at: 20, alreadyHasSleep: true) == .leave)
    }

    @Test("A skipped night gets no sleep")
    func skippedIsLeft() {
        #expect(decide([interval(from: 5, to: 12)], at: 20, skipped: true) == .leave)
    }

    @Test("A doze too short to be a night's sleep is not written")
    func shortDozeIsIgnored() {
        #expect(decide([interval(from: 5, to: 5.25)], at: 8) == .wait)
        #expect(decide([interval(from: 5, to: 5.25)], at: 19) == .leave)
    }

    @Test("A night with no recorded sleep is left alone once its window closes")
    func noSleepAfterWindowIsLeft() {
        #expect(decide([], at: 10) == .wait)
        #expect(decide([], at: 19) == .leave)
    }

    @Test("Nights older than the lookback are not touched")
    func oldNightsAreLeft() {
        let eightDays = SleepFill.lookback / 3600 + 24
        #expect(decide([interval(from: 5, to: 12)], at: eightDays) == .leave)
    }

    /// Somebody logging a night that is still going, or logging it ahead.
    @Test("A night that has not ended is waited on, not written")
    func unfinishedNightWaits() {
        #expect(decide([interval(from: -5, to: -2)], at: -1) == .wait)
    }

    /// Two devices, one night, and the person is up: the written figure is the
    /// real one, not the doubled one.
    @Test("What gets written is the merged figure")
    func writesMergedFigure() {
        #expect(decide([interval(from: 5, to: 12), interval(from: 5, to: 12)], at: 13) == .record(hours: 7))
    }
}
