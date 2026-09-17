import Foundation
import Testing
import ChillMateCore
@testable import ChillMate

/// The patterns card, which is the one place on the insights screen that makes a
/// claim rather than showing a count.
///
/// Everything here is descriptive, so the tests are mostly about restraint: what
/// it refuses to say when there is not enough to say it from, and that it never
/// compares a window against one that does not exist.
@Suite("Night patterns")
struct NightPatternsTests {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam") ?? .gmt
        return calendar
    }

    private static let now = Date(timeIntervalSince1970: 1_789_000_000)

    private static func entry(daysAgo: Int, substances: [String] = [], skipped: Bool = false) -> NightEntry {
        NightEntry(
            date: calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now,
            hadSex: false,
            skippedNight: skipped,
            substances: substances
        )
    }

    private static func patterns(_ entries: [NightEntry], windowDays: Int = 30) -> NightPatterns {
        NightPatterns(entries: entries, windowDays: windowDays, now: now, calendar: calendar)
    }

    /// The restraint that matters most: one Saturday is not a pattern.
    @Test("Below the minimum it says nothing about weekdays or pairings")
    func tooLittleDataSaysNothing() {
        let entries = (0..<(NightPatterns.minimumNights - 1)).map { Self.entry(daysAgo: $0 * 2, substances: ["GHB", "MDMA"]) }
        let result = Self.patterns(entries)

        #expect(result.busiest == nil)
        #expect(result.pairing == nil)
    }

    @Test("The busiest weekday is the one with the most nights")
    func findsTheBusiestWeekday() throws {
        // Seven nights, five of them 7 days apart so they land on one weekday.
        var entries = (0..<5).map { Self.entry(daysAgo: $0 * 7) }
        entries.append(Self.entry(daysAgo: 3))
        entries.append(Self.entry(daysAgo: 10))

        let busiest = try #require(Self.patterns(entries).busiest)
        let expected = Self.calendar.component(.weekday, from: Self.now)

        #expect(busiest.weekday == expected)
        #expect(busiest.count == 5)
        #expect(busiest.share > 0.5)
    }

    /// Skipped nights are not logged nights, and counting them would make the
    /// busiest day the day someone most often chose not to.
    @Test("Skipped nights are not counted")
    func skippedNightsAreExcluded() {
        let entries = (0..<10).map { Self.entry(daysAgo: $0, skipped: true) }
        let result = Self.patterns(entries)

        #expect(result.loggedNights == 0)
        #expect(result.busiest == nil)
    }

    /// The comparison needs a previous window. Inventing one from nothing would
    /// report every new user as a dramatic increase.
    @Test("With no history there is nothing to compare against")
    func noHistoryMeansNoComparison() {
        let entries = (0..<8).map { Self.entry(daysAgo: $0) }
        #expect(Self.patterns(entries).change == nil)
    }

    @Test("With history it compares against the window before")
    func comparesAgainstThePreviousWindow() throws {
        let recent = (0..<8).map { Self.entry(daysAgo: $0 + 1) }
        let older = (0..<3).map { Self.entry(daysAgo: 35 + $0) }

        let change = try #require(Self.patterns(recent + older).change)
        #expect(change.current == 8)
        #expect(change.previous == 3)
        #expect(change.difference == 5)
        #expect(change.isFlat == false)
    }

    @Test("The most common pairing is found, and a single night is not one")
    func findsTheMostCommonPairing() throws {
        var entries = (0..<4).map { Self.entry(daysAgo: $0, substances: ["GHB", "MDMA"]) }
        entries += (0..<3).map { Self.entry(daysAgo: 10 + $0, substances: ["Cocaine", "Alcohol"]) }
        entries.append(Self.entry(daysAgo: 20, substances: ["Ketamine", "Poppers"]))

        let pairing = try #require(Self.patterns(entries).pairing)
        #expect([pairing.first, pairing.second].sorted() == ["GHB", "MDMA"])
        #expect(pairing.nights == 4)
    }

    @Test("A night with one substance produces no pairing")
    func singleSubstanceNightsProduceNoPairing() {
        let entries = (0..<8).map { Self.entry(daysAgo: $0, substances: ["GHB"]) }
        #expect(Self.patterns(entries).pairing == nil)
    }

    /// The card draws nothing rather than an empty box.
    @Test("An empty history has nothing to say")
    func emptyHistorySaysNothing() {
        #expect(Self.patterns([]).hasAnythingToSay == false)
    }

    /// The same input must produce the same answer between reads, or the card
    /// flickers between two equally busy days.
    @Test("Ties resolve the same way every time")
    func tiesAreStable() {
        let entries = (0..<8).map { Self.entry(daysAgo: $0) }
        let first = Self.patterns(entries)
        for _ in 0..<5 {
            #expect(Self.patterns(entries) == first)
        }
    }
}
