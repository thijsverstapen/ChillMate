import StoreKit
import SwiftUI

/// Asks for an App Store rating only once the reader has finished something, and
/// rarely. Deliberately never called from panic support, the emergency sheet or
/// any other crisis path: a rating card on top of those would be indefensible.
@MainActor
enum ReviewPrompt {
    /// Completed aftercare check-ins required before the first ask.
    private static let minimumCheckIns = 4

    /// Seconds between asks. Apple caps prompts at three a year regardless; this
    /// keeps ChillMate well inside that on its own.
    private static let cooldown: TimeInterval = 120 * 24 * 60 * 60

    private static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static func recordCheckIn() {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: DefaultsKey.reviewCheckInCount)
        defaults.set(count + 1, forKey: DefaultsKey.reviewCheckInCount)
    }

    /// Whether this moment has been earned. Call `recordAsked()` if you act on it.
    static func shouldAsk() -> Bool {
        let defaults = UserDefaults.standard

        guard defaults.integer(forKey: DefaultsKey.reviewCheckInCount) >= minimumCheckIns else {
            return false
        }

        // At most once per released version, so an update never re-asks someone
        // who has already answered.
        guard defaults.string(forKey: DefaultsKey.reviewPromptedVersion) != currentVersion else {
            return false
        }

        let last = defaults.double(forKey: DefaultsKey.reviewPromptedAt)
        return last == 0 || Date.now.timeIntervalSince1970 - last > cooldown
    }

    static func recordAsked() {
        let defaults = UserDefaults.standard
        defaults.set(currentVersion, forKey: DefaultsKey.reviewPromptedVersion)
        defaults.set(Date.now.timeIntervalSince1970, forKey: DefaultsKey.reviewPromptedAt)
    }
}
