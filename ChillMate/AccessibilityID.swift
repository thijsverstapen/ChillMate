import Foundation

/// Stable, locale-independent identifiers for UI tests.
///
/// The UI tests queried controls by their English display label
/// (`app.tabBars.buttons["More"]`), which meant they could only pass in English —
/// including `testLaunchesInEveryLanguage`, whose entire point is the other four.
/// Identifiers are never localized, so a test written against these works in every
/// language.
///
/// Kept in the app target (not the test target) so the identifier and the view
/// that carries it live together and cannot drift apart.
enum AccessibilityID {
    // Tabs
    static let homeTab = "tab.home"
    static let historyTab = "tab.history"
    static let moreTab = "tab.more"

    // Home
    static let logChillButton = "home.logChill"
    static let skipNightButton = "home.skipNight"
    static let panicButton = "home.panic"
    static let dailyScorePill = "home.dailyScore"

    // Log sheet
    static let logSheet = "log.sheet"
    static let logSaveButton = "log.save"
    static let logCancelButton = "log.cancel"
}
