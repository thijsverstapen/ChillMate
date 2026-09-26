import Foundation
import Testing
import ChillMateCore

/// What "I'm home safe" does to the weekend check-ins.
///
/// Until 5.1.0 it cleared them, and the next time the app came to the front they
/// were all scheduled again, unchanged, so somebody home at two still got the
/// four o'clock check-in. Clearing also took every future weekend's with it.
@Suite("Weekend check-ins")
struct WeekendCheckInScheduleTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return calendar
    }

    /// Saturday 4 October 2025 at the given time. Saturday's early hours are
    /// Friday night.
    private func saturday(_ hour: Int, _ minute: Int = 0, weekOffset: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2025, month: 10, day: 4 + 7 * weekOffset, hour: hour, minute: minute))!
    }

    private func sunday(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2025, month: 10, day: 5, hour: hour, minute: minute))!
    }

    @Test("Without a home-safe, every slot repeats")
    func nothingQuietedByDefault() {
        let triggers = WeekendCheckInSchedule.triggers(now: saturday(2, 10), lastHomeSafe: nil, calendar: calendar)
        #expect(triggers == WeekendCheckInSchedule.slots.map { .repeating($0) })
    }

    /// The bug itself: home at two, the phone opened at ten past.
    @Test("Home safe at two quiets the four o'clock check-in, and only that one")
    func homeSafeQuietsTheRestOfTheNight() {
        let triggers = WeekendCheckInSchedule.triggers(now: saturday(2, 10), lastHomeSafe: saturday(2), calendar: calendar)

        // Saturday 04:00 moves to the following Saturday, once.
        #expect(triggers[1] == .once(saturday(4, weekOffset: 1)))
        // Saturday 01:30 has passed, and Saturday night's two are a day away.
        #expect(triggers[0] == .repeating(WeekendCheckInSchedule.slots[0]))
        #expect(triggers[2] == .repeating(WeekendCheckInSchedule.slots[2]))
        #expect(triggers[3] == .repeating(WeekendCheckInSchedule.slots[3]))
    }

    @Test("Home safe on Saturday night quiets both of that night's check-ins")
    func homeSafeBeforeBothSlots() {
        let triggers = WeekendCheckInSchedule.triggers(now: sunday(0, 40), lastHomeSafe: sunday(0, 30), calendar: calendar)
        #expect(triggers[2] == .once(calendar.date(byAdding: .day, value: 7, to: sunday(1, 30))!))
        #expect(triggers[3] == .once(calendar.date(byAdding: .day, value: 7, to: sunday(4))!))
        #expect(triggers[0] == .repeating(WeekendCheckInSchedule.slots[0]))
        #expect(triggers[1] == .repeating(WeekendCheckInSchedule.slots[1]))
    }

    /// Opened again the next afternoon: the night is over, so everything goes
    /// back to repeating and next weekend is covered in full.
    @Test("The next day, everything repeats again")
    func quietDoesNotOutlastTheNight() {
        let triggers = WeekendCheckInSchedule.triggers(now: saturday(15), lastHomeSafe: saturday(2), calendar: calendar)
        #expect(triggers == WeekendCheckInSchedule.slots.map { .repeating($0) })
    }

    @Test("A home-safe from last weekend quiets nothing")
    func oldHomeSafeIsIgnored() {
        let triggers = WeekendCheckInSchedule.triggers(now: saturday(1), lastHomeSafe: saturday(2, weekOffset: -1), calendar: calendar)
        #expect(triggers == WeekendCheckInSchedule.slots.map { .repeating($0) })
    }

    /// The quiet window must never reach a check-in of the following night.
    @Test("Quiet lasts less than the gap between two nights")
    func quietWindowIsShorterThanADay() {
        #expect(WeekendCheckInSchedule.quietAfterHomeSafe < 24 * 60 * 60 - 2.5 * 60 * 60)
    }
}
