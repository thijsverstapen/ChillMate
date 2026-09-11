import Foundation

/// What the logs say about shape rather than volume.
///
/// The insights screen counted four things over the chosen window — chills, risky
/// logs, continued sessions, journal entries. A count answers "how many", which
/// is the least useful question anyone brings to this screen. "Sixteen" tells you
/// nothing you can act on; "almost always a Saturday, and more than the month
/// before" does.
///
/// Everything here is descriptive and derived only from what the person logged.
/// Nothing infers, diagnoses, or advises. `PersonalBaselineCard` already sets the
/// framing this follows: usual for you, not good or bad.
struct NightPatterns: Equatable {

    /// The weekday that holds the most logged nights, and how many of them.
    ///
    /// Nil below `minimumNights`, because one Saturday is not a pattern and
    /// presenting it as one is the failure this whole type exists to avoid.
    struct Busiest: Equatable {
        let weekday: Int
        let count: Int
        let share: Double
    }

    /// How this window compares with the one immediately before it, of equal
    /// length. Nil when there is no earlier window to compare against.
    struct Change: Equatable {
        let current: Int
        let previous: Int

        var difference: Int { current - previous }
        var isFlat: Bool { difference == 0 }
    }

    /// The two substances that most often appear on the same night, with the
    /// number of nights they did.
    struct Pairing: Equatable {
        let first: String
        let second: String
        let nights: Int
    }

    /// Below this, there is not enough to call anything a pattern.
    static let minimumNights = 6

    let busiest: Busiest?
    let change: Change?
    let pairing: Pairing?
    let loggedNights: Int

    /// - Parameters:
    ///   - entries: every entry available, not only the window. The comparison
    ///     needs the preceding window too, and taking a pre-filtered list is how
    ///     the old "risky logs" tile came to report three weeks under a caption
    ///     promising three months.
    ///   - windowDays: the window the screen is showing.
    init(entries: [NightEntry], windowDays: Int, now: Date = .now, calendar: Calendar = .current) {
        let start = calendar.date(byAdding: .day, value: -windowDays, to: now) ?? now
        let previousStart = calendar.date(byAdding: .day, value: -(windowDays * 2), to: now) ?? now

        let logged = entries.filter { !$0.skippedNight && $0.date >= start && $0.date <= now }
        let previous = entries.filter { !$0.skippedNight && $0.date >= previousStart && $0.date < start }

        loggedNights = logged.count

        // Enough of a history to be worth comparing at all.
        change = entries.contains { $0.date < start } ? Change(current: logged.count, previous: previous.count) : nil

        guard logged.count >= Self.minimumNights else {
            busiest = nil
            pairing = nil
            return
        }

        var perWeekday: [Int: Int] = [:]
        for entry in logged {
            perWeekday[calendar.component(.weekday, from: entry.date), default: 0] += 1
        }
        // Ties break on the lower weekday number so the answer is stable between
        // reads rather than flickering between two equally busy days.
        if let top = perWeekday.max(by: { ($0.value, -$0.key) < ($1.value, -$1.key) }), top.value >= 2 {
            busiest = Busiest(
                weekday: top.key,
                count: top.value,
                share: Double(top.value) / Double(logged.count)
            )
        } else {
            busiest = nil
        }

        var perPair: [String: Int] = [:]
        for entry in logged {
            let names = Set(entry.substances).sorted()
            guard names.count >= 2 else { continue }
            for (index, first) in names.enumerated() {
                for second in names[(index + 1)...] {
                    perPair["\(first)\u{0}\(second)", default: 0] += 1
                }
            }
        }
        if let top = perPair.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }), top.value >= 2 {
            let parts = top.key.split(separator: "\u{0}", maxSplits: 1).map(String.init)
            pairing = parts.count == 2
                ? Pairing(first: parts[0], second: parts[1], nights: top.value)
                : nil
        } else {
            pairing = nil
        }
    }

    /// Whether there is anything here worth putting on screen.
    var hasAnythingToSay: Bool {
        busiest != nil || pairing != nil || (change.map { !$0.isFlat } ?? false)
    }
}
