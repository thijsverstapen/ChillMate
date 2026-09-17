import ActivityKit
import AppIntents
import UserNotifications

/// "I'm home", from the Lock Screen, in one tap and without unlocking.
///
/// A `LiveActivityIntent` runs in the *app's* process even when the button that
/// fired it is drawn by the widget extension, which is what makes this possible
/// at all: only the process that started an activity can end it. An ordinary
/// `AppIntent` here would have had to open the app, which means a passcode,
/// which means the button is useless in the rain at 4am — exactly when somebody
/// is walking home and wants to close this out with a thumb.
///
/// It is not discoverable in Shortcuts. "I'm home" with no journey running is
/// not an action anybody wants in a gallery; it is a button on a specific thing.
struct SafeRouteArrivedIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "I'm home"
    static let description = IntentDescription("Marks the journey home as finished.")
    static let isDiscoverable = false
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await SafeRouteActivityAttributes.markArrived()

        // The reminder exists to catch a journey nobody closed out. This closed it
        // out, so it has to go, or it arrives later asking a question that has
        // been answered.
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [SafeRouteReminder.identifier])

        return .result()
    }
}
