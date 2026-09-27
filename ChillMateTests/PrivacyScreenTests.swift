import Foundation
import Testing
@testable import ChillMate

/// What the Privacy screen counts as a protection.
///
/// The Security check it replaced counted Apple Health sync and the iCloud
/// backup among its protections and told people to switch on whatever was off,
/// so sharing more data raised the score. These pin what counts now.
@Suite("Privacy screen")
struct PrivacyScreenTests {

    private let none = PrivacyProtections(appLock: false, secondPIN: false, hideFromScreenshots: false, quietLockScreen: false, discreetTimer: false)

    @Test("Each protection counts once, and there are five")
    func counting() {
        #expect(none.onCount == 0)
        #expect(PrivacyProtections.total == 5)

        let all = PrivacyProtections(appLock: true, secondPIN: true, hideFromScreenshots: true, quietLockScreen: true, discreetTimer: true)
        #expect(all.onCount == PrivacyProtections.total)

        var one = none
        one.hideFromScreenshots = true
        #expect(one.onCount == 1)
    }

    /// Nothing on the Lock Screen is as quiet as discreet wording.
    @Test("No notifications counts as a quiet Lock Screen")
    func quietLockScreen() {
        #expect(PrivacyProtections.quietLockScreen(notificationsOn: false, discreet: false))
        #expect(PrivacyProtections.quietLockScreen(notificationsOn: true, discreet: true))
        #expect(!PrivacyProtections.quietLockScreen(notificationsOn: true, discreet: false))
    }
}

/// Removing what the encrypted iCloud Drive backup left behind.
@MainActor
@Suite("Legacy iCloud backup cleanup")
struct LegacyICloudBackupFilesTests {

    private func freshDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "LegacyICloudBackupFilesTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// Nearly everybody. Nothing to find, so iCloud Drive is never asked.
    @Test("Somebody who never used the backup is settled at once")
    func neverUsed() async {
        let defaults = freshDefaults()
        await LegacyICloudBackupFiles.removeIfNeeded(defaults: defaults)
        #expect(defaults.bool(forKey: DefaultsKey.legacyICloudBackupsRemoved))
    }

    /// The test host has no iCloud account, which is exactly the signed-out case:
    /// the files cannot be reached, so nothing is marked done and the old keys
    /// stay, to try again on a later launch.
    @Test("When iCloud Drive can't be reached, it tries again later")
    func unreachableRetries() async {
        let defaults = freshDefaults()
        defaults.set(true, forKey: DefaultsKey.legacyICloudBackupEnabled)
        defaults.set(1_790_000_000.0, forKey: DefaultsKey.legacyLastICloudBackupTimestamp)

        await LegacyICloudBackupFiles.removeIfNeeded(defaults: defaults)

        #expect(!defaults.bool(forKey: DefaultsKey.legacyICloudBackupsRemoved))
        #expect(defaults.object(forKey: DefaultsKey.legacyICloudBackupEnabled) != nil)
    }

    @Test("Once settled, the old backup settings are gone")
    func settledClearsKeys() async {
        let defaults = freshDefaults()
        defaults.set("Encrypted iCloud backup saved.", forKey: "lastICloudBackupStatus")
        await LegacyICloudBackupFiles.removeIfNeeded(defaults: defaults)
        for key in DefaultsKey.legacyICloudBackupKeys {
            #expect(defaults.object(forKey: key) == nil, "\(key) survived")
        }
    }
}
