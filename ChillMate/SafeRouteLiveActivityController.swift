import ActivityKit
import Foundation

/// Starting, extending and ending the journey home.
///
/// Mirrors `DrugTimerLiveActivityController` in shape deliberately — same
/// guard on `areActivitiesEnabled`, same silence on failure — because a second
/// controller that behaved differently would be a second set of edge cases to
/// remember.
///
/// One journey at a time. Starting a second while one is running replaces it
/// rather than stacking: two "are you home yet" activities on a Lock Screen is
/// noise, and the answer to both is the same tap.
enum SafeRouteLiveActivityController {

    @MainActor
    static var isRunning: Bool {
        Activity<SafeRouteActivityAttributes>.activities.contains { $0.content.state.arrivedAt == nil }
    }

    /// The expected arrival of the journey currently running, if there is one.
    @MainActor
    static var expectedArrival: Date? {
        Activity<SafeRouteActivityAttributes>.activities
            .first { $0.content.state.arrivedAt == nil }?
            .content.state.expectedArrival
    }

    @MainActor
    static func start(expectedArrival: Date, now: Date = .now) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        await end(now: now)

        let state = SafeRouteActivityAttributes.ContentState(expectedArrival: expectedArrival, arrivedAt: nil)
        do {
            _ = try Activity.request(
                attributes: SafeRouteActivityAttributes(startedAt: now),
                // Stale at the expected arrival, not later: past that moment the
                // activity is making a claim it can no longer support, and the
                // system dimming it is the correct thing to happen.
                content: ActivityContent(state: state, staleDate: expectedArrival),
                pushType: nil
            )
        } catch {
            print("[ChillMate] Safe route Live Activity request failed: \(error)")
        }
    }

    /// Pushes a new arrival time onto a running journey.
    @MainActor
    static func extend(to expectedArrival: Date) async {
        for activity in Activity<SafeRouteActivityAttributes>.activities where activity.content.state.arrivedAt == nil {
            var state = activity.content.state
            state.expectedArrival = expectedArrival
            await activity.update(ActivityContent(state: state, staleDate: expectedArrival))
        }
    }

    /// Ends every journey, arrived or not. Used when starting a new one and when
    /// the user cancels from inside the app.
    @MainActor
    static func end(now: Date = .now) async {
        for activity in Activity<SafeRouteActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: now),
                dismissalPolicy: .immediate
            )
        }
    }
}
