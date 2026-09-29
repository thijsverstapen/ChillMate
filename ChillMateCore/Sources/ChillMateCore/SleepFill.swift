import Foundation

/// How much somebody slept after a night, read from what their devices recorded,
/// and when that figure is settled enough to write into their log.
///
/// Pure arithmetic over time intervals, kept out of the HealthKit service so every
/// rule can be tested without a health store.
public enum SleepFill {

    // MARK: - Where to look

    /// The stretch of time after a night in which its sleep is counted.
    ///
    /// Eighteen hours from the end of the night, the window aftercare has always
    /// read sleep from. The log sheet used to count sixteen hours from the *start*
    /// instead, so the same night could get two different figures depending on
    /// which screen asked — and a session that ran past sixteen hours got none at
    /// all, because its window closed before it ended.
    public static func window(forNightEndingAt end: Date) -> DateInterval {
        DateInterval(start: end, duration: 18 * 60 * 60)
    }

    /// How far back to look for nights that still have no sleep.
    ///
    /// A week covers somebody who logs a night and does not open the app again for
    /// a few days, without reaching back through months of history on every launch.
    public static let lookback: TimeInterval = 7 * 24 * 60 * 60

    // MARK: - How long

    /// Time asleep inside `window`, counting each moment once.
    ///
    /// Sleep samples are summed nowhere in this app any more, and the reason is
    /// double counting. A watch writes the night as stages, a sleep app writes the
    /// same night again, the phone may write it a third time — and adding their
    /// durations turned seven hours into fourteen. Health dedupes when it shows
    /// sleep; the old code did not. The union of the intervals is what somebody
    /// actually slept, however many devices noticed.
    ///
    /// Intervals are clipped to the window first, so sleep that began before the
    /// night or ran past the window is only counted for the part inside it.
    public static func asleepDuration(of intervals: [DateInterval], within window: DateInterval) -> TimeInterval {
        let clipped = intervals
            .compactMap { $0.intersection(with: window) }
            .filter { $0.duration > 0 }
            .sorted { $0.start < $1.start }

        var total: TimeInterval = 0
        var current: DateInterval?
        for interval in clipped {
            guard let open = current else {
                current = interval
                continue
            }
            if interval.start <= open.end {
                // Overlapping or touching: extend rather than count twice.
                current = DateInterval(start: open.start, end: max(open.end, interval.end))
            } else {
                total += open.duration
                current = interval
            }
        }
        total += current?.duration ?? 0
        return total
    }

    // MARK: - When to write it

    /// How long after the last recorded sleep somebody counts as up.
    ///
    /// Writing the figure while they are still asleep would lock in half a night,
    /// and automatic sleep never overwrites a night that already has a figure. So it
    /// waits until they have been awake a while, or until the window has closed.
    public static let awakeFor: TimeInterval = 45 * 60

    /// Less than this is not written as a night's sleep.
    ///
    /// A few minutes of recorded doze is more likely a sensor catching somebody
    /// lying still than the sleep that followed a night out, and once written it is
    /// never replaced automatically.
    public static let minimumToRecord: TimeInterval = 30 * 60

    /// What to do about one night.
    public enum Decision: Equatable, Sendable {
        /// Leave it: it already has sleep, was skipped, or is too old.
        case leave
        /// Not yet: the night has not ended, or the person may still be asleep, or
        /// has not slept yet.
        case wait
        /// Write this many hours.
        case record(hours: Double)
    }

    /// Decides for one night.
    ///
    /// - Parameters:
    ///   - nightEnd: when the logged night ended.
    ///   - alreadyHasSleep: the night already carries a sleep figure, typed or read.
    ///     Automatic sleep never replaces one.
    ///   - skipped: a night marked as skipped has nothing to attach sleep to.
    ///   - intervals: every recorded asleep interval that touches the window.
    ///   - now: the current moment.
    public static func decide(
        nightEnd: Date,
        alreadyHasSleep: Bool,
        skipped: Bool,
        intervals: [DateInterval],
        now: Date
    ) -> Decision {
        if alreadyHasSleep || skipped { return .leave }
        if now.timeIntervalSince(nightEnd) > lookback { return .leave }
        if now < nightEnd { return .wait }

        let window = window(forNightEndingAt: nightEnd)
        let asleep = asleepDuration(of: intervals, within: window)
        let windowClosed = now >= window.end

        guard asleep >= minimumToRecord else {
            // Nothing worth writing. Keep waiting while the window is open; once it
            // closes there is nothing more to wait for.
            return windowClosed ? .leave : .wait
        }

        let lastAsleep = intervals
            .compactMap { $0.intersection(with: window)?.end }
            .max()
        let awake = lastAsleep.map { now.timeIntervalSince($0) >= awakeFor } ?? false

        guard windowClosed || awake else { return .wait }
        return .record(hours: asleep / 3600)
    }
}
