import Foundation
import SwiftData
import WidgetKit

/// Which dose the phone's other surfaces should be showing, and telling all of
/// them at once.
///
/// Three places read "is a dose running": the watch over WatchConnectivity, the
/// Home Screen widgets, and the Lock Screen dose widget through the App Group.
/// Before this they were told in different places and not all of them — a timer
/// started by Siri wrote a record and a Live Activity and told the watch nothing,
/// so a phone in a pocket and a watch on a wrist disagreed about whether anything
/// was running. One entry point means a new way to start a timer cannot quietly
/// miss a surface.
enum ActiveDoseTimer {

    /// The timer the Lock Screen should show, or nil when there is nothing to say.
    ///
    /// Only the user's own: a timer with a person's name on it is one they are
    /// keeping for somebody else, and that person's substance use does not belong
    /// on a Lock Screen that anyone standing nearby can read.
    ///
    /// Most recently started wins. With two doses running, the newer one is the
    /// one whose onset is still ahead and therefore the one where a decision is
    /// still to be made.
    static func mostRelevant(in timers: [DrugDoseTimerRecord], now: Date = .now) -> DrugDoseTimerRecord? {
        timers
            .filter { $0.personName.trimmingCharacters(in: .whitespaces).isEmpty }
            .filter { snapshot(for: $0).isWorthShowing(at: now) }
            .max { $0.startedAt < $1.startedAt }
    }

    /// What crosses into the widget extension for one timer.
    static func snapshot(for timer: DrugDoseTimerRecord) -> DoseTimerSnapshot {
        // `afterEffectsEnd`, not `lastPublishedMoment`. The latter falls back to
        // the end of the effects when no after-effects window is published, which
        // would have the widget announce a comedown for cocaine — the one
        // substance here whose source explicitly publishes no window at all.
        let comedownEnd = Substance(rawValue: timer.substanceName).flatMap { substance in
            ComedownTimeline(
                substance: substance,
                route: AdministrationRoute(rawValue: timer.administrationRoute)?.referenceRoute,
                startedAt: timer.startedAt
            )?.afterEffectsEnd
        }
        return DoseTimerSnapshot(
            substanceName: timer.substanceName,
            startedAt: timer.startedAt,
            endsAt: timer.endsAt,
            comedownEndsAt: comedownEnd
        )
    }

    /// Tell every surface that the set of timers changed.
    ///
    /// Call this from anywhere a timer is created, deleted or edited, including
    /// from App Intents, which run without any of the app's views on screen.
    @MainActor
    static func broadcast(_ timers: [DrugDoseTimerRecord], now: Date = .now) {
        WatchConnectivityService.shared.sendActiveTimers(timers)
        DoseTimerSnapshot.write(mostRelevant(in: timers, now: now).map(snapshot(for:)))
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// The same, for callers that have a context rather than a list.
    @MainActor
    static func broadcast(from context: ModelContext, now: Date = .now) {
        broadcast(context.fetchLogging(FetchDescriptor<DrugDoseTimerRecord>()), now: now)
    }
}
