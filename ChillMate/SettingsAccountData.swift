import SwiftData
import SwiftUI
import TipKit
import UIKit

/// Everything that takes data out of ChillMate or removes it: CSV export, the
/// retention window, and account deletion.
///
/// Split out of `SettingsView.swift` unchanged. `AccountDataDeletion` is the
/// reason this is its own file rather than more cards — it is the one piece of
/// settings code that destroys something.

struct CSVExportCard: View {
    let isWorking: Bool
    let export: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "tablecells.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.chillPrimary)
                    .frame(width: 42, height: 42)
                    .glassSurface(radius: 21, tint: Color.chillPrimary.opacity(0.12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("CSV export")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)

                    Text("Export your Chill logs as a CSV file. Tap 'Prepare backup' first to also get the encrypted archive.")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: export) {
                HStack {
                    if isWorking { ProgressView() }
                    Label("Export as CSV", systemImage: "tablecells.fill")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChillPillButtonStyle(prominent: true))
            .disabled(isWorking)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)
    }
}

struct DataRetentionCard: View {
    @Binding var selectedMonths: Int
    @Binding var isAutomatic: Bool
    let applyRetention: () -> Void

    // LocalizedStringResource, not String: Text(someString) renders verbatim, so
    // these labels shipped as English in every language. Widened to eight options.
    private let options: [(months: Int, label: LocalizedStringResource)] = [
        (0, "Keep everything"),
        (1, "1 month"),
        (3, "3 months"),
        (6, "6 months"),
        (12, "1 year"),
        (24, "2 years"),
        (36, "3 years"),
        (60, "5 years")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "calendar.badge.minus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 42, height: 42)
                    .glassSurface(radius: 21, tint: .orange.opacity(0.12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Data retention")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)

                    Text("Delete logs older than a chosen age. This cannot be undone. Back up first.")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Picker("Keep data for", selection: $selectedMonths) {
                ForEach(options, id: \.months) { option in
                    Text(option.label).tag(option.months)
                }
            }
            .pickerStyle(.menu)
            .tint(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)

            if selectedMonths > 0 {
                Toggle(isOn: $isAutomatic) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete automatically")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.chillText)

                        Text("Applies the window once a day, so you do not have to remember.")
                            .font(.caption)
                            .foregroundStyle(Color.chillSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(.orange)

                Button(role: .destructive, action: applyRetention) {
                    Label("Delete those entries now", systemImage: "trash.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .red))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(radius: 28, tint: .orange.opacity(0.08), interactive: true)
    }
}

struct DeleteAccountCard: View {
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
            .buttonStyle(ChillPillButtonStyle(prominent: true, tint: .red))
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .red.opacity(0.08), interactive: true)
    }
}

struct DeleteAccountConfirmationView: View {
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
                            .disablesRootSwipeBack()

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
                        .glassSurface(radius: 24, tint: .black.opacity(0.04), interactive: true)

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
                                errorMessage = String(localized: "Deletion did not finish. Please try again.")
                            }
                        }
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                            }

                            Text(isDeleting ? String(localized: "Deleting") : String(localized: "Delete everything"))
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChillPillButtonStyle(prominent: true, tint: .red))
                    .disabled(!canDelete || isDeleting)
                    .opacity(canDelete ? 1 : 0.55)

                    Button("Cancel") {
                        attemptDismiss()
                    }
                    .buttonStyle(ChillPillButtonStyle(prominent: false))
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .navigationTitle(Text(verbatim: ""))
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
enum AccountDataDeletion {
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
            DefaultsKey.appBackgroundPhotoFingerprint,
            "locationServicesChecked",
            "lastOnDeviceRecoverySnapshotTimestamp",
            "lastOnDeviceRecoveryRestoreTimestamp",
            "lastOnDeviceRecoveryStatus"
        ]

        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // The background photo is a file now, so clearing its defaults key is not
        // enough to erase it.
        BackgroundPhotoStore.delete()
    }

    private static func deleteAllModels(in context: ModelContext) throws {
        let entries = try context.fetch(FetchDescriptor<NightEntry>())
        for entry in entries {
            context.delete(entry)
        }

        // Cascade removes children attached to the entries above, but a CloudKit
        // sync can briefly leave child records whose parent hasn't imported (or was
        // deleted elsewhere). Sweep them explicitly: partner records carry names and
        // phone numbers, so none may survive "Delete all data".
        for substanceRecord in try context.fetch(FetchDescriptor<LoggedSubstanceRecord>()) {
            context.delete(substanceRecord)
        }
        for partnerRecord in try context.fetch(FetchDescriptor<PartnerDetailRecord>()) {
            context.delete(partnerRecord)
        }
        for triggerRecord in try context.fetch(FetchDescriptor<TriggerTagRecord>()) {
            context.delete(triggerRecord)
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

/// Turns the second PIN on and off.
///
/// Sits under the real PIN card and only appears once there is a real PIN, because
/// a second PIN has nothing to be distinct from otherwise.
///
/// The copy avoids the word "panic" deliberately. Somebody scrolling this screen
/// with a person beside them should not be looking at a row that announces what it
/// is for.
