import Foundation

/// The single registry of every UserDefaults key ChillMate reads or writes.
///
/// These keys were previously repeated as bare string literals at each use site
/// — `trustedContactPhone` in eight places, `requiresFaceID`, `notificationsEnabled`,
/// `chillReducedMotion` and others in six each — across `@AppStorage` declarations,
/// `UserDefaults.standard` calls, the widget, and the watch app. A typo in any one
/// of those silently bound to a *different* key that reads back as `false`/`""`
/// rather than failing, which is exactly how `chillReducedMotion` ended up wired
/// into onboarding only while Settings advertised it app-wide.
///
/// Every key lives here now, so a typo is a compile error. `@AppStorage` requires a
/// literal-typed String, which these constants satisfy.
enum DefaultsKey {
    // MARK: Lock & privacy
    static let requiresFaceID = "requiresFaceID"
    static let requiresPIN = "requiresPIN"
    static let autoLockMinutes = "autoLockMinutes"
    static let localEncryptionEnabled = "localEncryptionEnabled"
    static let screenPrivacyEnabled = "screenPrivacyEnabled"
    static let pinFailedAttempts = "pinFailedAttempts"
    static let pinLockoutUntil = "pinLockoutUntil"

    // MARK: Notifications
    static let notificationsEnabled = "notificationsEnabled"
    static let dailyAffirmationsEnabled = "dailyAffirmationsEnabled"
    static let discreetNotifications = "discreetNotifications"
    static let notificationTone = "notificationTone"
    static let checkInHour = "checkInHour"
    static let checkInMinute = "checkInMinute"
    static let safetyCheckInsEnabled = "safetyCheckInsEnabled"
    static let weekendSafetyEnabled = "weekendSafetyEnabled"
    static let weeklyDigestEnabled = "weeklyDigestEnabled"
    static let stiReminderEnabled = "stiReminderEnabled"
    static let lastInactivityScheduleDay = "lastInactivityScheduleDay"
    static let lastAffirmationScheduleDay = "lastAffirmationScheduleDay"
    static let pendingAppDestination = "pendingAppDestination"

    // MARK: Health & metrics
    static let healthKitAutoSync = "healthKitAutoSync"
    static let healthKitSleepReadWriteEnabled = "healthKitSleepReadWriteEnabled"
    static let healthKitHeartRateReadEnabled = "healthKitHeartRateReadEnabled"
    static let healthKitHRVReadEnabled = "healthKitHRVReadEnabled"
    static let healthKitWorkoutReadEnabled = "healthKitWorkoutReadEnabled"
    static let lastKnownHRVms = "lastKnownHRVms"
    static let lastDailyRecoveryScore = "lastDailyRecoveryScore"
    static let reductionGoalSessions = "reductionGoalSessions"
    static let reductionGoalCountSubstanceOnly = "reductionGoalCountSubstanceOnly"

    // MARK: Appearance & accessibility
    static let appBackgroundStyle = "appBackgroundStyle"
    /// Legacy: the background photo as base64 in UserDefaults. Read only by
    /// `BackgroundPhotoStore.migrateFromUserDefaultsIfNeeded()`, which moves it to a
    /// file and clears it.
    static let appBackgroundPhotoData = "appBackgroundPhotoData"
    /// Short fingerprint of the file-backed background photo — no image bytes.
    static let appBackgroundPhotoFingerprint = "appBackgroundPhotoFingerprint"
    static let highContrastMode = "highContrastMode"
    static let chillReducedMotion = "chillReducedMotion"

    // MARK: Profile & locale
    static let appLanguage = "appLanguage"
    static let country = "country"
    static let localEmergencyNumber = "localEmergencyNumber"
    static let trustedContactName = "trustedContactName"
    static let trustedContactPhone = "trustedContactPhone"
    static let trustedContactMessage = "trustedContactMessage"

    // MARK: Backup & recovery
    static let iCloudBackupEnabled = "iCloudBackupEnabled"
    static let lastICloudBackupTimestamp = "lastICloudBackupTimestamp"
    static let lastICloudRestoreTimestamp = "lastICloudRestoreTimestamp"
    static let lastICloudBackupStatus = "lastICloudBackupStatus"
    static let lastOnDeviceRecoveryStatus = "lastOnDeviceRecoveryStatus"
    static let lastOnDeviceRecoverySnapshotTimestamp = "lastOnDeviceRecoverySnapshotTimestamp"
    static let lastOnDeviceRecoveryRestoreTimestamp = "lastOnDeviceRecoveryRestoreTimestamp"
    static let dataRetentionMonths = "dataRetentionMonths"

    // MARK: Session state
    static let lastAppUseTimestamp = "lastAppUseTimestamp"
    static let hasActiveDrugTimer = "hasActiveDrugTimer"
    static let hasShownFirstLaunchSplash = "hasShownFirstLaunchSplash"
    static let drugTimerTrackedPeople = "drugTimerTrackedPeople"
    static let hydrationLastLoggedDay = "hydrationLastLoggedDay"
    static let typedRecordsMigrationCompleted = "typedRecordsMigrationCompleted"

    // MARK: Watch mirror (read on the watch, written on the phone)
    static let watchHydrationReminders = "watchHydrationReminders"
    static let watchBreathingHaptics = "watchBreathingHaptics"
    static let watchDiscreetCheckIns = "watchDiscreetCheckIns"
    static let watchVisibleTimers = "watchVisibleTimers"
    static let watchHeartRateWarnings = "watchHeartRateWarnings"

    /// App-group suite shared with the widget and Live Activity extensions.
    static let appGroupSuite = "group.com.codex.ChillMate"
}
