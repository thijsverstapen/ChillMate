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
