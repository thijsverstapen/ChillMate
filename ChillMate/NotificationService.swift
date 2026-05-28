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
            "Soft and supportive"
        case .direct:
            "Clear and practical"
        case .minimal:
            "Short and discreet"
        case .playful:
            "Light, but still serious"
        }
    }
}

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let checkInIdentifier = "chillmate.checkin"
    private let inactivityDays = [7, 14, 21]
    private let affirmationIdentifiers = (1...7).map { "chillmate.affirmation.\($0)" }
    private let checkInMessages = [
        "Pause for a second. Are you still feeling okay?",
        "Do you need water, food, air, or a break from the room?",
        "Do you feel safe with the people around you?",
        "Would calling someone you trust make this feel steadier?",
        "Check your body before anything else: breathing, temperature, heartbeat, and boundaries.",
        "If there is chest pain, fainting, blue lips, seizure, overheating, or someone cannot be woken: call 112 now."
    ]

    private init() {}

    private var discreetNotificationsEnabled: Bool {
        if UserDefaults.standard.object(forKey: "discreetNotifications") == nil {
            return true
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
        destination: NotificationDestination? = nil
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = discreetNotificationsEnabled ? discreetTitle : title
        content.body = discreetNotificationsEnabled ? discreetBody : tonedBody(body, discreetBody: discreetBody)
        content.sound = .default
        if let destination {
            content.userInfo = ["destination": destination.rawValue]
        }
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .passive
        }
        return content
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleCheckInReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [checkInIdentifier])

        let content = notificationContent(
            title: "Private check-in",
            body: "Add sleep, drugs, or a skipped Chill when you are ready.",
            discreetBody: "Private check-in available.",
            destination: .home
        )

        var components = DateComponents()
        components.hour = 10
        components.minute = 0

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
                title: "Maybe add a private log?",
                body: "If there was a Chill, skipped Chill, sleep, or aftercare moment, you can add it when you feel ready.",
                discreetBody: "Private reminder available.",
                destination: .home
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

        let messages = [
            "Every choice that protects your body counts.",
            "A quiet Chill-free day still moves you forward.",
            "You are allowed to rest, reset, and choose yourself.",
            "Doing well with your score is worth noticing today.",
            "Skipping substances is not missing out. It is taking care of future you.",
            "You can be proud of small steady decisions.",
            "Your recovery streak is built one kind choice at a time."
        ]

        for (index, message) in messages.enumerated() {
            let content = notificationContent(
                title: "ChillMate confidence boost",
                body: message,
                discreetBody: "A confidence boost is waiting.",
                destination: .home
            )

            var components = DateComponents()
            components.weekday = index + 1
            components.hour = 11
            components.minute = 15

            let request = UNNotificationRequest(
                identifier: affirmationIdentifiers[index],
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            center.add(request)
        }
    }

    func clearDailyAffirmations() {
        center.removePendingNotificationRequests(withIdentifiers: affirmationIdentifiers)
    }

    func scheduleRiskWarning(count: Int) {
        let content = notificationContent(
            title: "Health check-in",
            body: "You have logged \(count) Chills with sex and drug use in 3 weeks. Consider talking with a professional helper.",
            discreetBody: "A private health check-in is available.",
            destination: .home
        )

        let request = UNNotificationRequest(
            identifier: "chillmate.risk.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        center.add(request)
    }

    func scheduleSTDResultReminder(testID: UUID, dueDate: Date) {
        let content = notificationContent(
            title: "STI results check",
            body: "If your results are in, add oral, genital, and anal results to ChillMate.",
            discreetBody: "A private results reminder is available.",
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
            title: "Gentle aftercare check-in",
            body: "How did you sleep, and how do you feel about last Chill?",
            discreetBody: "A private aftercare check-in is available.",
            destination: .home
        )

        let request = UNNotificationRequest(
            identifier: "chillmate.aftercare.\(entryID.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval(for: date), repeats: false)
        )
        center.add(request)
    }

    func schedulePositiveSleepNotification(hours: Double) {
        let content = notificationContent(
            title: "Good recovery sleep",
            body: "Apple Health shows \(hours.formatted(.number.precision(.fractionLength(0...1)))) hours of sleep. That is a strong recovery signal.",
            discreetBody: "A private recovery update is available.",
            destination: .home
        )

        let request = UNNotificationRequest(
            identifier: "chillmate.sleep.positive.\(UUID().uuidString)",
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
                title: "Plan ending soon",
                body: "Your safer session plan ends in \(label). Check water, transport, and your limits now.",
                discreetBody: "Your private plan has a timing reminder.",
                destination: .saferPlan
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
            (firstDoseDate, "PrEP before sex", "If you use around-sex PrEP and it is prescribed for you, take 2 pills now so there is at least 2 hours before sex."),
            (firstDoseDate.addingTimeInterval(24 * 60 * 60), "PrEP follow-up", "Take 1 pill at the same time as the first PrEP pills yesterday."),
            (firstDoseDate.addingTimeInterval(48 * 60 * 60), "PrEP follow-up", "Take the second follow-up pill at the same time. Continue daily if sex continues over consecutive days.")
        ]

        let identifiers = reminders.indices.map { "chillmate.prep.\(planID.uuidString).\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        for (index, reminder) in reminders.enumerated() where reminder.0 > .now {
            let content = notificationContent(
                title: reminder.1,
                body: reminder.2,
                discreetBody: "A private medication reminder is available.",
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
        while date < endDate, index < 8 {
            let content = notificationContent(
                title: "Gentle safety check",
                body: checkInMessages[index % checkInMessages.count],
                discreetBody: "A private safety check is available.",
                destination: destination
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
            withIdentifiers: (0..<8).map { sessionCheckInIdentifier(id: id, index: $0) }
        )
    }

    private func schedulePostPlanRedoseCheck(planID: UUID, date: Date) {
        let content = notificationContent(
            title: "Pause before adding more",
            body: "Your planned ending time has passed. If you want to log more drugs, stop first and ask yourself clearly: is this really what you want right now?",
            discreetBody: "A private timing check is available.",
            destination: .timers
        )

        let request = UNNotificationRequest(
            identifier: "chillmate.safeplan.\(planID.uuidString).ended",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval(for: date), repeats: false)
        )
        center.add(request)
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
