import Foundation
import SwiftData

/// Bounded fetch descriptors for the app's `@Query` properties.
///
/// Every `@Query` in the app was declared as a bare sort with no predicate and no
/// limit, so each view materialized its entire table on every appearance. The worst
/// case was `SafetyAutopilotView`, which loaded five complete tables (all night
/// entries, all timers, all plans, all STI tests, all profiles) to render one
/// status card. `DashboardView` loaded six. For an app people log in daily, that
/// grows without bound.
///
/// The limits below are deliberately generous: comfortably more than any screen
/// displays, while keeping fetches O(limit) instead of O(table).
///
/// Deliberately using `fetchLimit` rather than a date predicate. A predicate would
/// need a cutoff `Date` captured when the view initializes, which goes stale in a
/// long-lived view and silently shifts what a screen shows as the app sits open.
/// A row limit has no such clock dependency.
///
/// The exception is any figure that aggregates: a count, a sum, an average, a
/// minimum, a maximum, a streak. A limit bounds a list harmlessly, because nobody
/// notices the thousandth row they never scrolled to. It caps an aggregate
/// silently, and a capped aggregate is indistinguishable from a real number that
/// stopped moving. Aggregates read through the windowed descriptors at the bottom
/// of this file, which take a cutoff and carry no limit at all.
enum ChillMateQueries {
    /// Night entries for the dashboard's derived metrics.
    ///
    /// Metric windows are 3 weeks (risk comparison) and 3 months (counts), so this
    /// cannot truncate anything the dashboard displays. The one figure that reads
    /// further back is the recovery streak, which needs the most recent entry that
    /// involved substances. Reaching this limit means the user has logged 1,000
    /// consecutive nights (roughly 2.7 years of daily logging) without one, in
    /// which case the streak falls back to their profile start date and still
    /// reports a very long streak.
    static var dashboardEntries: FetchDescriptor<NightEntry> {
        var descriptor = FetchDescriptor<NightEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1000
        return descriptor
    }

    /// Night entries for history, calendar and insight screens.
    static var recentEntries: FetchDescriptor<NightEntry> {
        var descriptor = FetchDescriptor<NightEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1000
        return descriptor
    }

    /// The user profile. A singleton in practice: every read is `profiles.first`
    /// or an emptiness check, so one row is all any caller uses.
    static var profile: FetchDescriptor<UserProfile> {
        var descriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return descriptor
    }

    /// Timers for the screens that list them. Counting inside this limit is wrong:
    /// use `timers(since:)` for that.
    static var recentTimers: FetchDescriptor<DrugDoseTimerRecord> {
        var descriptor = FetchDescriptor<DrugDoseTimerRecord>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        return descriptor
    }

    static var recentTests: FetchDescriptor<STDTestRecord> {
        var descriptor = FetchDescriptor<STDTestRecord>(
            sortBy: [SortDescriptor(\.testDate, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        return descriptor
    }

    static var recentPlansByCreation: FetchDescriptor<SaferSessionPlan> {
        var descriptor = FetchDescriptor<SaferSessionPlan>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        return descriptor
    }

    static var recentPlansByDate: FetchDescriptor<SaferSessionPlan> {
        var descriptor = FetchDescriptor<SaferSessionPlan>(
            sortBy: [SortDescriptor(\.plannedDate, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        return descriptor
    }

    /// Journal entries for the screens that list them. Counting inside this limit is
    /// wrong: use `journalEntries(since:)` for that.
    static var recentJournalEntries: FetchDescriptor<JournalEntry> {
        var descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 500
        return descriptor
    }

    static var recentRiskChecks: FetchDescriptor<RiskCheckRecord> {
        var descriptor = FetchDescriptor<RiskCheckRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        return descriptor
    }

    /// Timers started on or after `start`, with no row limit.
    ///
    /// For counters, not for lists. `recentTimers` stops at 200 rows, which is
    /// generous for a list nobody scrolls to the bottom of but wrong for a tally:
    /// somebody who starts more timers than that, across their own doses and the
    /// people they track, would watch the tally freeze at 200 and stay there, with
    /// nothing on screen admitting it had been truncated. A window predicate has no
    /// cap to hit, and the fetch still stays small because the window is what bounds
    /// it now.
    ///
    /// The caller supplies the cutoff so the clock lives with the view that owns the
    /// window. Build it with `windowStart(daysBack:)`.
    static func timers(since start: Date) -> FetchDescriptor<DrugDoseTimerRecord> {
        FetchDescriptor<DrugDoseTimerRecord>(
            predicate: #Predicate<DrugDoseTimerRecord> { $0.startedAt >= start },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
    }

    /// Journal entries written on or after `start`, with no row limit.
    ///
    /// Same reasoning as `timers(since:)`: `recentJournalEntries` stops at 500 rows,
    /// which is plenty for the journal list and a wrong answer for "how many did I
    /// write". Fetching a window also keeps the externally stored photo blobs of
    /// older entries out of the read.
    static func journalEntries(since start: Date) -> FetchDescriptor<JournalEntry> {
        FetchDescriptor<JournalEntry>(
            predicate: #Predicate<JournalEntry> { $0.date >= start },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
    }

    /// Start of the day `days` days before `now`.
    ///
    /// Rounded down to a day boundary deliberately. A cutoff of "this instant minus
    /// 90 days" is a different value on every read, so a `@Query` built from it is a
    /// different descriptor on every view update and refetches for nothing. Day
    /// granularity is also what the logs themselves are counted in, so a window that
    /// starts mid morning would drop part of its own oldest day.
    static func windowStart(daysBack days: Int, now: Date = .now, calendar: Calendar = .current) -> Date {
        guard let start = calendar.date(byAdding: .day, value: -days, to: now) else {
            return .distantPast
        }
        return calendar.startOfDay(for: start)
    }
}
