import Foundation
import Testing
import ChillMateCore
@testable import ChillMate

/// The small hours, which the app used to judge in three places and judge
/// differently in each.
@Suite("Night mode")
struct NightModeTests {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam") ?? .gmt
        return calendar
    }

    private func date(hour: Int) -> Date {
        Self.calendar.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: hour, minute: 30))!
    }

    @Test("Midnight to five is the middle of the night", arguments: [0, 1, 2, 3, 4])
    func smallHoursAreActive(hour: Int) {
        #expect(NightMode.isActive(at: date(hour: hour), calendar: Self.calendar))
    }

    @Test("Five in the morning is not", arguments: [5, 9, 13, 17])
    func daytimeIsNot(hour: Int) {
        #expect(!NightMode.isActive(at: date(hour: hour), calendar: Self.calendar))
    }

    @Test("Six to midnight is the evening", arguments: [18, 20, 23])
    func eveningIsPreNight(hour: Int) {
        #expect(NightMode.isPreNight(at: date(hour: hour), calendar: Self.calendar))
        #expect(!NightMode.isActive(at: date(hour: hour), calendar: Self.calendar))
    }

    /// The bug this type exists to fix. Home read everything before four in the
    /// morning as *before* a night out, so at 2am it offered a checklist for
    /// getting ready — to somebody who was already out.
    @Test("Two in the morning is not the evening", arguments: [0, 1, 2, 3])
    func smallHoursAreNotPreNight(hour: Int) {
        #expect(!NightMode.isPreNight(at: date(hour: hour), calendar: Self.calendar))
    }

    /// The two windows must not overlap, or the moment Home leads with depends on
    /// the order the checks happen to be written in.
    @Test("The two windows never overlap")
    func windowsAreDisjoint() {
        for hour in 0..<24 {
            let moment = date(hour: hour)
            let night = NightMode.isActive(at: moment, calendar: Self.calendar)
            let evening = NightMode.isPreNight(at: moment, calendar: Self.calendar)
            #expect(!(night && evening), "hour \(hour) is both")
        }
    }
}
