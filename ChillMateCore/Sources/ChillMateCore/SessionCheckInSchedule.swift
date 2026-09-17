import Foundation

/// When a session's wellbeing check-ins land.
///
/// Pulled out of `NotificationService` for the same reason `PEPReminderSchedule`
/// was: the service talks to `UNUserNotificationCenter`, which means none of the
/// arithmetic inside it could be tested, and this particular arithmetic decides
/// whether somebody gets checked on during a night out.
///
/// That is the pattern this codebase uses instead of injecting protocols
/// everywhere. Making the whole service injectable would mean threading a
/// dependency through 64 call sites to make one decision testable; lifting the
/// decision out makes it testable and leaves the 64 call sites alone.
public enum SessionCheckInSchedule {

    /// How long after a session starts the first check-in lands.
    ///
    /// Ninety minutes, and not sooner: a check-in that arrives while somebody is
    /// still arriving somewhere is the one that teaches them to swipe these away.
    public static let firstCheckInDelay: TimeInterval = 90 * 60

    /// The gap between check-ins.
    public static let interval: TimeInterval = 90 * 60

    /// A ceiling, so a timer set to an absurd length cannot schedule hundreds of
    /// notifications. iOS keeps 64 pending notifications per app and silently
    /// drops the rest, which would quietly cost the user their *other* reminders
    /// — the PEP window, the STI follow-up — rather than these.
    public static let maximumCheckIns = 48

    /// Every check-in moment for a session, in order.
    ///
    /// - Parameters:
    ///   - startsAt: when the session began. A session that began in the past
    ///     counts from now, so a timer logged retroactively does not schedule a
    ///     check-in for a moment that has already gone.
    ///   - endsAt: when the session's window closes.
    ///   - now: the current moment.
    public static func checkInDates(startsAt: Date, endsAt: Date, now: Date = .now) -> [Date] {
        var dates: [Date] = []
        var date = max(now, startsAt).addingTimeInterval(firstCheckInDelay)
        while date < endsAt, dates.count < maximumCheckIns {
            dates.append(date)
            date = date.addingTimeInterval(interval)
        }
        return dates
    }

    /// Whether the end-of-session escalation still fits under the ceiling.
    public static func hasRoomForEscalation(after checkInCount: Int) -> Bool {
        checkInCount < maximumCheckIns
    }
}

/// When the reminders before a safer session plan ends land, and what they call
/// the time left.
///
/// Outside `NotificationService` because that type is `@MainActor` and this is
/// arithmetic and formatting — isolating it to the main actor bought nothing and
/// cost every test an actor hop.
public enum SaferPlanReminderSchedule {

    /// How long before a plan ends each reminder lands.
    public static let offsets: [TimeInterval] = [60 * 60, 30 * 60, 10 * 60]

    /// Identifiers written by builds that spelled the English label into them.
    ///
    /// Cleared alongside the current ones. Without this, a plan rescheduled after
    /// updating leaves the old reminders pending under identifiers nothing can
    /// name any more, and they fire on top of the new ones.
    public static let legacyLabels = ["1 hour", "30 minutes", "10 minutes"]

    /// A duration in the reader's language, formatted by Foundation rather than
    /// stored as text.
    ///
    /// The sentence around it was translated and the duration inside it was not,
    /// so every Dutch reader was told their plan ends "over 30 minutes". Deriving
    /// it from the number needs no catalog entry and cannot fall out of step with
    /// the offsets it describes.
    public static func durationLabel(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(
            .units(allowed: [.hours, .minutes], width: .wide, maximumUnitCount: 1)
        )
    }
}
