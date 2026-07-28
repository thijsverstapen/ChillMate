import Foundation
import SwiftData

/// Bounded fetch descriptors for the app's `@Query` properties.
///
/// Every `@Query` in the app was declared as a bare sort with no predicate and no
/// limit, so each view materialized its entire table on every appearance. The worst
/// case was `SafetyAutopilotView`, which loaded five complete tables — all night
/// entries, all timers, all plans, all STI tests, all profiles — to render one
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
enum ChillMateQueries {
    /// Night entries for the dashboard's derived metrics.
    ///
    /// Metric windows are 3 weeks (risk comparison) and 3 months (counts), so this
    /// cannot truncate anything the dashboard displays. The one figure that reads
    /// further back is the recovery streak, which needs the most recent entry that
    /// involved substances. Reaching this limit means the user has logged 1,000
    /// consecutive nights — roughly 2.7 years of daily logging — without one, in
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

    /// The user profile. A singleton in practice — every read is `profiles.first`
    /// or an emptiness check — so one row is all any caller uses.
    static var profile: FetchDescriptor<UserProfile> {
        var descriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return descriptor
    }

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
}
