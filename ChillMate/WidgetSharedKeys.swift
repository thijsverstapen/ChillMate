import Foundation

/// Keys in the shared App Group suite, written by the phone or watch app and read
/// by the widget and Live Activity extensions.
///
/// These crossed four targets (the app, the watch app, the watch widget, and the
/// Live Activity extension) as bare string literals duplicated at each end, with
/// a comment in `WatchConnectivityReceiver` reading "Key strings are duplicated in
/// the widget's WidgetStore by design. Keep them in sync." Nothing enforced that.
/// Renaming a key on the writing side left the reading side compiling cleanly and
/// silently showing zeros on the user's watch face.
///
/// This file is a member of all four targets, so the two ends cannot drift.
///
/// The names are deliberately unchanged: they are already in use on shipped
/// devices, and altering one would blank a complication until the next write.
enum WidgetSharedKey {
    /// App Group suite shared by every ChillMate target.
    static let suiteName = "group.com.codex.ChillMate"

    // MARK: Written by the watch app, read by the watch complication
    static let watchStreakDays = "widgetStreakDays"
    static let watchScore = "widgetScore"
    static let watchScoreActive = "widgetScoreActive"
    static let watchTimerSubstance = "widgetTimerSubstance"
    static let watchTimerStart = "widgetTimerStart"
    static let watchTimerEnd = "widgetTimerEnd"

    // MARK: Written by the phone app, read by the Live Activity extension
    static let recoveryStreak = "widgetRecoveryStreak"
    static let dailyScore = "lastDailyRecoveryScore"
    static let scoreIsActive = "widgetScoreIsActive"

    // MARK: Written by the phone app and by the Live Activity's Log water button

    /// Hydration timestamp. `HydrationLog` in the app target and the Live Activity's
    /// intent both read and write this, in the shared suite above, from separate
    /// processes. It lived as a bare literal at both ends, so changing either the
    /// spelling or the suite at one end stopped hydration crossing the boundary with
    /// no error anywhere.
    static let hydrationLogDate = "lastHydrationLogDate"

    // MARK: Watch settings, pushed from the phone in the application context
    //
    // These were bare string literals at both ends: spelled once in
    // `WatchConnectivityService.sendSettings()` and again in the watch's
    // `applyContext`. Renaming either side left both compiling and the watch
    // silently falling back to its defaults, which is the exact failure this file
    // was created to stop and which its own header describes.

    static let watchHydrationReminders = "watchHydrationReminders"
    static let watchBreathingHaptics = "watchBreathingHaptics"
    static let watchDiscreetCheckIns = "watchDiscreetCheckIns"
    static let watchVisibleTimers = "watchVisibleTimers"
    static let watchHeartRateWarnings = "watchHeartRateWarnings"

    static let watchStrainDetection = "watchStressAndTemperatureDetection"

    /// Every watch setting the phone pushes, so the sender cannot omit one by
    /// accident.
    static let watchSettingKeys = [
        watchHydrationReminders,
        watchBreathingHaptics,
        watchDiscreetCheckIns,
        watchVisibleTimers,
        watchHeartRateWarnings,
        watchStrainDetection,
    ]

    // MARK: Physiological strain, pushed from the phone

    /// Heart-rate variability in milliseconds, and whether a reading exists.
    ///
    /// Paired with the heart rate the phone already relays. Neither number means
    /// much alone: a high heart rate on its own is dancing. A high heart rate
    /// with suppressed variability is the body under load, which is the signal
    /// worth interrupting someone for.
    static let hasHRV = "hasHRV"
    static let latestHRVms = "latestHRVms"

    // MARK: Watch-local state
    //
    // These live in the watch's own `UserDefaults.standard`, NOT in the shared suite
    // above, because nothing off the watch reads them. They are registered here only
    // because this file is the one key registry the watch target compiles, and a key
    // that is not in a registry is a key that can drift.

    static let watchHydrationCount = "watchHydrationCount"
    static let watchHydrationDay = "watchHydrationDay"
    static let watchQuickSkipDay = "watchQuickSkipDay"
    static let watchEmergencyNumber = "watchEmergencyNumber"

    // MARK: Written by the phone app, read by the Lock Screen dose widget
    //
    // Separate from the `watchTimer*` keys above, which the *watch* writes for its
    // own complication. Sharing them would mean a phone with no paired watch
    // showing nothing, and a paired watch overwriting the phone's own state.

    static let doseTimerSubstance = "doseTimerSubstance"
    static let doseTimerStart = "doseTimerStart"
    static let doseTimerEnd = "doseTimerEnd"
    static let doseTimerComedownEnd = "doseTimerComedownEnd"

    // MARK: Written by the Control Center controls, read by the phone app

    /// Where the app should navigate on next foreground. A control runs in the
    /// extension's process, so it cannot reach the app's own `UserDefaults`
    /// and has to hand the destination over through the shared suite instead.
    static let pendingDestination = "widgetPendingDestination"

    /// Must equal `NotificationDestination.panic.rawValue` in the app target,
    /// which the extension cannot see. `ControlDestinationTests` asserts it.
    static let destinationPanic = "panic"

    /// The shared suite, or nil when the App Group is unavailable.
    static var suite: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}


/// The one dose the Lock Screen is showing, as it crosses from the app into the
/// widget extension.
///
/// Four bare keys with a shape agreed at both ends is exactly the drift this file
/// exists to prevent, so the shape lives here too and neither end spells a key.
///
/// `comedownEndsAt` is the reason this is not just the check-in timer. The timer
/// is a wellbeing reminder the user picked the length of; the comedown window is
/// what the sources publish, and it routinely outlives the timer by a day. A
/// Lock Screen that goes blank when the reminder ends would be answering the
/// easier question.
struct DoseTimerSnapshot: Equatable, Sendable {
    let substanceName: String
    let startedAt: Date
    let endsAt: Date

    /// When every published figure for this dose has elapsed, where the sources
    /// publish one. Nil is normal: it means nobody publishes an after-effects
    /// window for this substance, not that there is nothing after the timer.
    let comedownEndsAt: Date?

    /// The last moment this dose is worth a place on the Lock Screen.
    var lastMoment: Date {
        max(endsAt, comedownEndsAt ?? endsAt)
    }

    func isWorthShowing(at now: Date) -> Bool {
        now < lastMoment
    }

    /// Whether the check-in window has run out while the published window has not.
    func isInComedown(at now: Date) -> Bool {
        now >= endsAt && now < lastMoment
    }

    /// Reads the snapshot, or nil when there is none or it has expired.
    ///
    /// Expiry is checked on read rather than cleaned up on a schedule, because
    /// nothing wakes the app to do the cleaning. A stale write left behind by a
    /// force-quit must not become a Lock Screen that insists a dose from Tuesday
    /// is still running.
    static func read(from defaults: UserDefaults? = WidgetSharedKey.suite, now: Date = .now) -> DoseTimerSnapshot? {
        guard let defaults else { return nil }
        let name = defaults.string(forKey: WidgetSharedKey.doseTimerSubstance) ?? ""
        let start = defaults.double(forKey: WidgetSharedKey.doseTimerStart)
        let end = defaults.double(forKey: WidgetSharedKey.doseTimerEnd)
        guard !name.isEmpty, start > 0, end > 0 else { return nil }

        let comedown = defaults.double(forKey: WidgetSharedKey.doseTimerComedownEnd)
        let snapshot = DoseTimerSnapshot(
            substanceName: name,
            startedAt: Date(timeIntervalSince1970: start),
            endsAt: Date(timeIntervalSince1970: end),
            comedownEndsAt: comedown > 0 ? Date(timeIntervalSince1970: comedown) : nil
        )
        return snapshot.isWorthShowing(at: now) ? snapshot : nil
    }

    /// Writes the snapshot, or clears it when there is nothing to show.
    static func write(_ snapshot: DoseTimerSnapshot?, to defaults: UserDefaults? = WidgetSharedKey.suite) {
        guard let defaults else { return }
        guard let snapshot else {
            for key in [
                WidgetSharedKey.doseTimerSubstance,
                WidgetSharedKey.doseTimerStart,
                WidgetSharedKey.doseTimerEnd,
                WidgetSharedKey.doseTimerComedownEnd
            ] {
                defaults.removeObject(forKey: key)
            }
            return
        }
        defaults.set(snapshot.substanceName, forKey: WidgetSharedKey.doseTimerSubstance)
        defaults.set(snapshot.startedAt.timeIntervalSince1970, forKey: WidgetSharedKey.doseTimerStart)
        defaults.set(snapshot.endsAt.timeIntervalSince1970, forKey: WidgetSharedKey.doseTimerEnd)
        defaults.set(
            snapshot.comedownEndsAt?.timeIntervalSince1970 ?? 0,
            forKey: WidgetSharedKey.doseTimerComedownEnd
        )
    }
}

/// The two decisions the watch makes on its own, pulled out of
/// `WatchConnectivityReceiver` so they can be tested.
///
/// The watch app is its own target with no test bundle, and standing one up means
/// a watchOS runner in CI for the sake of two rules. These are the two rules —
/// both pure, both consequential — and this file is already a member of every
/// target, so they can be exercised from `ChillMateTests` instead.
///
/// The alternative was leaving the emergency number untested, which is the last
/// thing in the app that should be.
enum WatchLogic {

    /// Which number the watch should dial.
    ///
    /// The order matters and the empty check is the point. The phone relays the
    /// user's real emergency number over `applicationContext`, and the watch keeps
    /// the last one so a cold launch out of range still dials correctly. Falling
    /// back to 112 is right for the Netherlands, Belgium, Germany, France and
    /// Spain and reaches nobody in the United States or Australia, so a stored
    /// value must win over the default — and a *blank* stored value must not,
    /// because an empty string dials nothing at all.
    ///
    /// - Parameters:
    ///   - stored: what the watch last persisted, if anything.
    ///   - relayed: a number arriving from the phone in this update, if any.
    /// - Returns: the number to dial, never empty.
    static func emergencyNumber(stored: String?, relayed: String? = nil) -> String {
        if let relayed, !relayed.trimmingCharacters(in: .whitespaces).isEmpty {
            return relayed
        }
        if let stored, !stored.trimmingCharacters(in: .whitespaces).isEmpty {
            return stored
        }
        return "112"
    }

    /// The day a piece of once-a-day watch state belongs to.
    ///
    /// Whole days since the reference date, in the watch's own calendar. Hydration
    /// counts and the quick-skip flag both reset when this changes.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> Int {
        Int(calendar.startOfDay(for: date).timeIntervalSinceReferenceDate / 86_400)
    }

    /// Whether a once-a-day action is still available.
    ///
    /// Quick skip sends one event per day. `lastSentDay` is 0 on a watch that has
    /// never sent one, which must not collide with a real day key — it cannot,
    /// because day zero is 1 January 2001.
    static func isAvailableToday(lastSentDay: Int, now: Date = .now, calendar: Calendar = .current) -> Bool {
        lastSentDay != dayKey(for: now, calendar: calendar)
    }
}
