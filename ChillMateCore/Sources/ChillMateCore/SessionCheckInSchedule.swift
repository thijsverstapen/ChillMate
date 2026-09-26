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

    /// The earliest a check-in will ever land, used only to rescue a session too
    /// short to receive one at all.
    ///
    /// Twenty minutes is far inside the ninety the normal cadence uses, which is
    /// deliberate: it applies when the alternative is silence, not when the
    /// alternative is a check-in at ninety.
    public static let shortSessionFloor: TimeInterval = 20 * 60

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
        let begin = max(now, startsAt)
        let window = endsAt.timeIntervalSince(begin)
        guard window > 0 else { return [] }

        var dates: [Date] = []
        var date = begin.addingTimeInterval(firstCheckInDelay)
        while date < endsAt, dates.count < maximumCheckIns {
            dates.append(date)
            date = date.addingTimeInterval(interval)
        }

        // A session shorter than the first delay used to receive nothing at all:
        // the first check-in was placed at ninety minutes, the loop asked whether
        // that was still inside the window, and for an hour-long session it was
        // not. Somebody who set a short timer got silence from a feature whose
        // whole job is to check on them.
        //
        // This only ever adds, and only when the normal cadence produced nothing,
        // so no session is checked on less often than before.
        if dates.isEmpty {
            let offset = max(shortSessionFloor, window / 2)
            if offset < window {
                dates.append(begin.addingTimeInterval(offset))
            }
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

/// The four soft check-ins across Friday and Saturday night, and what saying
/// "I'm home safe" does to them.
///
/// They used to be four repeating calendar triggers, cleared when somebody said
/// they were home and then scheduled again, unchanged, the next time the app came
/// to the front. Home at two and opening the phone to check a message meant the
/// four o'clock check-in came anyway. Clearing them also removed every future
/// weekend's, until the app happened to be opened again.
///
/// This decides, for each slot, whether its next occurrence should still fire.
public enum WeekendCheckInSchedule {

    public struct Slot: Equatable, Sendable {
        public let weekday: Int
        public let hour: Int
        public let minute: Int

        public var components: DateComponents {
            DateComponents(hour: hour, minute: minute, weekday: weekday)
        }
    }

    /// Calendar weekdays: Sunday is 1, Saturday is 7. Saturday's early hours are
    /// Friday night, Sunday's are Saturday night. Two each.
    public static let slots: [Slot] = [
        Slot(weekday: 7, hour: 1, minute: 30), Slot(weekday: 7, hour: 4, minute: 0),
        Slot(weekday: 1, hour: 1, minute: 30), Slot(weekday: 1, hour: 4, minute: 0)
    ]

    /// How long "I'm home safe" quiets the check-ins for. Long enough to cover the
    /// rest of the night it was said in, short enough never to reach the next one.
    public static let quietAfterHomeSafe: TimeInterval = 12 * 60 * 60

    public enum Trigger: Equatable, Sendable {
        /// Every week at this slot, starting with its next occurrence.
        case repeating(Slot)
        /// Once, at this moment: the slot's occurrence after the one that was
        /// quieted. The next time the app runs it becomes repeating again.
        case once(Date)
    }

    /// One trigger per slot, in the order of `slots`.
    public static func triggers(now: Date, lastHomeSafe: Date?, calendar: Calendar) -> [Trigger] {
        slots.map { slot in
            guard let lastHomeSafe,
                  let next = calendar.nextDate(after: now, matching: slot.components, matchingPolicy: .nextTime),
                  next >= lastHomeSafe,
                  next.timeIntervalSince(lastHomeSafe) <= quietAfterHomeSafe,
                  let following = calendar.nextDate(after: next, matching: slot.components, matchingPolicy: .nextTime)
            else {
                return .repeating(slot)
            }
            return .once(following)
        }
    }
}
