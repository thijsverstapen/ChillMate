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

    /// A two-hour timer has room for exactly one, at ninety minutes. A shorter
    /// one has room for none, and must schedule none rather than one that lands
    /// after the window it was meant to cover.
    @Test("A window shorter than the first delay schedules nothing")
    func shortWindowsScheduleNothing() {
        #expect(dates(hours: 1).isEmpty)
        #expect(dates(hours: 1.4).isEmpty)
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
