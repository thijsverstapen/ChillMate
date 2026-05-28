import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private enum SettingsSectionPage: String, CaseIterable, Identifiable {
    case privacy = "Privacy & lock"
    case privacyDashboard = "Privacy dashboard"
    case permissions = "Permissions"
    case notifications = "Notifications"
    case iCloud = "iCloud backup"
    case accessibility = "Accessibility"
    case appearance = "Appearance"
    case watch = "Apple Watch"
    case quality = "Safety review"
    case account = "Account data"

    var id: String { rawValue }

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
        case .quality:
            "checkmark.seal.text.page.fill"
        case .account:
            "person.crop.circle.badge.xmark"
        }
    }

    var subtitle: String {
        switch self {
        case .privacy:
            "Face ID, PIN, and local protection"
        case .privacyDashboard:
            "What is stored, exported, and never shared"
        case .permissions:
            "Health and system access"
        case .notifications:
            "Check-ins and affirmations"
        case .iCloud:
            "Encrypted backup and restore"
        case .accessibility:
            "Readable, calm, and one-handed app behavior"
        case .appearance:
            "Adaptive background and photos"
        case .watch:
            "Companion preferences"
        case .quality:
            "Medical wording, evidence limits, and review status"
        case .account:
            "Export backup, delete account, and stored data"
        }
    }
}

@MainActor
struct SettingsView: View {
    @AppStorage("requiresFaceID") private var requiresFaceID = false
    @AppStorage("requiresPIN") private var requiresPIN = false
    @AppStorage("appPINHash") private var appPINHash = ""
    @AppStorage("appPINSalt") private var appPINSalt = ""
    @AppStorage("localEncryptionEnabled") private var localEncryptionEnabled = true
    @AppStorage("healthKitAutoSync") private var healthKitAutoSync = false
    @AppStorage("healthKitSexualActivityWriteEnabled") private var healthKitSexualActivityWriteEnabled = false
    @AppStorage("healthKitSleepReadWriteEnabled") private var healthKitSleepReadWriteEnabled = false
    @AppStorage("healthKitHeartRateReadEnabled") private var healthKitHeartRateReadEnabled = false
    @AppStorage("healthKitHRVReadEnabled") private var healthKitHRVReadEnabled = false
    @AppStorage("healthKitWorkoutReadEnabled") private var healthKitWorkoutReadEnabled = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("dailyAffirmationsEnabled") private var dailyAffirmationsEnabled = false
    @AppStorage("discreetNotifications") private var discreetNotifications = true
    @AppStorage("notificationTone") private var notificationTone = NotificationTone.gentle.rawValue
    @AppStorage("iCloudBackupEnabled") private var iCloudBackupEnabled = false
    @AppStorage("lastICloudBackupStatus") private var lastICloudBackupStatus = ""
    @AppStorage("lastICloudBackupTimestamp") private var lastICloudBackupTimestamp = 0.0
    @AppStorage("highContrastMode") private var highContrastMode = false
    @AppStorage("chillReducedMotion") private var chillReducedMotion = false
    @AppStorage("oneHandedControls") private var oneHandedControls = true
    @AppStorage("appBackgroundStyle") private var appBackgroundStyle = ChillBackgroundStyle.score.rawValue
    @AppStorage("appBackgroundPhotoData") private var appBackgroundPhotoData = ""
    @AppStorage("lastDailyRecoveryScore") private var lastDailyRecoveryScore = 42
    @AppStorage("watchHydrationReminders") private var watchHydrationReminders = true
    @AppStorage("watchHeartRateWarnings") private var watchHeartRateWarnings = true
    @AppStorage("watchBreathingHaptics") private var watchBreathingHaptics = true
    @AppStorage("watchDiscreetCheckIns") private var watchDiscreetCheckIns = true
    @AppStorage("watchVisibleTimers") private var watchVisibleTimers = true
    @AppStorage("watchStressAndTemperatureDetection") private var watchStressAndTemperatureDetection = false

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
    @State private var settingsPath: [SettingsSectionPage] = []
    @State private var encryptedBackupURL: URL?
    @State private var isShowingBackupImporter = false

    let showsDoneButton: Bool

    init(showsDoneButton: Bool = true) {
        self.showsDoneButton = showsDoneButton
    }

    private var palette: DailyScorePalette {
        DailyScorePalette(score: lastDailyRecoveryScore)
    }

    var body: some View {
        NavigationStack(path: $settingsPath) {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Privacy & lock")
                                .font(.largeTitle.bold())
                                .foregroundStyle(palette.heroText)

                            Text("Choose how ChillMate protects private logs and which system features can use them.")
                                .font(.callout)
                                .foregroundStyle(palette.heroSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 8)

                        VStack(spacing: 12) {
                            ForEach(SettingsSectionPage.allCases) { page in
                                NavigationLink(value: page) {
                                    SettingsCategoryCard(page: page)
                                }
                                .buttonStyle(.plain)
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
                            .glassSurface(radius: 22, tint: .white.opacity(0.26))
                        }

                        if let message {
                            Text(message)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Color.chillSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(16)
                                .glassSurface(radius: 22, tint: .white.opacity(0.26))
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SettingsSectionPage.self) { page in
                settingsPage(page)
            }
            .toolbar {
                if showsDoneButton && settingsPath.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        BackChevronButton {
                            dismiss()
                        }
                    }
                }
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
            .edgeSwipeToDismiss()
            .endEditingOnTap()
        }
    }

    @ViewBuilder
    private func settingsPage(_ page: SettingsSectionPage) -> some View {
        ZStack {
            DashboardBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(
                        title: page.rawValue,
                        subtitle: page.subtitle,
                        symbol: page.symbol,
                        tint: Color.chillPrimary
                    )

                    switch page {
                    case .privacy:
                        SettingsToggleCard(
                            title: "Lock with Face ID",
                            caption: "Ask for Face ID whenever the app is opened.",
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

                        SettingsToggleCard(
                            title: "Local encryption",
                            caption: "Protect local ChillMate files with complete iOS data protection while your phone is locked.",
                            symbol: "lock.doc.fill",
                            isOn: $localEncryptionEnabled
                        )

                        EncryptionInfoCard()

                    case .privacyDashboard:
                        PrivacyDashboardCard()

                    case .permissions:
                        SettingsToggleCard(
                            title: "Add logs to Apple Health",
                            caption: "Save sex and sleep entries to Apple Health after each log.",
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
                        SettingsToggleCard(
                            title: "Notifications",
                            caption: "Allow private reminders and health check-in warnings.",
                            symbol: "bell.badge.fill",
                            isOn: $notificationsEnabled
                        )

                        SettingsToggleCard(
                            title: "Daily affirmations",
                            caption: "Send a small confidence boost for recovery, drug-free days, and strong daily scores.",
                            symbol: "sparkles",
                            isOn: $dailyAffirmationsEnabled
                        )

                        SettingsToggleCard(
                            title: "Discreet notification text",
                            caption: "Use vague lock-screen wording and show details only after opening ChillMate.",
                            symbol: "eye.slash.fill",
                            isOn: $discreetNotifications
                        )

                        NotificationToneCard(selectedTone: $notificationTone)

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

                    case .watch:
                        WatchCompanionSettingsCard(
                            hydrationReminders: $watchHydrationReminders,
                            heartRateWarnings: $watchHeartRateWarnings,
                            breathingHaptics: $watchBreathingHaptics,
                            discreetCheckIns: $watchDiscreetCheckIns,
                            visibleTimers: $watchVisibleTimers,
                            stressAndTemperatureDetection: $watchStressAndTemperatureDetection
                        )

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
                            .glassSurface(radius: 22, tint: .white.opacity(0.26))
                    }
                }
                .padding(20)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .liquidGlassAlert(
            isPresented: $isShowingDisablePINAlert,
            title: "Turn off PIN lock?",
            message: "ChillMate will no longer ask for your PIN. Face ID stays on if it is enabled.",
            primaryTitle: "Turn off PIN",
            primaryIsDestructive: true,
            primaryAction: {
                requiresPIN = false
                LocalSecurityService.clearPIN()
                message = "PIN lock is off."
            },
            secondaryTitle: "Keep PIN"
        )
        .liquidGlassAlert(
            isPresented: $isShowingDeleteWarning,
            title: "Delete account and all data?",
            message: "This will delete your profile and every log stored by ChillMate on this device.",
            primaryTitle: "Continue to final check",
            primaryIsDestructive: true,
            primaryAction: {
                isShowingFinalDeleteCheck = true
            },
            secondaryTitle: "Cancel"
        )
        .fullScreenCover(isPresented: $isShowingFinalDeleteCheck) {
            DeleteAccountConfirmationView {
                await deleteAccountAndData()
            }
        }
        .fullScreenCover(isPresented: $isShowingPINSetup) {
            PINSetupView(isChangingExistingPIN: requiresPIN) { newPIN in
                let credentials = LocalSecurityService.makePINCredentials(pin: newPIN)
                appPINHash = credentials.hash
                appPINSalt = credentials.salt
                requiresPIN = true
                message = "PIN lock is on."
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
                let success = try await AppAuthenticator.authenticate(reason: "Protect ChillMate with Face ID")
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
            message = "Local encryption is on. ChillMate protects app files with complete iOS data protection when your phone is locked."
        } else {
            message = "Extra local file protection is off. Your iPhone still applies its normal system protection."
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
                try await HealthKitService.shared.requestAuthorization()
                await MainActor.run {
                    healthKitAutoSync = true
                    healthKitSexualActivityWriteEnabled = true
                    healthKitSleepReadWriteEnabled = true
                    message = "Apple Health export is on for new logs."
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
                try await HealthKitService.shared.requestAuthorization(scopes: [scope])
                await MainActor.run {
                    setHealthScope(scope, enabled: true)
                    message = "\(scope.rawValue) is enabled."
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
        case .workoutRead:
            healthKitWorkoutReadEnabled = enabled
        }
    }

    private func prepareEncryptedBackup() {
        isWorking = true
        message = nil
        Task {
            do {
                let data = try EncryptedBackupService.shared.encryptedBackupData(localContext: modelContext)
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                let stamp = formatter.string(from: .now)
                    .replacingOccurrences(of: ":", with: "-")
                let fileName = "ChillMate-Encrypted-Backup-\(stamp).cmbak"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try data.write(to: url, options: [.atomic, .completeFileProtection])

                await MainActor.run {
                    encryptedBackupURL = url
                    message = "Encrypted backup prepared."
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    message = "Could not create encrypted backup: \(error.localizedDescription)"
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
            do {
                let canAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if canAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let data = try Data(contentsOf: url)
                let summary = try EncryptedBackupService.shared.importEncryptedBackupData(data, into: modelContext)

                await MainActor.run {
                    message = summary.displayText
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    message = "Could not import backup: \(error.localizedDescription)"
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

            NotificationService.shared.clearScheduledNotifications()
            dailyAffirmationsEnabled = false
            message = nil
            return
        }

        isWorking = true
        Task {
            do {
                let granted = try await NotificationService.shared.requestAuthorization()
                await MainActor.run {
                    isRevertingToggle = !granted
                    notificationsEnabled = granted
                    if granted {
                        NotificationService.shared.scheduleCheckInReminder()
                        NotificationService.shared.scheduleInactivityReminders()
                        if dailyAffirmationsEnabled {
                            NotificationService.shared.scheduleDailyAffirmations()
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

            message = "iCloud backup is off. Local encrypted recovery stays available on this iPhone."
            return
        }

        guard ICloudBackupService.shared.isAvailable else {
            isRevertingToggle = true
            iCloudBackupEnabled = false
            message = ICloudBackupError.iCloudUnavailable.localizedDescription
            return
        }

        lastICloudBackupStatus = ICloudBackupService.shared.statusLine
        message = "iCloud backup is on. ChillMate saves encrypted backup files to your iCloud Drive."
    }

    private func saveICloudBackup() {
        guard iCloudBackupEnabled else {
            message = "Turn on iCloud backup first."
            return
        }

        isWorking = true
        message = nil
        Task {
            do {
                let date = try ICloudBackupService.shared.saveLatestBackup(localContext: modelContext)
                await MainActor.run {
                    lastICloudBackupTimestamp = date.timeIntervalSince1970
                    lastICloudBackupStatus = "Encrypted iCloud backup saved \(date.formatted(date: .abbreviated, time: .shortened))."
                    message = lastICloudBackupStatus
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    lastICloudBackupStatus = error.localizedDescription
                    message = "Could not save to iCloud: \(error.localizedDescription)"
                    isWorking = false
                }
            }
        }
    }

    private func restoreICloudBackup() {
        isWorking = true
        message = nil
        Task {
            do {
                let summary = try ICloudBackupService.shared.restoreLatestBackup(into: modelContext)
                await MainActor.run {
                    lastICloudBackupStatus = summary.displayText
                    message = "Restored from iCloud. \(summary.displayText)"
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    lastICloudBackupStatus = error.localizedDescription
                    message = "Could not restore from iCloud: \(error.localizedDescription)"
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
                try ICloudBackupService.shared.deleteBackups()
                await MainActor.run {
                    lastICloudBackupTimestamp = 0
                    lastICloudBackupStatus = "iCloud backups deleted."
                    message = lastICloudBackupStatus
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    message = "Could not delete iCloud backups: \(error.localizedDescription)"
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

            NotificationService.shared.clearDailyAffirmations()
            message = nil
            return
        }

        if notificationsEnabled {
            NotificationService.shared.scheduleDailyAffirmations()
            message = "Daily affirmations are on."
            return
        }

        isWorking = true
        Task {
            do {
                let granted = try await NotificationService.shared.requestAuthorization()
                await MainActor.run {
                    isRevertingToggle = !granted
                    notificationsEnabled = granted
                    dailyAffirmationsEnabled = granted
                    if granted {
                        NotificationService.shared.scheduleCheckInReminder()
                        NotificationService.shared.scheduleInactivityReminders()
                        NotificationService.shared.scheduleDailyAffirmations()
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

            let optimizedData = await Task.detached(priority: .utility) {
                ChillImageOptimizer.downsampledJPEGData(from: data, maxPixelSize: 1400, compressionQuality: 0.84)
            }.value

            await MainActor.run {
                appBackgroundPhotoData = optimizedData.base64EncodedString()
                appBackgroundStyle = ChillBackgroundStyle.photo.rawValue
                message = "Background photo updated."
            }
        }
    }

    private func deleteAccountAndData() async -> Bool {
        isWorking = true
        message = nil

        do {
            try AccountDataDeletion.deleteAllData(currentContext: modelContext)
            NotificationService.shared.clearScheduledNotifications()
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
            message = "ChillMate could not delete everything: \(error.localizedDescription)"
            isWorking = false
            return false
        }
    }
}

private struct SettingsToggleCard: View {
    let title: String
    let caption: String
    let symbol: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isOn ? Color.chillPrimary : Color.chillSecondary)
                    .frame(width: 42, height: 42)
                    .glassSurface(radius: 21, tint: (isOn ? Color.chillPrimary : Color.black).opacity(0.10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.chillText)

                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(.chillPrimary)
        .padding(16)
        .glassSurface(radius: 28, tint: .white.opacity(0.30), interactive: true)
    }
}

private struct SettingsCategoryCard: View {
    let page: SettingsSectionPage

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: page.symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.chillPrimary)
                .frame(width: 42, height: 42)
                .glassSurface(radius: 21, tint: Color.chillPrimary.opacity(0.14))

            VStack(alignment: .leading, spacing: 4) {
                Text(page.rawValue)
                    .font(.headline)
                    .foregroundStyle(Color.chillText)

                Text(page.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillSecondary)
        }
        .padding(16)
        .glassSurface(radius: 26, tint: .white.opacity(0.30), interactive: true)
    }
}

private struct EncryptionInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Encryption default", systemImage: "lock.doc.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("Local protection is on by default. ChillMate can also prepare an AES-GCM encrypted backup archive that stays under your control.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassSurface(radius: 24, tint: Color.chillPrimary.opacity(0.08))
    }
}

private struct PrivacyDashboardCard: View {
    private let rows: [(String, String, String)] = [
        ("Stored on this device", "Profile, logs, STI tests, timers, plans, journal entries, trusted contact, background, and lock settings.", "iphone"),
        ("Encrypted backup", "Created as local backup files or encrypted iCloud Drive backups when you turn those options on.", "externaldrive.badge.lock.fill"),
        ("Shared with Apple Health", "Only the health categories you enable in Permissions.", "heart.text.square.fill"),
        ("Never sent by ChillMate", "Partner messages, emergency texts, and route actions stay user-initiated through iOS apps.", "hand.raised.fill")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Data map")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            ForEach(rows, id: \.0) { row in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: row.2)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.chillVisibleBlue)
                        .frame(width: 38, height: 38)
                        .glassSurface(radius: 19, tint: Color.chillVisibleBlue.opacity(0.10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.0)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.chillText)
                        Text(row.1)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .white.opacity(0.30))
    }
}

private struct GranularHealthKitPermissionsCard: View {
    @Binding var sexualActivityWrite: Bool
    @Binding var sleepReadWrite: Bool
    @Binding var heartRateRead: Bool
    @Binding var hrvRead: Bool
    @Binding var workoutRead: Bool
    let requestScope: (HealthKitPermissionScope) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apple Health categories")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("Enable only the categories you want ChillMate to use. Apple still manages final access in system privacy settings.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HealthPermissionToggleLine(scope: .sexualActivityWrite, isOn: $sexualActivityWrite, requestScope: requestScope)
            HealthPermissionToggleLine(scope: .sleepReadWrite, isOn: $sleepReadWrite, requestScope: requestScope)
            HealthPermissionToggleLine(scope: .heartRateRead, isOn: $heartRateRead, requestScope: requestScope)
            HealthPermissionToggleLine(scope: .heartRateVariabilityRead, isOn: $hrvRead, requestScope: requestScope)
            HealthPermissionToggleLine(scope: .workoutRead, isOn: $workoutRead, requestScope: requestScope)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)
    }
}

private struct HealthPermissionToggleLine: View {
    let scope: HealthKitPermissionScope
    @Binding var isOn: Bool
    let requestScope: (HealthKitPermissionScope) -> Void

    var body: some View {
        Toggle(isOn: Binding(
            get: { isOn },
            set: { newValue in
                isOn = newValue
                if newValue {
                    requestScope(scope)
                }
            }
        )) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: scope.symbolName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isOn ? Color.chillVisibleBlue : Color.chillSecondary)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(scope.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                    Text(scope.caption)
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Color.chillPrimary)
    }
}

private struct NotificationToneCard: View {
    @Binding var selectedTone: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Check-in tone")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("Choose how reminders talk to you. Discreet notifications still keep lock-screen wording vague.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Tone", selection: $selectedTone) {
                ForEach(NotificationTone.allCases) { tone in
                    Text(tone.rawValue).tag(tone.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .tint(Color.chillPrimary)

            Text((NotificationTone(rawValue: selectedTone) ?? .gentle).caption)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillSecondary)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)
    }
}

private struct AccessibilityQualityCard: View {
    @Binding var highContrastMode: Bool
    @Binding var reducedMotion: Bool
    @Binding var oneHandedControls: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Readable by default")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("ChillMate uses Dynamic Type, edge-swipe back navigation, VoiceOver labels on key controls, and reduced animation options for high-stress moments.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            SettingsToggleLine(title: "High contrast overlays", symbol: "circle.lefthalf.filled", isOn: $highContrastMode)
            SettingsToggleLine(title: "Reduce ChillMate animations", symbol: "figure.walk.motion", isOn: $reducedMotion)
            SettingsToggleLine(title: "Prefer bottom actions", symbol: "hand.tap.fill", isOn: $oneHandedControls)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillVisibleBlue.opacity(0.08), interactive: true)
    }
}

private struct ClinicalReviewSettingsCard: View {
    private let rows = [
        "Risk wording uses caution levels instead of claiming a combination is safe.",
        "Drug, STI, PrEP, and emergency content includes source links where practical.",
        "Public release should still receive clinician or harm-reduction professional review before App Store distribution."
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Clinical review layer", systemImage: "checkmark.seal.text.page.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            ForEach(rows, id: \.self) { row in
                Label(row, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("This app can support safer decisions, but it cannot diagnose, treat, or replace emergency or professional medical care.")
                .font(.caption.weight(.bold))
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillVisibleMint.opacity(0.08))
    }
}

private struct EncryptedBackupCard: View {
    @AppStorage("lastOnDeviceRecoveryStatus") private var lastOnDeviceRecoveryStatus = ""
    @AppStorage("lastOnDeviceRecoverySnapshotTimestamp") private var lastOnDeviceRecoverySnapshotTimestamp = 0.0
    let backupURL: URL?
    let isWorking: Bool
    let prepareBackup: () -> Void
    let importBackup: () -> Void

    private var recoveryStatusText: String {
        if lastOnDeviceRecoverySnapshotTimestamp > 0 {
            let date = Date(timeIntervalSince1970: lastOnDeviceRecoverySnapshotTimestamp)
            return "Automatic encrypted on-device recovery is updated when ChillMate moves to the background. Last update: \(date.formatted(date: .abbreviated, time: .shortened))."
        }

        return "Automatic encrypted on-device recovery starts after you have saved local data and the app has moved to the background once."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "lock.doc.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.chillVisibleBlue)
                    .frame(width: 42, height: 42)
                    .glassSurface(radius: 21, tint: Color.chillVisibleBlue.opacity(0.12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Encrypted backup")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)

                    Text("Create an encrypted emergency archive of the local ChillMate data. ChillMate also keeps a protected on-device recovery snapshot for reinstall recovery when iOS keeps the device Keychain.")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(lastOnDeviceRecoveryStatus.isEmpty ? recoveryStatusText : lastOnDeviceRecoveryStatus)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: prepareBackup) {
                HStack {
                    if isWorking {
                        ProgressView()
                    }
                    Label("Prepare encrypted backup", systemImage: "lock.doc.fill")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.chillPrimary)
            .disabled(isWorking)

            Button(action: importBackup) {
                Label("Import backup file", systemImage: "square.and.arrow.down.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.chillVisibleBlue)
            .disabled(isWorking)

            if let backupURL {
                ShareLink(item: backupURL) {
                    Label("Share backup file", systemImage: "square.and.arrow.up.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.chillVisibleBlue)
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillVisibleBlue.opacity(0.08), interactive: true)
    }
}

private struct ICloudBackupCard: View {
    @Binding var isEnabled: Bool
    let status: String
    let lastBackupTimestamp: Double
    let isWorking: Bool
    let saveNow: () -> Void
    let restore: () -> Void
    let deleteBackups: () -> Void

    private var statusText: String {
        if !status.isEmpty {
            return status
        }

        if lastBackupTimestamp > 0 {
            let date = Date(timeIntervalSince1970: lastBackupTimestamp)
            return "Latest encrypted iCloud backup: \(date.formatted(date: .abbreviated, time: .shortened))."
        }

        return "Turn this on to keep an encrypted backup in iCloud Drive and restore it from Settings or setup."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.chillVisibleBlue)
                    .frame(width: 42, height: 42)
                    .glassSurface(radius: 21, tint: Color.chillVisibleBlue.opacity(0.12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Encrypted iCloud backup")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)

                    Text("ChillMate saves an encrypted backup file to your iCloud Drive. Your data is encrypted before it leaves the app.")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Toggle("iCloud backup", isOn: $isEnabled)
                    .labelsHidden()
                    .tint(Color.chillPrimary)
            }

            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: saveNow) {
                    HStack {
                        if isWorking {
                            ProgressView()
                        }
                        Label("Back up now", systemImage: "icloud.and.arrow.up.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.chillPrimary)
                .disabled(isWorking || !isEnabled)

                Button(action: restore) {
                    Label("Restore", systemImage: "icloud.and.arrow.down.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.chillVisibleBlue)
                .disabled(isWorking)
            }

            Button(role: .destructive, action: deleteBackups) {
                Label("Delete iCloud backups", systemImage: "trash.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(isWorking)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillVisibleBlue.opacity(0.08), interactive: true)
    }
}

private struct PINLockCard: View {
    let isEnabled: Bool
    let setPIN: () -> Void
    let turnOff: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "number")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isEnabled ? Color.chillPrimary : Color.chillSecondary)
                    .frame(width: 42, height: 42)
                    .glassSurface(radius: 21, tint: (isEnabled ? Color.chillPrimary : Color.black).opacity(0.10))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Lock with PIN")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)

                    Text(isEnabled ? "PIN lock is enabled. You can change or turn it off." : "Add a 4-8 digit PIN alongside Face ID.")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Spacer(minLength: 0)

                Button(isEnabled ? "Change PIN" : "Set PIN", action: setPIN)
                    .font(.headline)
                    .frame(minWidth: 118)
                    .buttonStyle(.borderedProminent)
                    .tint(.chillPrimary)

                if isEnabled {
                    Button("Turn off", role: .destructive, action: turnOff)
                        .font(.headline)
                        .frame(minWidth: 96)
                        .buttonStyle(.bordered)
                        .tint(.red)
                }
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .white.opacity(0.30), interactive: true)
    }
}

private struct PINSetupView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var pin = ""
    @State private var confirmPIN = ""
    @State private var message: String?
    @State private var isShowingDiscardWarning = false

    let isChangingExistingPIN: Bool
    let save: (String) -> Void

    private var canSave: Bool {
        LocalSecurityService.isValidPIN(pin) && pin == confirmPIN
    }

    private var hasInput: Bool {
        !pin.isEmpty || !confirmPIN.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                VStack(alignment: .leading, spacing: 18) {
                    Spacer(minLength: 20)

                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "number.circle.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Color.chillPrimary)
                            .frame(width: 72, height: 72)
                            .glassSurface(radius: 36, tint: Color.chillPrimary.opacity(0.16))

                        Text(isChangingExistingPIN ? "Change your PIN" : "Set a PIN")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.chillText)

                        Text("Use 4-8 numbers. This PIN unlocks the app on this device and works alongside Face ID.")
                            .font(.callout)
                            .lineSpacing(3)
                            .foregroundStyle(Color.chillSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(22)
                    .glassSurface(radius: 34, tint: .white.opacity(0.28), interactive: true)

                    VStack(spacing: 12) {
                        SecureField("New PIN", text: $pin)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)

                        SecureField("Confirm PIN", text: $confirmPIN)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                    }
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.chillText)
                    .padding(16)
                    .glassSurface(radius: 24, tint: .white.opacity(0.30), interactive: true)
                    .onChange(of: pin) { _, newValue in
                        pin = String(newValue.filter(\.isNumber).prefix(8))
                    }
                    .onChange(of: confirmPIN) { _, newValue in
                        confirmPIN = String(newValue.filter(\.isNumber).prefix(8))
                    }

                    if let message {
                        Text(message)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .glassSurface(radius: 20, tint: .red.opacity(0.10))
                    }

                    GlassActionButton(prominent: true) {
                        guard canSave else {
                            message = pin.count < 4 ? "Use at least 4 numbers." : "The PINs do not match."
                            return
                        }

                        save(pin)
                        dismiss()
                    } label: {
                        Label("Save PIN", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.55)

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BackChevronButton {
                        attemptDismiss()
                    }
                }
            }
            .discardChangesDialog(isPresented: $isShowingDiscardWarning) {
                dismiss()
            }
            .edgeSwipeBack(attemptDismiss)
            .endEditingOnTap()
        }
    }

    private func attemptDismiss() {
        if hasInput {
            isShowingDiscardWarning = true
        } else {
            dismiss()
        }
    }
}

private struct WatchCompanionSettingsCard: View {
    @Binding var hydrationReminders: Bool
    @Binding var heartRateWarnings: Bool
    @Binding var breathingHaptics: Bool
    @Binding var discreetCheckIns: Bool
    @Binding var visibleTimers: Bool
    @Binding var stressAndTemperatureDetection: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Companion app preferences")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("These settings prepare the iPhone side for Apple Watch features: hydration reminders, elevated heart-rate warnings, haptic breathing, discreet check-ins, timer visibility, and future stress/temperature signals.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            SettingsToggleLine(title: "Hydration reminders", symbol: "drop.fill", isOn: $hydrationReminders)
            SettingsToggleLine(title: "Elevated heart-rate warnings", symbol: "heart.fill", isOn: $heartRateWarnings)
            SettingsToggleLine(title: "Breathing haptics", symbol: "lungs.fill", isOn: $breathingHaptics)
            SettingsToggleLine(title: "Discreet haptic check-ins", symbol: "applewatch.radiowaves.left.and.right", isOn: $discreetCheckIns)
            SettingsToggleLine(title: "Visible timers and complications", symbol: "timer", isOn: $visibleTimers)
            SettingsToggleLine(title: "Stress and temperature detection", symbol: "thermometer.medium", isOn: $stressAndTemperatureDetection)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)
    }
}

private struct SettingsToggleLine: View {
    let title: String
    let symbol: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)
        }
        .tint(Color.chillPrimary)
    }
}

private struct BackgroundLibraryCard: View {
    @Binding var selectedStyle: String
    @Binding var selectedPhoto: PhotosPickerItem?
    let updatePhoto: (PhotosPickerItem?) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.chillPrimary)
                    .frame(width: 42, height: 42)
                    .glassSurface(radius: 21, tint: Color.chillPrimary.opacity(0.12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Background")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)

                    Text("Choose a ChillMate gradient or add a photo. The app keeps a readability overlay on top.")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ChillBackgroundStyle.allCases.filter { $0 != .photo }) { style in
                    Button {
                        selectedStyle = style.rawValue
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: style == .score ? [Color.chillDarkBackground, Color.chillPrimary, .yellow.opacity(0.75), .white] : style.colors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 48)

                            Text(style.rawValue)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.chillText)
                        }
                        .padding(10)
                        .background(.white.opacity(selectedStyle == style.rawValue ? 0.55 : 0.24), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Add photo background", systemImage: "photo.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.chillPrimary)
            .onChange(of: selectedPhoto) { _, newValue in
                updatePhoto(newValue)
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .white.opacity(0.30), interactive: true)
    }
}

private struct DeleteAccountCard: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 42, height: 42)
                    .glassSurface(radius: 21, tint: .red.opacity(0.12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Delete account")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)

                    Text("Remove your profile, logs, local data, and saved preferences.")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(role: .destructive, action: action) {
                Label("Delete account and data", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .red.opacity(0.08), interactive: true)
    }
}

private struct DeleteAccountConfirmationView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var confirmationText = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var isShowingDiscardWarning = false

    let deleteAction: () async -> Bool

    private var canDelete: Bool {
        confirmationText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "DELETE"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                VStack(alignment: .leading, spacing: 18) {
                    Spacer(minLength: 20)

                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.red)
                            .frame(width: 72, height: 72)
                            .glassSurface(radius: 36, tint: .red.opacity(0.14))

                        Text("Final delete check")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.chillText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("This permanently removes your ChillMate account, profile photo, profile details, logs, local storage, and saved preferences. Type DELETE to continue.")
                            .font(.callout)
                            .lineSpacing(3)
                            .foregroundStyle(Color.chillSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(22)
                    .glassSurface(radius: 34, tint: .white.opacity(0.18), interactive: true)

                    TextField("DELETE", text: $confirmationText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.chillText)
                        .padding(16)
                        .glassSurface(radius: 24, tint: .white.opacity(0.30), interactive: true)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .glassSurface(radius: 22, tint: .red.opacity(0.10))
                    }

                    Button(role: .destructive) {
                        Task {
                            isDeleting = true
                            errorMessage = nil
                            let didDelete = await deleteAction()
                            isDeleting = false

                            if didDelete {
                                dismiss()
                            } else {
                                errorMessage = "Deletion did not finish. Please try again."
                            }
                        }
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                            }

                            Text(isDeleting ? "Deleting" : "Delete everything")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!canDelete || isDeleting)
                    .opacity(canDelete ? 1 : 0.55)

                    Button("Cancel") {
                        attemptDismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BackChevronButton {
                        attemptDismiss()
                    }
                }
            }
            .discardChangesDialog(isPresented: $isShowingDiscardWarning) {
                dismiss()
            }
            .edgeSwipeBack(attemptDismiss)
            .endEditingOnTap()
        }
    }

    private func attemptDismiss() {
        if confirmationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dismiss()
        } else {
            isShowingDiscardWarning = true
        }
    }
}

@MainActor
private enum AccountDataDeletion {
    static func deleteAllData(currentContext: ModelContext) throws {
        var errors: [Error] = []

        do {
            try deleteAllModels(in: currentContext)
        } catch {
            errors.append(error)
        }

        do {
            let container = try ChillMateModelContainer.containerForDataDeletion()
            try deleteAllModels(in: ModelContext(container))
        } catch {
            errors.append(error)
        }

        do {
            try EncryptedBackupService.shared.deleteOnDeviceRecoverySnapshot()
        } catch {
            errors.append(error)
        }

        do {
            try ICloudBackupService.shared.deleteBackups()
        } catch {
            errors.append(error)
        }

        if let error = errors.first {
            throw error
        }
    }

    static func clearStoredSettings() {
        let keys = [
            "requiresFaceID",
            "requiresPIN",
            "appPINHash",
            "appPINSalt",
            "localEncryptionEnabled",
            "healthKitAutoSync",
            "healthKitSexualActivityWriteEnabled",
            "healthKitSleepReadWriteEnabled",
            "healthKitHeartRateReadEnabled",
            "healthKitHRVReadEnabled",
            "healthKitWorkoutReadEnabled",
            "notificationsEnabled",
            "dailyAffirmationsEnabled",
            "discreetNotifications",
            "notificationTone",
            "iCloudBackupEnabled",
            "lastICloudBackupStatus",
            "lastICloudBackupTimestamp",
            "lastICloudRestoreTimestamp",
            "highContrastMode",
            "chillReducedMotion",
            "oneHandedControls",
            "consentBoundaryWant",
            "consentBoundaryNo",
            "consentCheckInPhrase",
            "consentExitPlan",
            "recoveryGoal",
            "recoverySupportPerson",
            "recoveryCommitment",
            "lastAppUseTimestamp",
            "profileName",
            "profileAge",
            "profilePronouns",
            "profilePreferences",
            "profileInterests",
            "profileBoundaries",
            "profileBio",
            "profileImageData",
            "trustedContactName",
            "trustedContactPhone",
            "trustedContactMessage",
            "appBackgroundStyle",
            "appBackgroundPhotoData",
            "locationServicesChecked",
            "lastOnDeviceRecoverySnapshotTimestamp",
            "lastOnDeviceRecoveryRestoreTimestamp",
            "lastOnDeviceRecoveryStatus"
        ]

        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private static func deleteAllModels(in context: ModelContext) throws {
        let entries = try context.fetch(FetchDescriptor<NightEntry>())
        for entry in entries {
            context.delete(entry)
        }

        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        for profile in profiles {
            context.delete(profile)
        }

        let stdTests = try context.fetch(FetchDescriptor<STDTestRecord>())
        for stdTest in stdTests {
            context.delete(stdTest)
        }

        let journalEntries = try context.fetch(FetchDescriptor<JournalEntry>())
        for journalEntry in journalEntries {
            context.delete(journalEntry)
        }

        let drugTimers = try context.fetch(FetchDescriptor<DrugDoseTimerRecord>())
        for drugTimer in drugTimers {
            context.delete(drugTimer)
        }

        let saferPlans = try context.fetch(FetchDescriptor<SaferSessionPlan>())
        for saferPlan in saferPlans {
            context.delete(saferPlan)
        }

        let riskChecks = try context.fetch(FetchDescriptor<RiskCheckRecord>())
        for riskCheck in riskChecks {
            context.delete(riskCheck)
        }

        try context.save()
    }
}
