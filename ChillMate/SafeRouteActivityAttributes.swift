import ActivityKit
import Foundation

/// The journey home, as a Live Activity.
///
/// Deliberately almost empty, and that is the design. A Live Activity draws on
/// the Lock Screen, which is the one screen in the app's world that anybody
/// standing next to you can read without a passcode — the same screen the panic
/// hide and the duress PIN exist because of. So the destination is not in here.
/// Not the address, not the name of the place, not "home". Somebody glancing over
/// a shoulder on a night bus learns that a timer is running and nothing else.
///
/// What it does carry is the only thing the surface needs: when you said you
/// would be there, and whether you have said you are. The button is the feature.
struct SafeRouteActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the journey should be over.
        var expectedArrival: Date

        /// Set once they have said they are home. Optional so an activity started
        /// by an older build still decodes across an app update.
        var arrivedAt: Date?

        /// Whether the expected time has passed with nobody saying anything.
        func isOverdue(at now: Date) -> Bool {
            arrivedAt == nil && now > expectedArrival
        }
    }

    let startedAt: Date
}

extension SafeRouteActivityAttributes {

    /// Ending a journey by saying you are home.
    ///
    /// Here rather than in the controller because the Lock Screen button's intent
    /// runs in the app's process but is *compiled* into the widget extension,
    /// where the controller does not exist. Two implementations of the same tap
    /// is how one of them quietly stops cancelling the reminder.
    @MainActor
    static func markArrived(now: Date = .now) async {
        for activity in Activity<SafeRouteActivityAttributes>.activities where activity.content.state.arrivedAt == nil {
            var state = activity.content.state
            state.arrivedAt = now
            // Left on screen for a couple of minutes rather than vanishing, so the
            // tap visibly did something. A button that makes the thing disappear
            // instantly reads as a mis-tap.
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .after(now.addingTimeInterval(120))
            )
        }
    }
}

/// The overdue reminder's identifier.
///
/// Lives here rather than in `NotificationService` because both the app and the
/// Live Activity extension need it: the app schedules the reminder, and the
/// intent behind the "I'm home" button cancels it. The intent is compiled into
/// both targets, so anything it touches has to be.
enum SafeRouteReminder {
    static let identifier = "chillmate.saferoute.overdue"

    /// How long a journey is assumed to take when nobody says otherwise.
    ///
    /// Thirty minutes is a guess and is meant to be edited. It is short on
    /// purpose: a reminder that arrives too early is a tap, and one that arrives
    /// too late is the whole point of the feature missed.
    static let defaultMinutes = 30

    static let selectableMinutes = [15, 30, 45, 60, 90]
}
