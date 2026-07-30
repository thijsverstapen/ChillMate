import Foundation

/// The registry of the UserDefaults keys the app target reads or writes.
///
/// These keys were previously repeated as bare string literals at each use site:
/// `trustedContactPhone` in eight places, `requiresFaceID`, `notificationsEnabled`,
/// `chillReducedMotion` and others in six each, spread across `@AppStorage`
/// declarations, `UserDefaults.standard` calls, the widget, and the watch app. A
/// typo in any one of those silently bound to a *different* key that reads back as
/// `false`/`""` rather than failing, which is exactly how `chillReducedMotion` ended
/// up wired into onboarding only while Settings advertised it app-wide.
///
/// Going through a constant here turns such a typo into a compile error. There is no
/// cost to it: `@AppStorage` only needs a `String`, so a constant drops in wherever a
/// literal used to sit.
///
/// Not every `forKey:` in the codebase resolves to this enum, and two of those cases
/// are deliberate rather than oversights:
///
/// 1. `ProfessionalHelperBridgeView` passes "paperRect" and "printableRect" to
///    `setValue(_:forKey:)` on a `UIPrintPageRenderer`. Those are KVC property names
///    on a UIKit object, not UserDefaults keys, and declaring them here would invite
///    someone to look them up in the wrong store.
/// 2. Keys that cross a process boundary into the widget, the Live Activity or the
///    watch belong in `WidgetSharedKey`, which is compiled into all four targets.
///    This file is a member of the app target only, so a copy here could quietly
///    drift from the copy an extension actually writes.
enum DefaultsKey {
    // MARK: Lock & privacy
    static let requiresFaceID = "requiresFaceID"
    static let requiresPIN = "requiresPIN"
    static let autoLockMinutes = "autoLockMinutes"
    static let localEncryptionEnabled = "localEncryptionEnabled"
    static let screenPrivacyEnabled = "screenPrivacyEnabled"
    static let pinFailedAttempts = "pinFailedAttempts"
    static let pinLockoutUntil = "pinLockoutUntil"
    /// Legacy salted SHA256 PIN credentials, from before PINs moved to PBKDF2 in the
    /// Keychain. `LocalSecurityService` reads them once so a PIN set on an older build
    /// still unlocks the app, then deletes them as it re-derives the credentials into
    /// the Keychain. Nothing writes them any more.
    ///
    /// The two strings are byte-for-byte what earlier builds stored. They are the only
    /// way back in for someone who set a PIN before the Keychain migration, so a
    /// changed value here would not fail loudly, it would lock that person out of
    /// their own log with a PIN they typed correctly.
    static let legacyAppPINHash = "appPINHash"
    static let legacyAppPINSalt = "appPINSalt"

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
    /// Short fingerprint of the file-backed background photo (no image bytes).
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
    /// Per-install identifier stamped into encrypted backup files, so a restore can
    /// tell a backup this device made from one another device made. Minted on first
    /// read and never rotated: rotating it would make every existing backup look
    /// foreign. Read and written by `EncryptedBackupDevice` in
    /// `EncryptedBackupService`, in `UserDefaults.standard`.
    static let encryptedBackupDeviceID = "encryptedBackupDeviceID"

    // MARK: Session state
    static let lastAppUseTimestamp = "lastAppUseTimestamp"
    static let hasActiveDrugTimer = "hasActiveDrugTimer"
    static let hasShownFirstLaunchSplash = "hasShownFirstLaunchSplash"
    static let drugTimerTrackedPeople = "drugTimerTrackedPeople"
    static let typedRecordsMigrationCompleted = "typedRecordsMigrationCompleted"
    // The daily hydration flag is deliberately absent. It is written by the Live
    // Activity's Log water button and by the Siri intent as well as by the app, so it
    // lives in the App Group suite under `HydrationLog`, not in
    // `UserDefaults.standard`. A constant here would name the wrong store.

    // MARK: Watch mirror (read on the watch, written on the phone)
    static let watchHydrationReminders = "watchHydrationReminders"
    static let watchBreathingHaptics = "watchBreathingHaptics"
    static let watchDiscreetCheckIns = "watchDiscreetCheckIns"
    static let watchVisibleTimers = "watchVisibleTimers"
    static let watchHeartRateWarnings = "watchHeartRateWarnings"

    // MARK: Consent, recovery & emergency free-text
    static let consentBoundaryWant = "consentBoundaryWant"
    static let consentBoundaryNo = "consentBoundaryNo"
    static let consentCheckInPhrase = "consentCheckInPhrase"
    static let consentExitPlan = "consentExitPlan"
    static let recoveryGoal = "recoveryGoal"
    static let recoveryCommitment = "recoveryCommitment"
    static let recoverySupportPerson = "recoverySupportPerson"
    static let emergencyAllergies = "emergencyAllergies"
    static let emergencyInstructions = "emergencyInstructions"
    static let localHealthcareContact = "localHealthcareContact"

    // MARK: Onboarding & UI state
    static let ageAssuranceVerifiedAdult = "ageAssuranceVerifiedAdult"
    static let ageAssuranceUnderage = "ageAssuranceUnderage"
    static let onboardingSwipeHintShown = "onboardingSwipeHintShown"
    static let locationServicesChecked = "locationServicesChecked"
    static let lastSelectedTab = "lastSelectedTab"
    static let lastBackgroundedAt = "lastBackgroundedAt"
    static let oneHandedControls = "oneHandedControls"

    // MARK: Misc settings
    static let healthKitSexualActivityWriteEnabled = "healthKitSexualActivityWriteEnabled"
    static let stiReminderMonths = "stiReminderMonths"
    static let watchStressAndTemperatureDetection = "watchStressAndTemperatureDetection"
    static let recentlyDeletedItems = "recentlyDeletedItems"

    // MARK: Language

    /// The system key iOS reads to resolve which `.lproj` a bundle serves. Not ours:
    /// the per-app Language screen in Settings writes it too, which is why
    /// `LocalizationService` has to reconcile rather than assume it is the only
    /// writer. Registered here so the spelling has one home.
    static let appleLanguages = "AppleLanguages"

    /// The language ChillMate itself last wrote into `appleLanguages`. Remembering
    /// what we asserted is the only way to recognise a value we did not write, which
    /// is what a change made in Settings looks like from inside the app.
    static let languageAssertedByChillMate = "appLanguageAssertedByChillMate"

    /// App-group suite shared with the widget and Live Activity extensions.
    /// Defined in `WidgetSharedKey`, which is a member of all four targets.
    static let appGroupSuite = WidgetSharedKey.suiteName
}
