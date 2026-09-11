import Foundation
import Testing
@testable import ChillMate

/// The PEP window reminders, which are the most time-critical notifications the
/// app sends.
///
/// Post-exposure prophylaxis has to begin within 72 hours. A reminder that
/// arrives after the window has closed is not merely useless — the follow-up one
/// says "You still have time to speak with a clinician", which by then is false.
///
/// The behaviour before 5.0.0 was to schedule both reminders at 9am and 3pm
/// tomorrow whatever the deadline was, so every case below where the window
/// closes inside a day was scheduled wrong.
@Suite("PEP window reminders")
struct PEPReminderScheduleTests {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam") ?? .gmt
        return calendar
    }

    private static func date(_ day: Int, _ hour: Int, _ minute: Int = 0) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            year: 2026, month: 9, day: day, hour: hour, minute: minute
        )))
    }

    /// The property that matters, stated once: nothing is ever scheduled outside
    /// the window.
    @Test("Every reminder falls inside the window", .tags(.safety))
    func remindersAreAlwaysInsideTheWindow() throws {
        let now = try Self.date(11, 2)

        for hours in [1, 3, 6, 12, 24, 36, 48, 60, 72] {
            let deadline = now.addingTimeInterval(Double(hours) * 3600)
            let dates = PEPReminderSchedule.reminderDates(
                deadline: deadline, now: now, calendar: Self.calendar
            )
            for date in dates {
                #expect(date > now, "a \(hours)h window scheduled a reminder in the past")
                #expect(date < deadline, "a \(hours)h window scheduled a reminder after it closed")
            }
            #expect(dates.count <= PEPReminderSchedule.maximumReminders)
            #expect(dates == dates.sorted(), "reminders are not in order for a \(hours)h window")
        }
    }

    /// The case the old code got wrong. Exposure at 2am with a window closing at
    /// 8am the same morning used to be told about it at 9am and 3pm, both after
    /// the fact.
    @Test("A window closing before the first clinic hour still gets a reminder", .tags(.safety))
    func shortOvernightWindowIsNotMissed() throws {
        let now = try Self.date(11, 2)
        let deadline = try Self.date(11, 8)

        let dates = PEPReminderSchedule.reminderDates(
            deadline: deadline, now: now, calendar: Self.calendar
        )

        #expect(dates.isEmpty == false, "a six-hour window sent nothing at all")
        #expect(dates.allSatisfy { $0 > now && $0 < deadline })
    }

    /// A full 72-hour window has plenty of room, so it should use the clinic-hours
    /// slots rather than an arbitrary midpoint.
    @Test("A full window uses mid-morning and mid-afternoon")
    func fullWindowUsesPreferredHours() throws {
        let now = try Self.date(11, 2)
        let deadline = now.addingTimeInterval(72 * 3600)

        let dates = PEPReminderSchedule.reminderDates(
            deadline: deadline, now: now, calendar: Self.calendar
        )

        #expect(dates.count == 2)
        let hours = dates.map { Self.calendar.component(.hour, from: $0) }
        #expect(hours.allSatisfy { PEPReminderSchedule.preferredHours.contains($0) },
                "expected clinic hours, got \(hours)")
        // Same morning, not tomorrow: the window is open now.
        #expect(Self.calendar.isDate(dates[0], inSameDayAs: now))
    }

    @Test("A closed window schedules nothing", .tags(.safety))
    func closedWindowSchedulesNothing() throws {
        let now = try Self.date(11, 12)
        let deadline = try Self.date(11, 9)

        #expect(PEPReminderSchedule.reminderDates(
            deadline: deadline, now: now, calendar: Self.calendar
        ).isEmpty)
    }

    /// A window about to shut is not worth an interruption that arrives as it
    /// closes.
    @Test("A window closing within minutes schedules nothing", .tags(.safety))
    func windowAboutToCloseSchedulesNothing() throws {
        let now = try Self.date(11, 12)
        let deadline = now.addingTimeInterval(PEPReminderSchedule.minimumLeadTime - 60)

        #expect(PEPReminderSchedule.reminderDates(
            deadline: deadline, now: now, calendar: Self.calendar
        ).isEmpty)
    }

    /// Exposure in the evening: the next useful moment is tomorrow morning, and
    /// that is inside a 72-hour window.
    @Test("An evening exposure waits for the morning")
    func eveningExposureWaitsForMorning() throws {
        let now = try Self.date(11, 22)
        let deadline = now.addingTimeInterval(72 * 3600)

        let dates = PEPReminderSchedule.reminderDates(
            deadline: deadline, now: now, calendar: Self.calendar
        )

        let first = try #require(dates.first)
        #expect(Self.calendar.component(.hour, from: first) == 9)
        #expect(Self.calendar.component(.day, from: first) == 12)
    }
}
