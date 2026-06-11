import Foundation
import UserNotifications

enum NotificationTone: String, CaseIterable, Identifiable {
    case gentle = "Gentle"
    case direct = "Direct"
    case minimal = "Minimal"
    case playful = "Playful"

    var id: String { rawValue }

    var caption: String {
        switch self {
        case .gentle:
            String(localized: "Soft and supportive")
        case .direct:
            String(localized: "Clear and practical")
        case .minimal:
            String(localized: "Short and discreet")
        case .playful:
            String(localized: "Light, but still serious")
        }
    }
}

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    enum ActionIdentifier {
        static let logNow = "CHILLMATE_LOG_NOW"
        static let snooze = "CHILLMATE_SNOOZE"
    }

    private let center = UNUserNotificationCenter.current()
    private let checkInIdentifier = "chillmate.checkin"
    private let riskWarningIdentifier = "chillmate.risk.health"
    private let inactivityDays = [7, 14, 21]
    private let affirmationIdentifiers = (1...7).map { "chillmate.affirmation.\($0)" }
    private let checkInMessages = [
        String(localized: "Pause for a second. How's your body doing right now?"),
        String(localized: "Water. Food. Air. Which one do you need?"),
        String(localized: "You don't have to be doing great. How are you actually feeling?"),
        String(localized: "Check in with yourself. Are the people around you still feeling safe to you?"),
        String(localized: "This is just a quiet check. You can close this and everything stays private."),
        String(localized: "If you need to step outside, that is always okay."),
        String(localized: "Would hearing a familiar voice help? You can call someone without explaining why."),
        String(localized: "How is your breathing? Try taking one slow breath before anything else."),
        String(localized: "No rush. Take a moment, then take the next small step."),
        String(localized: "If there is chest pain, blue lips, seizure, or someone cannot be woken: call emergency services now."),
        String(localized: "Your boundaries are still yours right now. Nothing has changed that."),
        String(localized: "Check your temperature. Are you warm enough? Too warm? Drink something.")
    ]

    private var pendingSnoozeID: String?

    private init() {}

    private var discreetNotificationsEnabled: Bool {
        if UserDefaults.standard.object(forKey: "discreetNotifications") == nil {
            return false
        }
        return UserDefaults.standard.bool(forKey: "discreetNotifications")
    }

    private var notificationTone: NotificationTone {
        if let value = UserDefaults.standard.string(forKey: "notificationTone"),
           let tone = NotificationTone(rawValue: value) {
            return tone
        }
        return .gentle
    }

    var checkInHour: Int {
        let stored = UserDefaults.standard.integer(forKey: "checkInHour")
        return stored == 0 ? 10 : stored
    }

    var checkInMinute: Int {
        UserDefaults.standard.integer(forKey: "checkInMinute")
    }

    private func tonedBody(_ body: String, discreetBody: String) -> String {
        switch notificationTone {
        case .gentle:
            body
        case .direct:
            body.replacingOccurrences(of: "when you are ready", with: "now if you can")
        case .minimal:
            discreetBody
        case .playful:
            "\(body) Small check, future-you says thanks."
        }
    }

    private func notificationContent(
        title: String,
        body: String,
        discreetTitle: String = "ChillMate",
        discreetBody: String = "Private check-in. Open ChillMate for details.",
        destination: NotificationDestination? = nil,
        categoryIdentifier: String? = nil
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = discreetNotificationsEnabled ? discreetTitle : title
        content.body = discreetNotificationsEnabled ? discreetBody : tonedBody(body, discreetBody: discreetBody)
        content.sound = .default
        if let destination {
            content.userInfo = ["destination": destination.rawValue]
        }
        if let categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }
        content.interruptionLevel = .passive
        return content
    }

    func registerCategories() {
        let logAction = UNNotificationAction(
            identifier: ActionIdentifier.logNow,
            title: String(localized: "Log now"),
            options: [.foreground]
        )
        let snoozeAction = UNNotificationAction(
            identifier: ActionIdentifier.snooze,
            title: String(localized: "Snooze 1 hour"),
            options: []
        )
        let checkInCategory = UNNotificationCategory(
            identifier: "CHECKIN",
            actions: [logAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        let riskCategory = UNNotificationCategory(
            identifier: "RISK",
            actions: [logAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([checkInCategory, riskCategory])
    }

    func snoozeCurrentCheckIn() {
        let content = notificationContent(
            title: String(localized: "Private check-in"),
            body: String(localized: "Add sleep, reflection notes, or a skipped Chill when you are ready."),
            discreetBody: String(localized: "Private check-in available."),
            destination: .home,
            categoryIdentifier: "CHECKIN"
        )
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60, repeats: false)
        let id = "chillmate.checkin.snooze.\(Int(Date.now.timeIntervalSince1970))"
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleCheckInReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [checkInIdentifier])

        let content = notificationContent(
            title: String(localized: "Private check-in"),
            body: String(localized: "Add sleep, reflection notes, or a skipped Chill when you are ready."),
            discreetBody: String(localized: "Private check-in available."),
            destination: .home,
            categoryIdentifier: "CHECKIN"
        )

        var components = DateComponents()
        components.hour = checkInHour
        components.minute = checkInMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: checkInIdentifier, content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleInactivityReminders(from lastUse: Date = .now) {
        clearInactivityReminders()

        for day in inactivityDays {
            guard let reminderDate = Calendar.current.date(byAdding: .day, value: day, to: lastUse) else {
                continue
            }

            let content = notificationContent(
                title: String(localized: "Maybe add a private log?"),
                body: String(localized: "If there was a Chill, skipped Chill, sleep, or aftercare moment, you can add it when you feel ready."),
                discreetBody: String(localized: "Private reminder available."),
                destination: .home,
                categoryIdentifier: "CHECKIN"
            )

            let request = UNNotificationRequest(
                identifier: inactivityIdentifier(day: day),
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval(for: reminderDate), repeats: false)
            )
            center.add(request)
        }
    }

    func clearInactivityReminders() {
        center.removePendingNotificationRequests(withIdentifiers: inactivityDays.map { inactivityIdentifier(day: $0) })
    }

    func scheduleDailyAffirmations() {
        clearDailyAffirmations()
        let pool = Self.affirmationMessagePool
        let jitterMinutes = [3, -7, 11, -4, 8, -12, 5]
        let stride = max(1, pool.count / 7)

        for index in 0..<7 {
            let messageIndex = (index * stride) % pool.count
            let message = pool[messageIndex]

            let content = notificationContent(
                title: Self.affirmationTitles[index % Self.affirmationTitles.count],
                body: message,
                discreetBody: String(localized: "A private note is waiting for you."),
                destination: .home
            )

            var components = DateComponents()
            components.weekday = index + 1
            components.hour = 11
            components.minute = 15 + jitterMinutes[index]

            let request = UNNotificationRequest(
                identifier: affirmationIdentifiers[index],
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            center.add(request)
        }
    }

    private static var affirmationTitles: [String] { [
        String(localized: "A quiet note from ChillMate"),
        String(localized: "Just checking in"),
        String(localized: "One thing worth noticing today"),
        String(localized: "Something small that counts"),
        String(localized: "A moment for yourself"),
        String(localized: "Today's reminder"),
        String(localized: "You're doing better than you think")
    ] }

    private static var affirmationMessagePool: [String] { [
        String(localized: "Every choice that protects your body is worth something, even the small ones."),
        String(localized: "A day without logged use is still a day that moved you forward."),
        String(localized: "You don't have to have it all figured out. Steady is enough."),
        String(localized: "Rest is not the same as giving up. It is part of how you recover."),
        String(localized: "Skipping a session is not missing out. It is choosing future you."),
        String(localized: "You can be proud of choices that no one else will ever see."),
        String(localized: "Your recovery streak is built one decision at a time, not all at once."),
        String(localized: "Checking in with yourself takes courage. You are doing that."),
        String(localized: "Nothing about today has to be perfect. Just real is already a lot."),
        String(localized: "The things you protect about yourself quietly. They matter."),
        String(localized: "Noticing patterns is harder than ignoring them. You are doing the harder thing."),
        String(localized: "There is no version of care that is too small to count."),
        String(localized: "You are allowed to move slowly. Slow is still moving."),
        String(localized: "The fact that you are thinking about your health at all. That is not nothing."),
        String(localized: "One honest log, one water refill, one text to someone you trust. That is a full day."),
        String(localized: "Recovery does not need an audience. Private progress still counts."),
        String(localized: "Being kind to your body is not always comfortable. You are doing it anyway."),
        String(localized: "Today you made it to this notification. Something in you is still paying attention."),
        String(localized: "It is okay to have complicated feelings about where you are right now."),
        String(localized: "What you are building with these logs is a kind of self-respect."),
        String(localized: "You have gotten through harder days than this one."),
        String(localized: "The streak is yours. No one can see it but you, and it is real."),
        String(localized: "You are not just tracking habits. You are learning what you need."),
        String(localized: "Substances change the picture. A clear day gives you back the full view."),
        String(localized: "Sometimes the healthiest thing is just not making it worse today."),
        String(localized: "You are worth checking in on, even when nothing is urgent."),
        String(localized: "There is no perfect way to do this. There is only what you actually do."),
        String(localized: "Your body remembers every kind decision you make, even the ones you forget.")
    ] }

    func clearDailyAffirmations() {
        center.removePendingNotificationRequests(withIdentifiers: affirmationIdentifiers)
    }

    func scheduleRiskWarning(count: Int) {
        let body = Self.riskWarningBody(count: count)
        let content = notificationContent(
            title: Self.riskWarningTitle(count: count),
            body: body,
            discreetBody: String(localized: "A private health check-in is available."),
            destination: .home,
            categoryIdentifier: "RISK"
        )

        center.removePendingNotificationRequests(withIdentifiers: [riskWarningIdentifier])
        let request = UNNotificationRequest(
            identifier: riskWarningIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        center.add(request)
    }

    func scheduleSTDResultReminder(testID: UUID, dueDate: Date) {
        let content = notificationContent(
            title: String(localized: "STI results check"),
            body: String(localized: "If your results are in, add oral, genital, and anal results to ChillMate."),
            discreetBody: String(localized: "A private results reminder is available."),
            destination: .home
        )

        let request = UNNotificationRequest(
            identifier: "chillmate.std.\(testID.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval(for: dueDate), repeats: false)
        )
        center.add(request)
    }

    func scheduleAftercareReminder(entryID: UUID, after date: Date) {
        let content = notificationContent(
            title: String(localized: "Gentle aftercare check-in"),
            body: String(localized: "How did you sleep, and how do you feel about last Chill?"),
            discreetBody: String(localized: "A private aftercare check-in is available."),
            destination: .home,
            categoryIdentifier: "CHECKIN"
        )

        let request = UNNotificationRequest(
            identifier: "chillmate.aftercare.\(entryID.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval(for: date), repeats: false)
        )
        center.add(request)
    }

    func scheduleWeeklySummary(streak: Int, score: Int) {
        clearWeeklySummary()
        let scoreText = score > 0 ? String(localized: ", score \(score)") : ""
        let streakText = streak == 1 ? String(localized: "1 day") : String(localized: "\(streak) days")
        let content = notificationContent(
            title: String(localized: "Your week in ChillMate"),
            body: String(localized: "You're at \(streakText) without logged substance use\(scoreText). Check in when ready."),
            discreetBody: String(localized: "Your private weekly summary is available."),
            destination: .home
        )
        var components = DateComponents()
        components.weekday = 1
        components.hour = 19
        components.minute = 0
        let request = UNNotificationRequest(
            identifier: "chillmate.weekly.digest",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        center.add(request)
    }

    func clearWeeklySummary() {
        center.removePendingNotificationRequests(withIdentifiers: ["chillmate.weekly.digest"])
    }

    func schedule48hFollowUp(entryID: UUID, sessionDate: Date) {
        let followUpDate = sessionDate.addingTimeInterval(48 * 60 * 60)
        guard followUpDate > .now else { return }
        let content = notificationContent(
            title: String(localized: "48-hour check-in"),
            body: String(localized: "It's been two days since your last Chill. How are you really feeling: sleep, mood, energy?"),
            discreetBody: String(localized: "A private follow-up is available."),
            destination: .home,
            categoryIdentifier: "CHECKIN"
        )
        let request = UNNotificationRequest(
            identifier: "chillmate.followup48h.\(entryID.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval(for: followUpDate), repeats: false)
        )
        center.add(request)
    }

    func scheduleSTIReminder(dueDate: Date) {
        clearSTIReminder()
        guard dueDate > .now else { return }
        let content = notificationContent(
            title: String(localized: "STI test reminder"),
            body: String(localized: "Based on your test schedule, it may be time for a check-up. Regular STI testing is part of staying healthy."),
            discreetBody: String(localized: "A private health reminder is available."),
            destination: .home
        )
        let request = UNNotificationRequest(
            identifier: "chillmate.sti.periodic",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval(for: dueDate), repeats: false)
        )
        center.add(request)
    }

    func clearSTIReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["chillmate.sti.periodic"])
    }

    func schedulePositiveSleepNotification(hours: Double) {
        let content = notificationContent(
            title: String(localized: "Good recovery sleep"),
            body: "Apple Health shows \(hours.formatted(.number.precision(.fractionLength(0...1)))) hours of sleep. That is a strong recovery signal.",
            discreetBody: String(localized: "A private recovery update is available."),
            destination: .home
        )

        let id = "chillmate.sleep.positive"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        center.add(request)
    }

    func scheduleSaferPlanReminders(planID: UUID, endingAt endingDate: Date) {
        let reminders: [(TimeInterval, String)] = [
            (60 * 60, "1 hour"),
            (30 * 60, "30 minutes"),
            (10 * 60, "10 minutes")
        ]

        let identifiers = reminders.map { "chillmate.safeplan.\(planID.uuidString).\($0.1)" }
            + ["chillmate.safeplan.\(planID.uuidString).ended"]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        for (offset, label) in reminders {
            let reminderDate = endingDate.addingTimeInterval(-offset)
            guard reminderDate > .now else {
                continue
            }

            let content = notificationContent(
                title: String(localized: "Plan ending soon"),
                body: "Your safer session plan ends in \(label). Check water, transport, and your limits now.",
                discreetBody: String(localized: "Your private plan has a timing reminder."),
                destination: .saferPlan,
                categoryIdentifier: "CHECKIN"
            )

            let request = UNNotificationRequest(
                identifier: "chillmate.safeplan.\(planID.uuidString).\(label)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval(for: reminderDate), repeats: false)
            )
            center.add(request)
        }

        schedulePostPlanRedoseCheck(planID: planID, date: endingDate)
    }

    func schedulePrepReminders(planID: UUID, plannedSexAt plannedDate: Date) {
        let firstDoseDate = plannedDate.addingTimeInterval(-2 * 60 * 60)
        let reminders: [(Date, String, String)] = [
            (firstDoseDate, "PrEP reminder", "If around-sex PrEP is prescribed for you, follow the schedule your clinician gave you."),
            (firstDoseDate.addingTimeInterval(24 * 60 * 60), "PrEP follow-up", "Follow your prescribed PrEP follow-up instructions at the planned time."),
            (firstDoseDate.addingTimeInterval(48 * 60 * 60), "PrEP follow-up", "Use your prescribed PrEP plan. Contact a clinician or GGD if you are unsure.")
        ]

        let identifiers = reminders.indices.map { "chillmate.prep.\(planID.uuidString).\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        for (index, reminder) in reminders.enumerated() where reminder.0 > .now {
            let content = notificationContent(
                title: reminder.1,
                body: reminder.2,
                discreetBody: String(localized: "A private medication reminder is available."),
                destination: .saferPlan
            )

            let request = UNNotificationRequest(
                identifier: "chillmate.prep.\(planID.uuidString).\(index)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval(for: reminder.0), repeats: false)
            )
            center.add(request)
        }
    }

    func scheduleSessionCheckIns(id: UUID, startsAt startDate: Date, endsAt endDate: Date, destination: NotificationDestination) {
        clearSessionCheckIns(id: id)

        let firstDate = max(Date.now, startDate).addingTimeInterval(90 * 60)
        guard firstDate < endDate else {
            return
        }

        var date = firstDate
        var index = 0
        let maxCheckIns = 48

        while date < endDate, index < maxCheckIns {
            let content = notificationContent(
                title: String(localized: "Gentle safety check"),
                body: checkInMessages[index % checkInMessages.count],
                discreetBody: String(localized: "A private safety check is available."),
                destination: destination,
                categoryIdentifier: "CHECKIN"
            )

            let request = UNNotificationRequest(
                identifier: sessionCheckInIdentifier(id: id, index: index),
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval(for: date), repeats: false)
            )
            center.add(request)

            date = date.addingTimeInterval(90 * 60)
            index += 1
        }
    }

    func clearSessionCheckIns(id: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: (0..<48).map { sessionCheckInIdentifier(id: id, index: $0) }
        )
    }

    private func schedulePostPlanRedoseCheck(planID: UUID, date: Date) {
        let content = notificationContent(
            title: String(localized: "Pause before adding more"),
            body: String(localized: "Your planned ending time has passed. Pause first: are you safe, supported, and still choosing what protects you tomorrow?"),
            discreetBody: String(localized: "A private timing check is available."),
            destination: .timers,
            categoryIdentifier: "CHECKIN"
        )

        let request = UNNotificationRequest(
            identifier: "chillmate.safeplan.\(planID.uuidString).ended",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval(for: date), repeats: false)
        )
        center.add(request)
    }

    func schedulePEPWindowReminders(entry: NightEntry) {
        clearPEPWindowReminders()
        guard entry.pepDeadline > .now else { return }

        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now

        // Morning reminder at 9am
        let morningComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        var morning = DateComponents()
        morning.year = morningComponents.year
        morning.month = morningComponents.month
        morning.day = morningComponents.day
        morning.hour = 9
        morning.minute = 0

        // Afternoon reminder at 3pm
        var afternoon = morning
        afternoon.hour = 15

        let deadlineString = entry.pepDeadline.formatted(date: .abbreviated, time: .shortened)

        let morningContent = notificationContent(
            title: String(localized: "PEP time window is open"),
            body: "A recent log may indicate a risk. Contact a doctor or sexual health clinic today. Window closes \(deadlineString).",
            discreetTitle: String(localized: "ChillMate"),
            discreetBody: String(localized: "A private health reminder is waiting for you."),
            destination: .emergency
        )
        let morningContent2 = notificationContent(
            title: String(localized: "PEP window still open"),
            body: "You still have time to speak with a clinician before \(deadlineString). Don't wait longer than needed.",
            discreetTitle: String(localized: "ChillMate"),
            discreetBody: String(localized: "A private health follow-up is available."),
            destination: .emergency
        )

        center.add(UNNotificationRequest(
            identifier: "chillmate.pep.morning",
            content: morningContent,
            trigger: UNCalendarNotificationTrigger(dateMatching: morning, repeats: false)
        ))
        center.add(UNNotificationRequest(
            identifier: "chillmate.pep.afternoon",
            content: morningContent2,
            trigger: UNCalendarNotificationTrigger(dateMatching: afternoon, repeats: false)
        ))
    }

    func clearPEPWindowReminders() {
        center.removePendingNotificationRequests(withIdentifiers: ["chillmate.pep.morning", "chillmate.pep.afternoon"])
    }

    func clearScheduledNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    private func inactivityIdentifier(day: Int) -> String {
        "chillmate.inactivity.\(day)"
    }

    private func sessionCheckInIdentifier(id: UUID, index: Int) -> String {
        "chillmate.sessionCheckIn.\(id.uuidString).\(index)"
    }

    private func triggerInterval(for date: Date) -> TimeInterval {
        max(60, date.timeIntervalSinceNow)
    }
}

private extension NotificationService {
    static func riskWarningTitle(count: Int) -> String {
        switch count {
        case 4...6: return "Worth a quick check-in"
        case 7...9: return "A pattern worth noticing"
        default:    return "Health check-in"
        }
    }

    static func riskWarningBody(count: Int) -> String {
        switch count {
        case 4...6:
            return "You have logged \(count) Chills with sex and substances in the last 3 weeks. That is worth a quiet conversation with your GP or a trusted person."
        case 7...9:
            return "ChillMate has logged \(count) high-risk Chills in 3 weeks. Your body and mind carry a real load from that. A counselor, GGD, or GP can help, without judgment."
        default:
            return "You have logged \(count) Chills involving sex and substances in the last 3 weeks. That level of frequency carries health risks. A GP, GGD, or counselor can support you."
        }
    }
}

enum NotificationDestination: String {
    case home
    case log
    case saferPlan
    case timers
    case emergency
    case panic
    case journal
    case safeRoute
}

enum HealthWarning {
    static func recentRiskCount(entries: [NightEntry], now: Date = .now, calendar: Calendar = .current) -> Int {
        let cutoff = calendar.date(byAdding: .day, value: -21, to: now) ?? now
        var count = 0
        for entry in entries where entry.date >= cutoff && entry.hadSex && !entry.skippedNight {
            if !entry.substances.isEmpty {
                count += 1
            }
        }
        return count
    }

    static func shouldWarn(entries: [NightEntry]) -> Bool {
        recentRiskCount(entries: entries) > 3
    }
}
