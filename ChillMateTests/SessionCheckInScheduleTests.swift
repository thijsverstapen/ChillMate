import Foundation
import Testing
import ChillMateCore
@testable import ChillMate

/// When somebody gets checked on during a night out.
///
/// This arithmetic used to live inside `NotificationService`, next to
/// `UNUserNotificationCenter`, where nothing could reach it.
@Suite("Session check-in schedule")
struct SessionCheckInScheduleTests {

    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func dates(hours: Double, startedHoursAgo: Double = 0) -> [Date] {
        SessionCheckInSchedule.checkInDates(
            startsAt: start.addingTimeInterval(-startedHoursAgo * 3600),
            endsAt: start.addingTimeInterval((hours - startedHoursAgo) * 3600),
            now: start
        )
    }

    @Test("The first check-in is ninety minutes in")
    func firstCheckInDelay() throws {
        let first = try #require(dates(hours: 6).first)
        #expect(first.timeIntervalSince(start) == SessionCheckInSchedule.firstCheckInDelay)
    }

    @Test("Check-ins land every ninety minutes")
    func spacing() {
        let dates = dates(hours: 6)
        let gaps = zip(dates, dates.dropFirst()).map { $1.timeIntervalSince($0) }
        #expect(gaps.allSatisfy { $0 == SessionCheckInSchedule.interval })
    }

    /// A two-hour timer has room for exactly one, at ninety minutes.
    ///
    /// This used to also assert that a shorter window schedules *nothing*, on the
    /// reasoning that none is better than one landing after the window it was
    /// meant to cover. The second half of that is still true and still enforced,
    /// by `nothingIsScheduledPastTheEnd` and by the short-session tests below —
    /// but scheduling nothing was not the only way to honour it. Moving the
    /// check-in earlier honours it too, and actually checks on the person, which
    /// is what the feature is for. An hour-long session received silence.
    @Test("A two-hour window has room for exactly one at the normal cadence")
    func twoHourWindowGetsOne() {
        #expect(dates(hours: 2).count == 1)
    }

    @Test("Nothing is scheduled past the end of the window")
    func nothingAfterTheEnd() {
        let end = start.addingTimeInterval(6 * 3600)
        let dates = SessionCheckInSchedule.checkInDates(startsAt: start, endsAt: end, now: start)
        #expect(dates.allSatisfy { $0 < end })
    }

    /// A timer logged after the fact — "I took it two hours ago" — must not
    /// schedule a check-in for a moment that has already passed, because iOS
    /// delivers a past-dated trigger immediately and the user gets a burst of
    /// check-ins for a night that is already underway.
    @Test("A session logged retroactively counts from now")
    func retroactiveSessionsCountFromNow() throws {
        let first = try #require(dates(hours: 8, startedHoursAgo: 3).first)
        #expect(first >= start)
        #expect(first.timeIntervalSince(start) == SessionCheckInSchedule.firstCheckInDelay)
    }

    /// iOS keeps 64 pending notifications per app and silently drops the rest. A
    /// session with no ceiling would spend that budget on itself and quietly cost
    /// the user their PEP window reminder.
    @Test("A very long window is capped")
    func longWindowsAreCapped() {
        let dates = dates(hours: 24 * 14)
        #expect(dates.count == SessionCheckInSchedule.maximumCheckIns)
        #expect(!SessionCheckInSchedule.hasRoomForEscalation(after: dates.count))
    }

    @Test("A normal night leaves room for the end-of-session escalation")
    func normalNightsLeaveRoom() {
        #expect(SessionCheckInSchedule.hasRoomForEscalation(after: dates(hours: 8).count))
    }

    // MARK: Short sessions

    /// A session shorter than the first delay received nothing at all: the first
    /// check-in was placed at ninety minutes and then tested against a window
    /// that had already closed. The feature exists to check on somebody, and for
    /// a short timer it stayed silent.
    @Test("A session too short for the normal cadence still gets one check-in", arguments: [
        0.5, 0.75, 1.0, 1.25, 1.4,
    ])
    func shortSessionsAreStillCheckedOn(hours: Double) throws {
        let scheduled = dates(hours: hours)
        #expect(scheduled.count == 1, "\(hours)h received \(scheduled.count) check-ins")

        let only = try #require(scheduled.first)
        let offset = only.timeIntervalSince(start)
        #expect(offset >= SessionCheckInSchedule.shortSessionFloor,
                "a check-in landed sooner than the floor allows")
        #expect(offset < hours * 3600,
                "a check-in landed after the session had already ended")
    }

    /// The floor only applies when the alternative is silence. A window long
    /// enough for the normal cadence must still get its first check-in at ninety
    /// minutes, not at the floor.
    @Test("The floor never pulls a normal session's first check-in earlier")
    func floorDoesNotDisturbNormalSessions() throws {
        for hours in [2.0, 4.0, 8.0, 12.0] {
            let first = try #require(dates(hours: hours).first)
            #expect(first.timeIntervalSince(start) == SessionCheckInSchedule.firstCheckInDelay,
                    "\(hours)h moved its first check-in")
        }
    }

    /// The property that makes this change safe to ship: it adds check-ins and
    /// never removes one. Asserted against the previous behaviour, recomputed
    /// here, rather than against remembered numbers.
    @Test("No window is checked on less often than the fixed cadence managed")
    func neverFewerThanBefore() {
        func fixedCadenceCount(windowHours: Double) -> Int {
            var count = 0
            var offset = SessionCheckInSchedule.firstCheckInDelay
            while offset < windowHours * 3600, count < SessionCheckInSchedule.maximumCheckIns {
                count += 1
                offset += SessionCheckInSchedule.interval
            }
            return count
        }

        for tenths in 1...240 {
            let hours = Double(tenths) / 10
            #expect(dates(hours: hours).count >= fixedCadenceCount(windowHours: hours),
                    "\(hours)h lost a check-in")
        }
    }

    @Test("A window that has already closed schedules nothing")
    func closedWindowSchedulesNothing() {
        #expect(dates(hours: 0).isEmpty)
        #expect(dates(hours: -1).isEmpty)
    }

    /// The duration inside the safer-plan reminder is formatted rather than
    /// stored, because it used to be an English literal interpolated into a
    /// translated sentence.
    @Test("Reminder durations are formatted, not spelled")
    func durationsAreFormatted() {
        for offset in SaferPlanReminderSchedule.offsets {
            let label = SaferPlanReminderSchedule.durationLabel(offset)
            #expect(!label.isEmpty)
            // A number and a unit, whatever the unit is called in this language.
            #expect(label.rangeOfCharacter(from: .decimalDigits) != nil, "no number in \(label)")
            #expect(label.rangeOfCharacter(from: .letters) != nil, "no unit in \(label)")
        }
    }
}
