import Foundation

/// Keys in the shared App Group suite, written by the phone or watch app and read
/// by the widget and Live Activity extensions.
///
/// These crossed four targets — the app, the watch app, the watch widget, and the
/// Live Activity extension — as bare string literals duplicated at each end, with
/// a comment in `WatchConnectivityReceiver` reading "Key strings are duplicated in
/// the widget's WidgetStore by design — keep them in sync." Nothing enforced that.
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

    /// The shared suite, or nil when the App Group is unavailable.
    static var suite: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}
