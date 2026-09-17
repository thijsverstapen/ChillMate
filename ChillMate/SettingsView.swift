import PhotosUI
import SwiftData
import SwiftUI
import TipKit
import UniformTypeIdentifiers
import ChillMateCore

/// Eleven full-width cards made Settings a long, undifferentiated scroll. The
/// same eleven destinations now sit in five labelled groups of compact rows.
// Internal alongside `SettingsSectionPage`, which publishes it: a type cannot
// expose one less visible than itself.
enum SettingsGroup: String, CaseIterable, Identifiable {
    case security
    case alerts
    case presentation
    case data
    case review

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .security: "Privacy and security"
        case .alerts: "Alerts and devices"
        case .presentation: "Look and feel"
        case .data: "Your data"
        case .review: "Goals and review"
        }
    }

    var pages: [SettingsSectionPage] {
        SettingsSectionPage.allCases.filter { $0.group == self }
    }
}

enum SettingsSectionPage: String, CaseIterable, Identifiable {
    case privacy = "Privacy & lock"
    case privacyDashboard = "Privacy dashboard"
    case permissions = "Permissions"
    case notifications = "Notifications"
    case iCloud = "iCloud backup"
    case accessibility = "Accessibility"
    case appearance = "Appearance"
    case watch = "Apple Watch"
    case shortcuts = "Siri & Shortcuts"
    case goals = "Reduction goals"
    case quality = "Safety review"
    case account = "Account data"

    var id: String { rawValue }

    var group: SettingsGroup {
        switch self {
        case .privacy, .privacyDashboard, .permissions: .security
        case .notifications, .watch, .shortcuts: .alerts
        case .appearance, .accessibility: .presentation
        case .iCloud, .account: .data
        case .goals, .quality: .review
        }
    }

    var symbol: String {
        switch self {
        case .privacy:
            "lock.shield.fill"
        case .privacyDashboard:
            "list.clipboard.fill"
        case .permissions:
            "checkmark.shield.fill"
        case .notifications:
            "bell.badge.fill"
        case .iCloud:
            "icloud.fill"
        case .accessibility:
            "accessibility.fill"
        case .appearance:
            "paintpalette.fill"
        case .watch:
            "applewatch"
        case .shortcuts:
            "mic.fill"
        case .goals:
            "chart.line.downtrend.xyaxis"
        case .quality:
            "checkmark.seal.text.page.fill"
        case .account:
            "person.crop.circle.badge.xmark"
        }
    }

    var subtitle: String {
        switch self {
        case .privacy:
            String(localized: "Face ID, PIN, and local protection")
        case .privacyDashboard:
            String(localized: "What is stored, exported, and never shared")
        case .permissions:
            String(localized: "Health and system access")
        case .notifications:
            String(localized: "Check-ins and affirmations")
        case .iCloud:
            String(localized: "Encrypted backup and restore")
        case .accessibility:
            String(localized: "Readable, calm, and one-handed app behavior")
        case .appearance:
            String(localized: "Adaptive background and photos")
        case .watch:
            String(localized: "Companion preferences")
        case .shortcuts:
            String(localized: "Voice actions and the Shortcuts gallery")
        case .goals:
            String(localized: "Max sessions per month and reduction tracking")
        case .quality:
            String(localized: "Medical wording, evidence limits, and review status")
        case .account:
            String(localized: "Export backup, delete account, and stored data")
        }
    }
}

@MainActor
struct SettingsView: View {
    @Environment(\.services) private var services
    @AppStorage(DefaultsKey.requiresFaceID) private var requiresFaceID = false
    @AppStorage(DefaultsKey.requiresPIN) private var requiresPIN = false
    @State private var isShowingDuressSetup = false
    @State private var hasDuressPIN = LocalSecurityService.hasDuressPIN()
    @AppStorage(DefaultsKey.localEncryptionEnabled) private var localEncryptionEnabled = true
    @AppStorage(DefaultsKey.healthKitAutoSync) private var healthKitAutoSync = false
    @AppStorage(DefaultsKey.healthKitSexualActivityWriteEnabled) private var healthKitSexualActivityWriteEnabled = false
    @AppStorage(DefaultsKey.healthKitSleepReadWriteEnabled) private var healthKitSleepReadWriteEnabled = false
    @AppStorage(DefaultsKey.healthKitHeartRateReadEnabled) private var healthKitHeartRateReadEnabled = false
    @AppStorage(DefaultsKey.healthKitHRVReadEnabled) private var healthKitHRVReadEnabled = false
    @AppStorage(DefaultsKey.healthKitWorkoutReadEnabled) private var healthKitWorkoutReadEnabled = false
    @AppStorage(DefaultsKey.healthKitVitalsReadEnabled) private var healthKitVitalsReadEnabled = false
    @AppStorage(DefaultsKey.healthKitMindfulWriteEnabled) private var healthKitMindfulWriteEnabled = false
    @AppStorage(DefaultsKey.notificationsEnabled) private var notificationsEnabled = false
    @AppStorage(DefaultsKey.dailyAffirmationsEnabled) private var dailyAffirmationsEnabled = false
    @AppStorage(DefaultsKey.discreetNotifications) private var discreetNotifications = false
    @AppStorage(DefaultsKey.notificationTone) private var notificationTone = NotificationTone.gentle.rawValue
    @AppStorage(DefaultsKey.iCloudBackupEnabled) private var iCloudBackupEnabled = false
    @AppStorage(DefaultsKey.lastICloudBackupStatus) private var lastICloudBackupStatus = ""
    @AppStorage(DefaultsKey.lastICloudBackupTimestamp) private var lastICloudBackupTimestamp = 0.0
    @AppStorage(DefaultsKey.highContrastMode) private var highContrastMode = false
    @AppStorage(DefaultsKey.chillReducedMotion) private var chillReducedMotion = false
    @AppStorage(DefaultsKey.oneHandedControls) private var oneHandedControls = true
    @AppStorage(DefaultsKey.appBackgroundStyle) private var appBackgroundStyle = ChillBackgroundStyle.score.rawValue
    @AppStorage(DefaultsKey.appBackgroundPhotoFingerprint) private var backgroundPhotoFingerprint = ""
    @AppStorage(DefaultsKey.lastDailyRecoveryScore) private var lastDailyRecoveryScore = 42
    @AppStorage(DefaultsKey.watchHydrationReminders) private var watchHydrationReminders = true
    @AppStorage(DefaultsKey.watchHeartRateWarnings) private var watchHeartRateWarnings = true
    @AppStorage(DefaultsKey.watchBreathingHaptics) private var watchBreathingHaptics = true
    @AppStorage(DefaultsKey.watchDiscreetCheckIns) private var watchDiscreetCheckIns = true
    @AppStorage(DefaultsKey.watchVisibleTimers) private var watchVisibleTimers = true
    @AppStorage(DefaultsKey.watchStressAndTemperatureDetection) private var watchStressAndTemperatureDetection = false
    @AppStorage(DefaultsKey.autoLockMinutes) private var autoLockMinutes = 0
    @AppStorage(DefaultsKey.screenPrivacyEnabled) private var screenPrivacyEnabled = true
    @AppStorage(DefaultsKey.safetyCheckInsEnabled) private var safetyCheckInsEnabled = false
    @AppStorage(DefaultsKey.weekendSafetyEnabled) private var weekendSafetyEnabled = false
    @AppStorage(DefaultsKey.checkInHour) private var checkInHour = 10
    @AppStorage(DefaultsKey.checkInMinute) private var checkInMinute = 0

    private var checkInTimeBinding: Binding<Date> {
        Binding {
            Calendar.current.date(
                bySettingHour: min(max(checkInHour, 0), 23),
                minute: min(max(checkInMinute, 0), 59),
                second: 0,
                of: .now
            ) ?? .now
        } set: { newDate in
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
            checkInHour = comps.hour ?? 10
            checkInMinute = comps.minute ?? 0
            if notificationsEnabled {
                services.notifications.scheduleCheckInReminder()
            }
        }
    }
    @AppStorage(DefaultsKey.weeklyDigestEnabled) private var weeklyDigestEnabled = false
    @AppStorage(DefaultsKey.stiReminderEnabled) private var stiReminderEnabled = false
    @AppStorage(DefaultsKey.stiReminderMonths) private var stiReminderMonths = 3
    @AppStorage(DefaultsKey.dataRetentionMonths) private var dataRetentionMonths = 0
    @AppStorage(DefaultsKey.dataRetentionAutomatic) private var dataRetentionAutomatic = false
    @AppStorage(DefaultsKey.reductionGoalSessions) private var reductionGoalSessions = 0
    @AppStorage(DefaultsKey.reductionGoalCountSubstanceOnly) private var reductionGoalCountSubstanceOnly = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var message: String?
    @State private var isWorking = false
    @State private var isRevertingToggle = false
    @State private var isShowingDeleteWarning = false
    @State private var isShowingFinalDeleteCheck = false
    @State private var isShowingPINSetup = false
    @State private var isShowingDisablePINAlert = false
    @State private var selectedBackgroundPhoto: PhotosPickerItem?
    @State private var encryptedBackupURL: URL?
    @State private var isShowingBackupImporter = false

    let showsBackButton: Bool

    init(showsBackButton: Bool = true) {
        self.showsBackButton = showsBackButton
    }

    private var palette: DailyScorePalette {
        DailyScorePalette(score: lastDailyRecoveryScore)
    }

    private var watchSettingsFingerprint: [Bool] {
        [watchHydrationReminders, watchHeartRateWarnings, watchBreathingHaptics, watchDiscreetCheckIns, watchVisibleTimers, watchStressAndTemperatureDetection]
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "n/a"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "n/a"
        return "ChillMate \(version) (\(build))"
    }

    var body: some View {
        ZStack {
            DashboardBackdrop()

            ScrollView {
                settingsCategoryList
            }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: SettingsSectionPage.self) { page in
                settingsPage(page)
                    // Status banners belong to the screen that created them. Clear
                    // any leftover message when opening a section so it doesn't
                    // follow the user onto unrelated settings pages.
                    .onAppear { message = nil }
            }
            .onChange(of: requiresFaceID) { _, isOn in
                faceIDLockChanged(isOn)
            }
            .onChange(of: localEncryptionEnabled) { _, isOn in
                localEncryptionChanged(isOn)
            }
            .onChange(of: healthKitAutoSync) { _, isOn in
                healthKitSyncChanged(isOn)
            }
            .onChange(of: notificationsEnabled) { _, isOn in
                notificationsChanged(isOn)
            }
            .onChange(of: dailyAffirmationsEnabled) { _, isOn in
                dailyAffirmationsChanged(isOn)
            }
            .onChange(of: iCloudBackupEnabled) { _, isOn in
                iCloudBackupChanged(isOn)
            }
            .onChange(of: weeklyDigestEnabled) { _, isOn in
                if isOn {
                    // Placeholder figures. Home reschedules with the real streak and score
                    // the next time it recomputes metrics, which is on its next appearance.
                    services.notifications.scheduleWeeklySummary(streak: 0, score: 0)
                } else {
                    services.notifications.clearWeeklySummary()
                }
            }
            .onChange(of: stiReminderEnabled) { _, isOn in
                if isOn {
                    let dueDate = Calendar.current.date(byAdding: .month, value: stiReminderMonths, to: .now) ?? .now
                    services.notifications.scheduleSTIReminder(dueDate: dueDate)
                } else {
                    services.notifications.clearSTIReminder()
                }
            }
            // Push Apple Watch preference changes immediately (previously they
            // only reached the watch once, at session activation). One combined
            // observer keeps the modifier chain within the type-checker's budget.
            .onChange(of: watchSettingsFingerprint) { _, _ in services.watch.sendSettings() }
            .endEditingOnTap()
        }
    }

    @ViewBuilder
    private var settingsCategoryList: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Settings")
                    .font(.largeTitle.bold())
                    .foregroundStyle(palette.heroText)

                Text("Locks, alerts, look, and your data")
                    .font(.callout)
                    .foregroundStyle(palette.heroSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)

            VStack(spacing: 20) {
                ForEach(SettingsGroup.allCases) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                            .padding(.leading, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(group.pages.enumerated()), id: \.element.id) { index, page in
                                if index > 0 {
                                    Divider()
                                        .overlay(Color.chillSecondary.opacity(0.18))
                                        .padding(.leading, 56)
                                }

                                NavigationLink(value: page) {
                                    SettingsCategoryRow(page: page)
                                }
                                .buttonStyle(ChillPlainButtonStyle())
                            }
                        }
                        .glassSurface(radius: 26, tint: .black.opacity(0.04))
                    }
                }
            }

            if isWorking {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Checking permissions")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(Color.chillSecondary)
                .padding(16)
                .glassSurface(radius: 22, tint: .black.opacity(0.04))
            }

            if let message {
                Text(message)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .glassSurface(radius: 22, tint: .black.opacity(0.04))
            }

            Text(appVersionText)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.chillTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
                .accessibilityLabel(Text("App version \(appVersionText)"))
        }
        .padding(20)
        .padding(.bottom, 28)
    }

    @ViewBuilder
    private var notificationsSectionContent: some View {
        SettingsToggleCard(
            title: String(localized: "Notifications"),
            caption: String(localized: "Allow private reminders and health check-in warnings."),
            symbol: "bell.badge.fill",
            isOn: $notificationsEnabled
        )

        SettingsToggleCard(
            title: String(localized: "Safety check-ins during sessions"),
            caption: String(localized: "While a dose timer is running, send more noticeable check-ins with a one-tap way to reach your trusted contact or emergency services if something feels wrong."),
            symbol: "shield.lefthalf.filled",
            isOn: $safetyCheckInsEnabled
        )

        SettingsToggleCard(
            title: String(localized: "Weekend night check-ins"),
            caption: String(localized: "On Friday and Saturday nights (12 to 6 am), a discreet passive check-in with one-tap “I'm safe” or “Get help”. Sent when a session is most likely."),
            symbol: "moon.stars.fill",
            isOn: Binding(
                get: { weekendSafetyEnabled },
                set: { newValue in
                    weekendSafetyEnabled = newValue
                    if newValue {
                        services.notifications.scheduleWeekendSafetyCheckIns()
                    } else {
                        services.notifications.clearWeekendSafetyCheckIns()
                    }
                }
            )
        )

        SettingsToggleCard(
            title: String(localized: "Daily affirmations"),
            caption: String(localized: "Send a small confidence boost for recovery, substance-free days, and strong daily scores."),
            symbol: "sparkles",
            isOn: $dailyAffirmationsEnabled
        )

        CheckInTimeCard(time: checkInTimeBinding)

        SettingsToggleCard(
            title: String(localized: "Discreet notification text"),
            caption: String(localized: "Use vague lock-screen wording and show details only after opening ChillMate."),
            symbol: "eye.slash.fill",
            isOn: $discreetNotifications
        )

        NotificationToneCard(selectedTone: $notificationTone)

        SettingsToggleCard(
            title: String(localized: "Weekly summary"),
            caption: String(localized: "Sunday evening digest of your streak, score, and recent logs."),
            symbol: "calendar.badge.clock",
            isOn: $weeklyDigestEnabled
        )

        SettingsToggleCard(
            title: String(localized: "STI test reminders"),
            caption: String(localized: "Remind you to get tested on a regular schedule."),
            symbol: "cross.case.fill",
            isOn: $stiReminderEnabled
        )

        if stiReminderEnabled {
            STIReminderIntervalCard(selectedMonths: $stiReminderMonths)
        }
    }

    @ViewBuilder
    private func settingsPage(_ page: SettingsSectionPage) -> some View {
        ZStack {
            DashboardBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(
                        title: page.localizedDisplayName,
                        subtitle: page.subtitle,
                        symbol: page.symbol,
                        tint: Color.chillPrimary
                    )

                    switch page {
                    case .privacy:
                        SettingsToggleCard(
                            title: String(localized: "Lock with Face ID"),
                            caption: String(localized: "Ask for Face ID whenever the app is opened."),
                            symbol: "faceid",
                            isOn: $requiresFaceID
                        )

                        PINLockCard(
                            isEnabled: requiresPIN,
                            setPIN: {
                                isShowingPINSetup = true
                            },
                            turnOff: {
                                isShowingDisablePINAlert = true
                            }
                        )

                        // Only offered once there is a real PIN to be distinct
                        // from. Without one there is nothing for a second PIN to
                        // mean.
                        if requiresPIN {
                            DuressPINCard(
                                isEnabled: hasDuressPIN,
                                setPIN: { isShowingDuressSetup = true },
                                turnOff: {
                                    LocalSecurityService.clearDuressPIN()
                                    hasDuressPIN = false
                                    message = String(localized: "Second PIN removed.")
                                }
                            )
                        }

                        SettingsToggleCard(
                            title: String(localized: "Extra app security"),
                            caption: String(localized: "Locks your private files even when the app is closed. Useful if your phone is ever lost or stolen."),
                            symbol: "lock.doc.fill",
                            isOn: $localEncryptionEnabled
                        )

                        AutoLockTimeoutCard(selectedMinutes: $autoLockMinutes)

                        SettingsToggleCard(
                            title: String(localized: "Hide contents from screenshots"),
                            caption: String(localized: "Cover the app in the App Switcher and while your screen is being recorded or mirrored, so a quick glance never reveals your log."),
                            symbol: "eye.slash.fill",
                            isOn: $screenPrivacyEnabled
                        )

                        EncryptionInfoCard()

                    case .privacyDashboard:
                        PrivacyDashboardCard()

                    case .permissions:
                        SettingsToggleCard(
                            title: String(localized: "Add logs to Apple Health"),
                            caption: String(localized: "Save sex and sleep entries to Apple Health after each log."),
                            symbol: "heart.text.square.fill",
                            isOn: $healthKitAutoSync
                        )

                        GranularHealthKitPermissionsCard(
                            sexualActivityWrite: $healthKitSexualActivityWriteEnabled,
                            sleepReadWrite: $healthKitSleepReadWriteEnabled,
                            heartRateRead: $healthKitHeartRateReadEnabled,
                            hrvRead: $healthKitHRVReadEnabled,
                            workoutRead: $healthKitWorkoutReadEnabled,
                            requestScope: requestHealthScope
                        )

                    case .notifications:
                        notificationsSectionContent

                    case .iCloud:
                        ICloudBackupCard(
                            isEnabled: $iCloudBackupEnabled,
                            status: lastICloudBackupStatus,
                            lastBackupTimestamp: lastICloudBackupTimestamp,
                            isWorking: isWorking,
                            saveNow: saveICloudBackup,
                            restore: restoreICloudBackup,
                            deleteBackups: deleteICloudBackups
                        )

                    case .accessibility:
                        AccessibilityQualityCard(
                            highContrastMode: $highContrastMode,
                            reducedMotion: $chillReducedMotion,
                            oneHandedControls: $oneHandedControls
                        )

                    case .appearance:
                        BackgroundLibraryCard(
                            selectedStyle: $appBackgroundStyle,
                            selectedPhoto: $selectedBackgroundPhoto,
                            updatePhoto: updateBackgroundPhoto
                        )

                    case .goals:
                        ReductionGoalCard(
                            goalSessions: $reductionGoalSessions,
                            substanceOnly: $reductionGoalCountSubstanceOnly
                        )

                    case .watch:
                        WatchCompanionSettingsCard(
                            hydrationReminders: $watchHydrationReminders,
                            heartRateWarnings: $watchHeartRateWarnings,
                            breathingHaptics: $watchBreathingHaptics,
                            discreetCheckIns: $watchDiscreetCheckIns,
                            visibleTimers: $watchVisibleTimers,
                            stressAndTemperatureDetection: $watchStressAndTemperatureDetection
                        )

                    case .shortcuts:
                        SiriShortcutsCard()

                    case .quality:
                        ClinicalReviewSettingsCard()

                    case .account:
                        EncryptedBackupCard(
                            backupURL: encryptedBackupURL,
                            isWorking: isWorking,
                            prepareBackup: prepareEncryptedBackup,
                            importBackup: {
                                isShowingBackupImporter = true
                            }
                        )

                        CSVExportCard(isWorking: isWorking, export: exportCSV)

                        TipView(AutomaticRetentionTip())

                        DataRetentionCard(
                            selectedMonths: $dataRetentionMonths,
                            isAutomatic: $dataRetentionAutomatic,
                            applyRetention: applyDataRetention
                        )

                        DeleteAccountCard {
                            isShowingDeleteWarning = true
                        }
                    }

                    if let message {
                        Text(message)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.chillSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .glassSurface(radius: 22, tint: .black.opacity(0.04))
                    }
                }
                .padding(20)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .liquidGlassAlert(
            isPresented: $isShowingDisablePINAlert,
            title: String(localized: "Turn off PIN lock?"),
            message: String(localized: "ChillMate will no longer ask for your PIN. Face ID stays on if it is enabled."),
            primaryTitle: String(localized: "Turn off PIN"),
            primaryIsDestructive: true,
            primaryAction: {
                requiresPIN = false
                LocalSecurityService.clearPIN()
                message = String(localized: "PIN lock is off.")
            },
            secondaryTitle: String(localized: "Keep PIN")
        )
        .liquidGlassAlert(
            isPresented: $isShowingDeleteWarning,
            title: String(localized: "Delete account and all data?"),
            message: String(localized: "This will delete your profile and every log stored by ChillMate on this device."),
            primaryTitle: String(localized: "Continue to final check"),
            primaryIsDestructive: true,
            primaryAction: {
                isShowingFinalDeleteCheck = true
            },
            secondaryTitle: String(localized: "Cancel")
        )
        .fullScreenCover(isPresented: $isShowingFinalDeleteCheck) {
            DeleteAccountConfirmationView {
                await deleteAccountAndData()
            }
        }
        .fullScreenCover(isPresented: $isShowingPINSetup) {
            PINSetupView(isChangingExistingPIN: requiresPIN) { newPIN in
                LocalSecurityService.savePINToKeychain(pin: newPIN)
                requiresPIN = true
                message = String(localized: "PIN lock is on.")
            }
        }
        .fullScreenCover(isPresented: $isShowingDuressSetup) {
            PINSetupView(isChangingExistingPIN: hasDuressPIN, isDuress: true) { newPIN in
                LocalSecurityService.saveDuressPIN(newPIN)
                hasDuressPIN = true
                message = String(localized: "Second PIN is set.")
            }
        }
        .fileImporter(
            isPresented: $isShowingBackupImporter,
            allowedContentTypes: [UTType(filenameExtension: "cmbak") ?? .data, .data, .json],
            allowsMultipleSelection: false,
            onCompletion: handleBackupImport
        )
        .endEditingOnTap()
    }

    private func faceIDLockChanged(_ isOn: Bool) {
        if !isOn {
            if isRevertingToggle {
                isRevertingToggle = false
                return
            }

            message = nil
            return
        }

        isWorking = true
        Task {
            do {
                let success = try await AppAuthenticator.authenticate(reason: String(localized: "Protect ChillMate with Face ID"))
                await MainActor.run {
                    isRevertingToggle = !success
                    requiresFaceID = success
                    message = success ? "Face ID lock is on." : "Face ID could not be enabled."
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    isRevertingToggle = true
                    requiresFaceID = false
                    message = error.localizedDescription
                    isWorking = false
                }
            }
        }
    }

    private func localEncryptionChanged(_ isOn: Bool) {
        if isOn {
            LocalSecurityService.applyFileProtection()
            message = String(localized: "Extra security is on. Your private files are locked while ChillMate is closed.")
        } else {
            message = String(localized: "Extra security is off. Your iPhone still applies its built-in protection.")
        }
    }

    private func healthKitSyncChanged(_ isOn: Bool) {
        if !isOn {
            if isRevertingToggle {
                isRevertingToggle = false
                return
            }

            message = nil
            return
        }

        isWorking = true
        Task {
            do {
                try await services.health.requestAuthorization()
                await MainActor.run {
                    healthKitAutoSync = true
                    healthKitSexualActivityWriteEnabled = true
                    healthKitSleepReadWriteEnabled = true
                    message = String(localized: "Apple Health export is on for new logs.")
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    isRevertingToggle = true
                    healthKitAutoSync = false
                    message = error.localizedDescription
                    isWorking = false
                }
            }
        }
    }

    private func requestHealthScope(_ scope: HealthKitPermissionScope) {
        isWorking = true
        Task {
            do {
                try await services.health.requestAuthorization(scopes: [scope])
                await MainActor.run {
                    setHealthScope(scope, enabled: true)
                    message = String(localized: "\(scope.localizedDisplayName) is enabled.")
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    setHealthScope(scope, enabled: false)
                    message = error.localizedDescription
                    isWorking = false
                }
            }
        }
    }

    private func setHealthScope(_ scope: HealthKitPermissionScope, enabled: Bool) {
        switch scope {
        case .sexualActivityWrite:
            healthKitSexualActivityWriteEnabled = enabled
        case .sleepReadWrite:
            healthKitSleepReadWriteEnabled = enabled
        case .heartRateRead:
            healthKitHeartRateReadEnabled = enabled
        case .heartRateVariabilityRead:
            healthKitHRVReadEnabled = enabled
        case .vitalsRead:
            healthKitVitalsReadEnabled = enabled
        case .mindfulWrite:
            healthKitMindfulWriteEnabled = enabled
        case .workoutRead:
            healthKitWorkoutReadEnabled = enabled
        }
    }

    /// Confirms the person holding the phone before anything moves all of the data
    /// at once.
    ///
    /// The PIN and Face ID gate opening the app, and then four buttons in here
    /// could export, import, restore or hand over the whole store without asking
    /// again. An unlocked phone left on a table was one tap from a complete copy
    /// of someone's drug use and sexual health history.
    ///
    /// Returns true when there is no lock configured at all: someone who has not
    /// asked for a lock has not asked to be challenged, and a prompt they cannot
    /// satisfy would just break export for them.
    private func confirmIdentity(reason: String) async -> Bool {
        guard requiresFaceID || requiresPIN else { return true }
        do {
            return try await AppAuthenticator.authenticate(reason: reason)
        } catch {
            await MainActor.run {
                message = String(localized: "Could not confirm it is you, so nothing was moved.")
            }
            return false
        }
    }

    private func prepareEncryptedBackup() {
        isWorking = true
        message = nil
        Task {
            guard await confirmIdentity(reason: String(localized: "Confirm it is you before preparing a backup")) else {
                await MainActor.run { isWorking = false }
                return
            }
            do {
                let data = try services.encryptedBackups.encryptedBackupData(localContext: modelContext)
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                let stamp = formatter.string(from: .now)
                    .replacingOccurrences(of: ":", with: "-")
                let fileName = "ChillMate-Encrypted-Backup-\(stamp).cmbak"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try data.write(to: url, options: [.atomic, .completeFileProtection])

                await MainActor.run {
                    encryptedBackupURL = url
                    message = String(localized: "Encrypted backup prepared.")
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    message = String(localized: "Could not create encrypted backup: \(error.localizedDescription)")
                    isWorking = false
                }
            }
        }
    }

    private func handleBackupImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importBackup(from: url)
        case .failure(let error):
            message = error.localizedDescription
        }
    }

    private func importBackup(from url: URL) {
        isWorking = true
        message = nil

        Task {
            guard await confirmIdentity(reason: String(localized: "Confirm it is you before replacing your data")) else {
                await MainActor.run { isWorking = false }
                return
            }
            do {
                let canAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if canAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let data = try Data(contentsOf: url)
                let summary = try services.encryptedBackups.importEncryptedBackupData(data, into: modelContext)

                await MainActor.run {
                    message = summary.displayText
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    message = String(localized: "Could not import backup: \(error.localizedDescription)")
                    isWorking = false
                }
            }
        }
    }

    private func notificationsChanged(_ isOn: Bool) {
        if !isOn {
            if isRevertingToggle {
                isRevertingToggle = false
                return
            }

            services.notifications.clearScheduledNotifications()
            dailyAffirmationsEnabled = false
            message = nil
            return
        }

        isWorking = true
        Task {
            do {
                let granted = try await services.notifications.requestAuthorization()
                await MainActor.run {
                    isRevertingToggle = !granted
                    notificationsEnabled = granted
                    if granted {
                        services.notifications.scheduleCheckInReminder()
                        services.notifications.scheduleInactivityReminders()
                        if dailyAffirmationsEnabled {
                            services.notifications.scheduleDailyAffirmations()
                        }
                    }
                    message = granted ? "Notifications are on." : "Notification permission was not granted."
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    isRevertingToggle = true
                    notificationsEnabled = false
                    message = error.localizedDescription
                    isWorking = false
                }
            }
        }
    }

    private func iCloudBackupChanged(_ isOn: Bool) {
        if !isOn {
            if isRevertingToggle {
                isRevertingToggle = false
                return
            }

            message = String(localized: "iCloud backup is off. Local encrypted recovery stays available on this iPhone.")
            return
        }

        guard services.cloudBackups.isAvailable else {
            isRevertingToggle = true
            iCloudBackupEnabled = false
            message = ICloudBackupError.iCloudUnavailable.localizedDescription
            return
        }

        lastICloudBackupStatus = services.cloudBackups.statusLine
        message = String(localized: "iCloud backup is on. ChillMate saves encrypted backup files to your iCloud Drive.")
    }

    private func saveICloudBackup() {
        guard iCloudBackupEnabled else {
            message = String(localized: "Turn on iCloud backup first.")
            return
        }

        isWorking = true
        message = nil
        Task {
            do {
                let date = try services.cloudBackups.saveLatestBackup(localContext: modelContext)
                await MainActor.run {
                    lastICloudBackupTimestamp = date.timeIntervalSince1970
                    // The service already wrote the durable status line, translated.
                    // Restating it here in an English literal is what overwrote that
                    // translation, so the call site now sets only the transient
                    // confirmation. Same rule in the restore and delete paths below.
                    let stamp = date.formatted(date: .abbreviated, time: .shortened)
                    message = String(localized: "Encrypted iCloud backup saved \(stamp).")
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    // Do NOT write error to lastICloudBackupStatus. It is a shared key
                    // shown across views and would propagate the error everywhere.
                    message = String(localized: "Could not save to iCloud: \(error.localizedDescription)")
                    isWorking = false
                }
            }
        }
    }

    private func restoreICloudBackup() {
        isWorking = true
        message = nil
        Task {
            guard await confirmIdentity(reason: String(localized: "Confirm it is you before replacing your data")) else {
                await MainActor.run { isWorking = false }
                return
            }
            do {
                let summary = try services.cloudBackups.restoreLatestBackup(into: modelContext)
                await MainActor.run {
                    message = String(localized: "Restored from iCloud. \(summary.displayText)")
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    // Do NOT write error to lastICloudBackupStatus, keep errors local.
                    message = String(localized: "Could not restore from iCloud: \(error.localizedDescription)")
                    isWorking = false
                }
            }
        }
    }

    private func deleteICloudBackups() {
        isWorking = true
        message = nil
        Task {
            do {
                try services.cloudBackups.deleteBackups()
                await MainActor.run {
                    lastICloudBackupTimestamp = 0
                    message = String(localized: "iCloud backups deleted.")
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    message = String(localized: "Could not delete iCloud backups: \(error.localizedDescription)")
                    isWorking = false
                }
            }
        }
    }

    private func dailyAffirmationsChanged(_ isOn: Bool) {
        if !isOn {
            if isRevertingToggle {
                isRevertingToggle = false
                return
            }

            services.notifications.clearDailyAffirmations()
            message = nil
            return
        }

        if notificationsEnabled {
            services.notifications.scheduleDailyAffirmations()
            message = String(localized: "Daily affirmations are on.")
            return
        }

        isWorking = true
        Task {
            do {
                let granted = try await services.notifications.requestAuthorization()
                await MainActor.run {
                    isRevertingToggle = !granted
                    notificationsEnabled = granted
                    dailyAffirmationsEnabled = granted
                    if granted {
                        services.notifications.scheduleCheckInReminder()
                        services.notifications.scheduleInactivityReminders()
                        services.notifications.scheduleDailyAffirmations()
                    }
                    message = granted ? "Daily affirmations are on." : "Notification permission was not granted."
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    isRevertingToggle = true
                    dailyAffirmationsEnabled = false
                    message = error.localizedDescription
                    isWorking = false
                }
            }
        }
    }

    private func updateBackgroundPhoto(_ item: PhotosPickerItem?) {
        guard let item else {
            return
        }

        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                return
            }

            let optimizedData = await ChillImageOptimizer.downsampledJPEG(from: data, maxPixelSize: 1400, compressionQuality: 0.84)
            // Written to a protected file rather than base64'd into UserDefaults;
            // only the fingerprint goes to defaults, which is what drives the
            // backdrop's reload.
            let fingerprint = BackgroundPhotoStore.save(optimizedData)
            ChillBackgroundImageCache.removeAll()
            backgroundPhotoFingerprint = fingerprint
            appBackgroundStyle = ChillBackgroundStyle.photo.rawValue
            message = String(localized: "Background photo updated.")
        }
    }

    private func exportCSV() {
        isWorking = true
        message = nil
        Task {
            guard await confirmIdentity(reason: String(localized: "Confirm it is you before exporting your data")) else {
                await MainActor.run { isWorking = false }
                return
            }
            do {
                let entries = try modelContext.fetch(FetchDescriptor<NightEntry>(sortBy: [SortDescriptor(\.date)]))
                var csv = "Date,StartDate,EndDate,HadSex,SkippedNight,Substances,PartnerCount,UsedCondom,WasPenetrated,SleptYet,SleepHours,Note\n"
                for entry in entries {
                    let row = [
                        entry.date.formatted(.iso8601),
                        entry.startDate.formatted(.iso8601),
                        entry.endDate.formatted(.iso8601),
                        entry.hadSex ? "true" : "false",
                        entry.skippedNight ? "true" : "false",
                        entry.substances.joined(separator: "|"),
                        "\(entry.partnerCount)",
                        entry.usedCondom ? "true" : "false",
                        entry.wasPenetrated ? "true" : "false",
                        entry.sleptYet ? "true" : "false",
                        entry.sleepHours > 0 ? entry.sleepHours.formatted(.number.precision(.fractionLength(1))) : "",
                        "\"\(entry.note.replacingOccurrences(of: "\"", with: "\"\""))\""
                    ].joined(separator: ",")
                    csv += row + "\n"
                }
                let data = Data(csv.utf8)
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                let stamp = formatter.string(from: .now).replacingOccurrences(of: ":", with: "-")
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("ChillMate-Export-\(stamp).csv")
                try data.write(to: url, options: [.atomic, .completeFileProtection])
                await MainActor.run {
                    encryptedBackupURL = url
                    message = String(localized: "CSV export ready. Use the Share button to save it.")
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    message = String(localized: "Could not create CSV: \(error.localizedDescription)")
                    isWorking = false
                }
            }
        }
    }

    private func applyDataRetention() {
        guard dataRetentionMonths > 0 else { return }
        let cutoff = Calendar.current.date(byAdding: .month, value: -dataRetentionMonths, to: .now) ?? .now
        isWorking = true
        Task {
            do {
                let old = try modelContext.fetch(FetchDescriptor<NightEntry>()).filter { $0.date < cutoff }
                for entry in old { modelContext.delete(entry) }
                try modelContext.save()
                await MainActor.run {
                    message = String(localized: "Deleted \(old.count) entries older than \(dataRetentionMonths) months.")
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    message = String(localized: "Could not apply retention: \(error.localizedDescription)")
                    isWorking = false
                }
            }
        }
    }

    private func deleteAccountAndData() async -> Bool {
        isWorking = true
        message = nil

        do {
            try AccountDataDeletion.deleteAllData(currentContext: modelContext)
            services.notifications.clearScheduledNotifications()
            requiresFaceID = false
            requiresPIN = false
            healthKitAutoSync = false
            notificationsEnabled = false
            dailyAffirmationsEnabled = false
            AccountDataDeletion.clearStoredSettings()
            isWorking = false
            dismiss()
            return true
        } catch {
            message = String(localized: "ChillMate could not delete everything: \(error.localizedDescription)")
            isWorking = false
            return false
        }
    }
}

private struct DuressPINCard: View {
    let isEnabled: Bool
    let setPIN: () -> Void
    let turnOff: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(String(localized: "Second PIN"), systemImage: "lock.square.stack")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("A second PIN that opens the app with nothing in it. It unlocks exactly like your real one, with no warning and nothing on screen to say which you used. Your data is untouched and your real PIN brings it straight back.")
                .font(.caption)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(isEnabled ? String(localized: "Change") : String(localized: "Set up"), action: setPIN)
                    .buttonStyle(ChillPillButtonStyle(prominent: !isEnabled))

                if isEnabled {
                    Button(String(localized: "Turn off"), role: .destructive, action: turnOff)
                        .buttonStyle(ChillPillButtonStyle())
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(radius: 26, tint: Color.chillPrimary.opacity(0.07))
    }
}
