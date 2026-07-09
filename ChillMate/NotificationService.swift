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
        static let getHelp = "CHILLMATE_GET_HELP"
        static let imSafe = "CHILLMATE_IM_SAFE"
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
        // Respect an explicitly-set hour (including midnight, 0). Only fall back to
        // 10:00 when the user has never chosen a time.
        guard UserDefaults.standard.object(forKey: "checkInHour") != nil else { return 10 }
        return UserDefaults.standard.integer(forKey: "checkInHour")
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
        categoryIdentifier: String? = nil,
        interruptionLevel: UNNotificationInterruptionLevel = .passive
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
        content.interruptionLevel = interruptionLevel
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
        let getHelpAction = UNNotificationAction(
            identifier: ActionIdentifier.getHelp,
            title: String(localized: "Get help"),
            options: [.foreground]
        )
        let imSafeAction = UNNotificationAction(
            identifier: ActionIdentifier.imSafe,
            title: String(localized: "I'm safe"),
            options: []
        )
        let safetyCheckInCategory = UNNotificationCategory(
            identifier: "SAFETY_CHECKIN",
            actions: [imSafeAction, getHelpAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([checkInCategory, riskCategory, safetyCheckInCategory])
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
        scheduleDailyAffirmations(using: Self.affirmationMessagePool)
    }

    /// Reschedules the weekly affirmations, first trying to generate fresh ones
    /// entirely on-device with Apple's FoundationModels. Falls back to the
    /// curated static pool whenever the model is unavailable (older device,
    /// Apple Intelligence off, Simulator) or returns too few usable lines.
    func scheduleDailyAffirmationsUsingOnDeviceModel(languageCode: String) async {
        var pool = await OnDeviceAffirmationService.generateAffirmations(count: 7, languageCode: languageCode) ?? []
        if pool.count < 3 {
            // Not enough trustworthy on-device output: use the curated pool.
            pool = Self.affirmationMessagePool
        } else if pool.count < 7 {
            // Top up so all seven slots have distinct-enough text.
            pool += Self.affirmationMessagePool
        }
        scheduleDailyAffirmations(using: pool)
    }

    private func scheduleDailyAffirmations(using pool: [String]) {
        clearDailyAffirmations()
        guard !pool.isEmpty else { return }
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
        String(localized: "Your body remembers every kind decision you make, even the ones you forget."),
        String(localized: "Small steps still count as steps."),
        String(localized: "You showed up for yourself today, and that matters."),
        String(localized: "One calm breath can change the next few minutes."),
        String(localized: "Your pace is allowed to be your own."),
        String(localized: "Progress is not always loud. Quiet days count too."),
        String(localized: "You are allowed to rest without earning it first."),
        String(localized: "Choosing water right now is a kind thing to do for yourself."),
        String(localized: "You don't have to explain your boundaries to anyone."),
        String(localized: "A gentle no is still a complete sentence."),
        String(localized: "Tomorrow-you will be glad you paused tonight."),
        String(localized: "You are more than your hardest day."),
        String(localized: "Taking care of yourself in private is still real care."),
        String(localized: "You can start over at any hour, not just in the morning."),
        String(localized: "The fact that you opened this app means part of you is hoping."),
        String(localized: "Feeling tired is information, not a failure."),
        String(localized: "You are allowed to change your mind about tonight."),
        String(localized: "Slowing down is a skill, and you are practicing it."),
        String(localized: "Your worth does not drop when a streak does."),
        String(localized: "One kind choice tends to make the next one easier."),
        String(localized: "You can be gentle with yourself and still take this seriously."),
        String(localized: "Rest now so the next decision comes from a clearer place."),
        String(localized: "You are learning your own patterns, and that is power."),
        String(localized: "Asking for help is a strong move, not a weak one."),
        String(localized: "A quiet night is allowed to just be a quiet night."),
        String(localized: "You do not have to carry today alone."),
        String(localized: "Drinking water and eating something counts as looking after yourself."),
        String(localized: "Your body is doing its best to keep up with you. Help it where you can."),
        String(localized: "You can hold pride and regret at the same time. Both are honest."),
        String(localized: "The version of you that rests is still the real you."),
        String(localized: "Checking the time before deciding is a quietly powerful habit."),
        String(localized: "You are allowed to leave early."),
        String(localized: "Comfort is not the same as safety. You get to choose safety."),
        String(localized: "One steadier night can shift a whole week."),
        String(localized: "You don't owe anyone an explanation for protecting yourself."),
        String(localized: "Noticing you need a break is already taking the break seriously."),
        String(localized: "Your future self is shaped by small choices like this one."),
        String(localized: "It is okay if today was only about getting through it."),
        String(localized: "You can be proud of a boundary you almost didn't hold."),
        String(localized: "Some progress only you will ever see, and that is enough."),
        String(localized: "You are allowed to want both connection and safety."),
        String(localized: "A pause is not a step back. It is part of moving well."),
        String(localized: "Your honesty with yourself is worth more than a perfect record."),
        String(localized: "Eating something gentle is a small act of self-respect."),
        String(localized: "You can be kind to the version of you that struggled last night."),
        String(localized: "There is no deadline on feeling better."),
        String(localized: "You are allowed to take up space and ask for what you need."),
        String(localized: "The calm you build now stays with you later."),
        String(localized: "Choosing rest over one more hour is a real choice."),
        String(localized: "You don't have to be okay to be worth caring for."),
        String(localized: "Each clear-headed morning is something you gave yourself."),
        String(localized: "You can set a boundary and still care about someone."),
        String(localized: "Letting the urge pass is a skill you are building."),
        String(localized: "Your body keeps the receipts of every kind choice."),
        String(localized: "A softer inner voice makes hard days a little lighter."),
        String(localized: "You are allowed to protect your sleep like it matters, because it does."),
        String(localized: "Coming back after a rough stretch takes real courage."),
        String(localized: "You can choose differently next time without hating this time."),
        String(localized: "Your limits are not a problem to fix. They are information to respect."),
        String(localized: "Today's small care is tomorrow's steadier ground."),
        String(localized: "You are not behind. You are on your own timeline."),
        String(localized: "One honest check-in is worth more than a perfect plan."),
        String(localized: "You can be tired and still be doing well."),
        String(localized: "Taking it slow tonight is a gift to the morning."),
        String(localized: "You deserve the same patience you would give a friend."),
        String(localized: "A clear day is not boring. It is yours to feel fully."),
        String(localized: "You can stop at enough, even when more is offered."),
        String(localized: "Protecting your peace is allowed, even when it disappoints someone."),
        String(localized: "The quiet choices add up to a life you can live with."),
        String(localized: "You are allowed to feel proud of staying in tonight."),
        String(localized: "Whatever today held, you are still here, and that counts."),
        String(localized: "You can love your community and still need a night off from it."),
        String(localized: "Hydration is not boring. It is how tomorrow feels survivable."),
        String(localized: "Choosing to log honestly is choosing to know yourself."),
        String(localized: "The pause button is always available to you."),
        String(localized: "You are allowed to want a softer kind of fun."),
        String(localized: "Resting your body is not the same as falling behind."),
        String(localized: "You can be the friend who leaves early and still be a good friend."),
        String(localized: "Naming what you feel takes the edge off carrying it."),
        String(localized: "A glass of water is a small promise you keep to yourself."),
        String(localized: "You can be gentle about a night that did not go to plan."),
        String(localized: "Slowing the night down is rarely something you regret in the morning."),
        String(localized: "Your calm is worth protecting, even in a loud room."),
        String(localized: "You are allowed to check in with yourself without a reason."),
        String(localized: "Tonight does not have to look like last weekend."),
        String(localized: "One honest sentence to a friend can lighten a heavy night."),
        String(localized: "You can hold space for joy and still keep yourself safe."),
        String(localized: "The kindest thing might be an early night."),
        String(localized: "You are allowed to outgrow what used to feel normal."),
        String(localized: "Eating before, not just after, is a quiet form of care."),
        String(localized: "You can choose people who make leaving easy."),
        String(localized: "Your body will thank you for the water you drink tonight."),
        String(localized: "A boundary you keep tonight teaches you that you can."),
        String(localized: "Feeling unsure is a fine reason to wait."),
        String(localized: "You are not too much for asking for what keeps you safe."),
        String(localized: "Recovery is less a straight line and more a series of returns."),
        String(localized: "You can be proud of the help you reached for."),
        String(localized: "Cooling down and catching your breath is doing something."),
        String(localized: "The morning is easier when you are kind to tonight."),
        String(localized: "You are allowed to keep some of your life just for you."),
        String(localized: "A check-in is not a test you can fail."),
        String(localized: "You can want closeness and still keep your limits."),
        String(localized: "Rest is productive in its own quiet way."),
        String(localized: "You are allowed to be a work in progress."),
        String(localized: "Pacing yourself is a sign of self-trust, not fear."),
        String(localized: "You can put your phone down and let the urge get bored."),
        String(localized: "Every time you choose water over more, your body notices."),
        String(localized: "You are allowed to feel good about an ordinary night."),
        String(localized: "A plan you can actually follow beats a perfect one you cannot."),
        String(localized: "You can be honest in your logs without being harsh with yourself."),
        String(localized: "Leaving room to stop early is a kind of wisdom."),
        String(localized: "You are allowed to need more sleep than you used to."),
        String(localized: "A steadier you is being built in moments like this."),
        String(localized: "You can care about tomorrow and still enjoy tonight."),
        String(localized: "Checking on a friend is also a way of checking on yourself."),
        String(localized: "Your nervous system likes slow, steady, and safe."),
        String(localized: "You are allowed to say this is enough for me tonight."),
        String(localized: "The fact that you are pausing means you are listening to yourself."),
        String(localized: "A calm body makes clearer choices."),
        String(localized: "You can be tender with the parts of you that are still healing."),
        String(localized: "Drinking water now is a vote for an easier morning."),
        String(localized: "You are allowed to protect your weekend self from your Friday-night self."),
        String(localized: "One steady breath is a place to start again."),
        String(localized: "Coming home safe is the whole goal tonight."),
        String(localized: "You can be both careful and free."),
        String(localized: "The smallest act of self-care still counts as care."),
        String(localized: "You are allowed to be the calm one tonight."),
        String(localized: "Letting yourself rest is letting yourself recover."),
        String(localized: "You can change the story for tonight at any point."),
        String(localized: "A boundary is a gift you give your future self."),
        String(localized: "You are allowed to feel proud without anyone clapping."),
        String(localized: "Checking the time, the dose plan, and the way home is just good care."),
        String(localized: "You can be soft with yourself and still be strong."),
        String(localized: "Your worth is not measured by how the night goes."),
        String(localized: "Taking a breather is not quitting."),
        String(localized: "You are allowed to want to remember your night clearly."),
        String(localized: "A clear head tomorrow is something you can choose tonight."),
        String(localized: "You can ask someone to stay close without explaining everything."),
        String(localized: "Rest is part of the plan, not a break from it."),
        String(localized: "You are allowed to be proud of one good decision."),
        String(localized: "Whatever you can manage today is allowed to be enough."),
        String(localized: "You are allowed to take the night at half speed."),
        String(localized: "Being honest about a hard night is its own kind of strength."),
        String(localized: "You can be proud of the line you did not cross."),
        String(localized: "Your body has carried you this far. Treat it like an ally."),
        String(localized: "Slowing down does not mean you are missing the moment."),
        String(localized: "You are allowed to want safety more than approval."),
        String(localized: "A short rest can save a long recovery."),
        String(localized: "You can leave a situation that stops feeling right."),
        String(localized: "The most caring choice is sometimes the quiet one."),
        String(localized: "You are allowed to put yourself first tonight."),
        String(localized: "One glass of water, one deep breath, one honest moment. Start there."),
        String(localized: "Your limits make your yes mean something."),
        String(localized: "You can be gentle with a craving without obeying it."),
        String(localized: "Coming back to yourself is always possible."),
        String(localized: "You are allowed to feel proud of a calm night."),
        String(localized: "Tending to your sleep is tending to your whole self."),
        String(localized: "You can let tonight be smaller than you planned."),
        String(localized: "A pause gives your future self a chance to weigh in."),
        String(localized: "You are not weak for needing rest. You are human."),
        String(localized: "Your steadiness is built from nights exactly like this."),
        String(localized: "You can choose comfort that does not cost you tomorrow."),
        String(localized: "Checking in is a way of staying on your own side."),
        String(localized: "You are allowed to keep something good going by stopping in time."),
        String(localized: "A clear morning is a gift you can still choose to give yourself."),
        String(localized: "You can be kind to yourself and accountable at once."),
        String(localized: "Your needs are not too much to take seriously."),
        String(localized: "The brave thing tonight might be the boring thing."),
        String(localized: "You are allowed to rest before you are completely out of energy."),
        String(localized: "One safer choice makes room for the next one."),
        String(localized: "You can hold your boundaries gently and firmly."),
        String(localized: "Slowing your breathing tells your body it is safe."),
        String(localized: "You are allowed to want less tonight than last time."),
        String(localized: "A night you remember is a night that stays yours."),
        String(localized: "You can ask for water, a seat, or a quiet corner. All allowed."),
        String(localized: "Your recovery is not cancelled by one hard day."),
        String(localized: "You are allowed to be proud of getting home safe."),
        String(localized: "The smallest pause can interrupt the biggest momentum."),
        String(localized: "You can be tired of pushing and still be doing fine."),
        String(localized: "Your future self is listening to the choice you make now."),
        String(localized: "You are allowed to choose the version of tonight that you can rest after."),
        String(localized: "Caring for your body is never a waste of a night."),
        String(localized: "You can be soft and still keep your word to yourself."),
        String(localized: "A calm exit is a skill worth being proud of."),
        String(localized: "You are allowed to feel relief when you choose to stop."),
        String(localized: "One steady decision can quiet a noisy night."),
        String(localized: "Your worth was never on the line tonight."),
        String(localized: "You can come back to the plan even after stepping away from it."),
        String(localized: "Being gentle with yourself is part of taking this seriously."),
        String(localized: "You are allowed to want both rest and connection, in that order tonight."),
        String(localized: "A check-in now can save a harder conversation later."),
        String(localized: "Your body keeps going because of small kindnesses like water and rest."),
        String(localized: "You can be proud of choosing the quieter path."),
        String(localized: "The way you treat yourself tonight echoes into tomorrow."),
        String(localized: "You are allowed to stop reading the room and listen to yourself."),
        String(localized: "A slower night still counts as a night well spent."),
        String(localized: "You can let go of how tonight was supposed to look."),
        String(localized: "Your honesty here is building trust with yourself."),
        String(localized: "You are allowed to take care of yourself without a crisis."),
        String(localized: "One good breath is enough to begin again."),
        String(localized: "You can be the person who looks out for you."),
        String(localized: "A boundary held gently is still a boundary held."),
        String(localized: "You are allowed to feel okay about an early goodnight."),
        String(localized: "Your steadiness today makes tomorrow lighter."),
        String(localized: "You can pause without explaining the pause."),
        String(localized: "Choosing rest is choosing yourself."),
        String(localized: "You are allowed to let this be a soft landing."),
        String(localized: "Small honest choices are quietly changing your story."),
        String(localized: "You can be proud of every clear-headed hour."),
        String(localized: "Your care for yourself counts even when no one sees it."),
        String(localized: "However tonight goes, you are allowed to be gentle with yourself tomorrow."),
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
            (firstDoseDate.addingTimeInterval(48 * 60 * 60), "PrEP follow-up", "Use your prescribed PrEP plan. Contact a clinician or sexual-health service if you are unsure.")
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

        // Opt-in "safety check-ins": more assertive (active vs passive) and carrying
        // a one-tap "Get help" action that routes to the trusted contact / emergency.
        let safetyMode = UserDefaults.standard.bool(forKey: "safetyCheckInsEnabled")
        let category = safetyMode ? "SAFETY_CHECKIN" : "CHECKIN"
        let level: UNNotificationInterruptionLevel = safetyMode ? .active : .passive

        let firstDate = max(Date.now, startDate).addingTimeInterval(90 * 60)
        guard firstDate < endDate else {
            return
        }

        var date = firstDate
        var index = 0
        let maxCheckIns = 48

        while date < endDate, index < maxCheckIns {
            let content = notificationContent(
                title: safetyMode ? String(localized: "Safety check-in") : String(localized: "Gentle safety check"),
                body: checkInMessages[index % checkInMessages.count],
                discreetBody: String(localized: "A private safety check is available."),
                destination: destination,
                categoryIdentifier: category,
                interruptionLevel: level
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

        // Escalation: an explicit, more assertive prompt at the planned session end
        // that routes straight to help if the person hasn't checked in.
        if safetyMode, index < maxCheckIns {
            let endContent = notificationContent(
                title: String(localized: "Are you okay?"),
                body: String(localized: "Your session timer has ended. Tap Get help to reach your trusted contact or emergency services, or I'm safe to dismiss."),
                discreetBody: String(localized: "A private safety check is available."),
                destination: .emergency,
                categoryIdentifier: "SAFETY_CHECKIN",
                interruptionLevel: .active
            )
            let endRequest = UNNotificationRequest(
                identifier: sessionCheckInIdentifier(id: id, index: index),
                content: endContent,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval(for: endDate), repeats: false)
            )
            center.add(endRequest)
        }
    }

    func clearSessionCheckIns(id: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: (0..<48).map { sessionCheckInIdentifier(id: id, index: $0) }
        )
    }

    /// The redose window opens at 40% of the effect duration. Schedule a local
    /// notification at that moment so the "pause before more" nudge fires in the
    /// background too (the Live Activity flag can't flip without a push token).
    func scheduleRedoseNudge(id: UUID, startsAt: Date, durationHours: Double) {
        let identifier = redoseNudgeIdentifier(id: id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let fireDate = startsAt.addingTimeInterval(durationHours * 3600 * 0.40)
        guard fireDate > .now else { return }

        let content = notificationContent(
            title: String(localized: "Pause before redosing"),
            body: String(localized: "You are partway through the effect window. If more is on your mind, pause first: are you safe, hydrated, and still choosing what protects tomorrow?"),
            discreetBody: String(localized: "A private timing check is available."),
            destination: .timers,
            categoryIdentifier: "CHECKIN"
        )

        center.add(UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval(for: fireDate), repeats: false)
        ))
    }

    func clearRedoseNudge(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [redoseNudgeIdentifier(id: id)])
    }

    private func redoseNudgeIdentifier(id: UUID) -> String {
        "chillmate.redose.\(id.uuidString)"
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
            return "ChillMate has logged \(count) high-risk Chills in 3 weeks. Your body and mind carry a real load from that. A counselor, sexual-health service, or GP can help, without judgment."
        default:
            return "You have logged \(count) Chills involving sex and substances in the last 3 weeks. That level of frequency carries health risks. A GP, sexual-health service, or counselor can support you."
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
    case combinationRisk
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
