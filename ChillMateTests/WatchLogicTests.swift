import Foundation
import Testing
@testable import ChillMate

/// The two decisions the watch makes without the phone.
///
/// The watch app has no test bundle of its own — standing up a watchOS runner in
/// CI for two rules is not worth it — so the rules live in `WidgetSharedKeys.swift`,
/// which is a member of every target, and are exercised from here.
@Suite("Watch logic")
struct WatchLogicTests {

    // MARK: The emergency number

    /// The default is right for five of the six countries ChillMate ships support
    /// for and reaches nobody in the sixth, so anything real must beat it.
    @Test("A stored number beats the 112 default", .tags(.safety))
    func storedNumberWins() {
        #expect(WatchLogic.emergencyNumber(stored: "911") == "911")
        #expect(WatchLogic.emergencyNumber(stored: "000") == "000")
    }

    @Test("A number relayed now beats a stored one", .tags(.safety))
    func relayedNumberWins() {
        #expect(WatchLogic.emergencyNumber(stored: "112", relayed: "911") == "911")
    }

    /// The failure this exists to prevent: an empty string dials nothing, and a
    /// blank arriving from the phone must not overwrite a good stored number or
    /// beat the default.
    @Test("Blank never wins, from either side", .tags(.safety), arguments: ["", " ", "   "])
    func blankNeverWins(blank: String) {
        #expect(WatchLogic.emergencyNumber(stored: blank) == "112")
        #expect(WatchLogic.emergencyNumber(stored: "911", relayed: blank) == "911")
        #expect(WatchLogic.emergencyNumber(stored: nil, relayed: blank) == "112")
    }

    @Test("With nothing at all, it still returns something dialable", .tags(.safety))
    func neverReturnsEmpty() {
        let number = WatchLogic.emergencyNumber(stored: nil, relayed: nil)
        #expect(number.isEmpty == false)
        #expect(number == "112")
    }

    // MARK: The day rollover

    @Test("The day key changes at local midnight and not before")
    func dayKeyFollowsLocalMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Amsterdam"))

        let midnight = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 11)))
        let lateSameNight = midnight.addingTimeInterval(23 * 3600 + 59 * 60)
        let justAfter = midnight.addingTimeInterval(24 * 3600)

        #expect(WatchLogic.dayKey(for: midnight, calendar: calendar)
                == WatchLogic.dayKey(for: lateSameNight, calendar: calendar))
        #expect(WatchLogic.dayKey(for: justAfter, calendar: calendar)
                == WatchLogic.dayKey(for: midnight, calendar: calendar) + 1)
    }

    /// A night out runs past midnight, which is exactly when this is used.
    @Test("Three in the morning belongs to the new day, as the rest of the app has it")
    func threeAmIsTheNextDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Amsterdam"))

        let evening = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 23)))
        let afterMidnight = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 3)))

        #expect(WatchLogic.dayKey(for: afterMidnight, calendar: calendar)
                == WatchLogic.dayKey(for: evening, calendar: calendar) + 1)
    }

    /// Zero is what `UserDefaults.integer(forKey:)` returns for a key that was
    /// never written, and it must not read as "already sent today".
    @Test("A watch that has never sent one can still send today")
    func neverSentIsAvailable() {
        #expect(WatchLogic.isAvailableToday(lastSentDay: 0))
    }

    @Test("Sent today blocks, sent yesterday does not")
    func availabilityFollowsTheDay() {
        let today = WatchLogic.dayKey(for: .now)
        #expect(WatchLogic.isAvailableToday(lastSentDay: today) == false)
        #expect(WatchLogic.isAvailableToday(lastSentDay: today - 1))
    }
}
