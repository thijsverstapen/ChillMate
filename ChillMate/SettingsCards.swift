import LocalAuthentication
import PhotosUI
import SwiftData
import SwiftUI
import TipKit
import ChillMateCore

/// The cards the settings pages are built from.
///
/// Split out of `SettingsView.swift`, which held a thousand-line view and
/// fourteen hundred lines of the pieces it is assembled from. This is a move:
/// the only edit is that the cards are no longer `private`, which is what
/// splitting a Swift file always costs — file-private is file-scoped, so a type
/// used from another file has to be visible from it.

struct SettingsToggleCard: View {
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
        .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
    }
}

struct SettingsCategoryRow: View {
    let page: SettingsSectionPage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: page.symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.chillPrimary)
                .frame(width: 32, height: 32)
                .glassSurface(radius: 10, tint: Color.chillPrimary.opacity(0.14))
                .accessibilityHidden(true)

            Text(page.localizedDisplayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.chillSecondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        // The subtitle no longer takes a second line, but VoiceOver still reads it.
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(page.subtitle))
    }
}

struct AutoLockTimeoutCard: View {
    @Binding var selectedMinutes: Int

    // LocalizedStringResource, not String: `Text(someString)` renders verbatim, so
    // plain strings here shipped as English in every language.
    private let options: [(label: LocalizedStringResource, minutes: Int)] = [
        ("Immediately", 0),
        ("After 1 minute", 1),
        ("After 5 minutes", 5),
        ("After 15 minutes", 15),
        ("After 1 hour", 60)
    ]

    var body: some View {
        // The picker sits on its own row. Inline, its longest menu label
        // ("After 15 minutes", longer once translated) squeezed the caption
        // into a ragged two-line wrap and then truncated itself.
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "timer.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.chillPrimary)
                    .frame(width: 42, height: 42)
                    .glassSurface(radius: 21, tint: Color.chillPrimary.opacity(0.10))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto-lock")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)

                    Text("Re-lock when returning from the background.")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Picker("Auto-lock", selection: $selectedMinutes) {
                ForEach(options, id: \.minutes) { option in
                    Text(option.label).tag(option.minutes)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.chillPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)
    }
}

struct CheckInTimeCard: View {
    @Binding var time: Date

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock.badge.checkmark.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.chillPrimary)
                .frame(width: 42, height: 42)
                .glassSurface(radius: 21, tint: Color.chillPrimary.opacity(0.10))

            VStack(alignment: .leading, spacing: 4) {
                Text("Daily check-in time")
                    .font(.headline)
                    .foregroundStyle(Color.chillText)

                Text("When the private daily reminder arrives.")
                    .font(.caption)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            DatePicker("Daily check-in time", selection: $time, displayedComponents: [.hourAndMinute])
                .labelsHidden()
                .tint(Color.chillPrimary)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)
    }
}

struct EncryptionInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Encryption default", systemImage: "lock.doc.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("Your data is protected by default. You can also create an encrypted backup file that only you can open. Handy if you ever reinstall or switch phones.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassSurface(radius: 24, tint: Color.chillPrimary.opacity(0.08))
    }
}

struct PrivacyDashboardCard: View {
    private let rows: [(String, String, String)] = [
        ("Stored on this device", "Profile, logs, STI tests, timers, plans, journal entries, trusted contact, background, and lock settings.", "iphone"),
        ("Encrypted backup", "Created as local backup files or encrypted iCloud Drive backups when you turn those options on.", "lock.doc.fill"),
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
                        .foregroundStyle(Color.chillSecondaryBlue)
                        .frame(width: 38, height: 38)
                        .glassSurface(radius: 19, tint: Color.chillSecondaryBlue.opacity(0.10))

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
        .glassSurface(radius: 28, tint: .black.opacity(0.04))
    }
}

struct GranularHealthKitPermissionsCard: View {
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
        Toggle(isOn: $isOn) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: scope.symbolName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isOn ? Color.chillPrimary : Color.chillSecondary)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(scope.localizedDisplayName)
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
        .onChange(of: isOn) { _, newValue in
            if newValue {
                requestScope(scope)
            }
        }
    }
}

struct NotificationToneCard: View {
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
                    Text(tone.localizedDisplayName).tag(tone.rawValue)
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

struct AccessibilityQualityCard: View {
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

            SettingsToggleLine(title: String(localized: "High contrast overlays"), symbol: "circle.lefthalf.filled", isOn: $highContrastMode)
            SettingsToggleLine(title: String(localized: "Reduce ChillMate animations"), symbol: "figure.walk.motion", isOn: $reducedMotion)
            SettingsToggleLine(title: String(localized: "Prefer bottom actions"), symbol: "hand.tap.fill", isOn: $oneHandedControls)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)
    }
}

struct ClinicalReviewSettingsCard: View {
    private let rows = [
        String(localized: "Risk wording uses caution levels instead of claiming a combination is safe."),
        String(localized: "Substance, STI, PrEP, and emergency content includes source links where practical."),
        String(localized: "ChillMate supports safer decisions, but it is not a substitute for medical, legal, or emergency care.")
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
        .glassSurface(radius: 28, tint: Color.chillMint.opacity(0.08))
    }
}

struct EncryptedBackupCard: View {
    @AppStorage(DefaultsKey.lastOnDeviceRecoveryStatus) private var lastOnDeviceRecoveryStatus = ""
    @AppStorage(DefaultsKey.lastOnDeviceRecoverySnapshotTimestamp) private var lastOnDeviceRecoverySnapshotTimestamp = 0.0
    let backupURL: URL?
    let isWorking: Bool
    let prepareBackup: () -> Void
    let importBackup: () -> Void

    private var recoveryStatusText: String {
        if lastOnDeviceRecoverySnapshotTimestamp > 0 {
            let date = Date(timeIntervalSince1970: lastOnDeviceRecoverySnapshotTimestamp)
            let stamp = date.formatted(date: .abbreviated, time: .shortened)
            return String(localized: "Automatic encrypted on-device recovery is updated when ChillMate moves to the background. Last update: \(stamp).")
        }

        return String(localized: "Automatic encrypted on-device recovery starts after you have saved local data and the app has moved to the background once.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "lock.doc.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.chillPrimary)
                    .frame(width: 42, height: 42)
                    .glassSurface(radius: 21, tint: Color.chillPrimary.opacity(0.12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Encrypted backup")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)

                    Text("Create an encrypted backup of your ChillMate data. ChillMate also saves a recovery copy on your device automatically. Useful if you ever reinstall the app.")
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
            .buttonStyle(ChillPillButtonStyle(prominent: true))
            .disabled(isWorking)

            Button(action: importBackup) {
                Label("Import backup file", systemImage: "square.and.arrow.down.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChillPillButtonStyle(prominent: false))
            .disabled(isWorking)

            if let backupURL {
                ShareLink(item: backupURL) {
                    Label("Share backup file", systemImage: "square.and.arrow.up.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: false))
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)
    }
}

struct ICloudBackupCard: View {
    @Binding var isEnabled: Bool
    let status: String
    let lastBackupTimestamp: Double
    let isWorking: Bool
    let saveNow: () -> Void
    let restore: () -> Void
    let deleteBackups: () -> Void

    /// Always shown. `status` is persisted, so the old `if !status.isEmpty` early
    /// return meant a stored line like "Backup complete." hid the date forever.
    private var lastBackupText: String {
        guard lastBackupTimestamp > 0 else {
            return String(localized: "No backup yet.")
        }
        let date = Date(timeIntervalSince1970: lastBackupTimestamp)
        let relative = date.formatted(.relative(presentation: .named))
        let stamp = date.formatted(date: .abbreviated, time: .shortened)
        return String(localized: "Last backup \(relative), on \(stamp).")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.chillPrimary)
                    .frame(width: 42, height: 42)
                    .glassSurface(radius: 21, tint: Color.chillPrimary.opacity(0.12))

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

            VStack(alignment: .leading, spacing: 4) {
                Text(lastBackupText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !status.isEmpty {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(Color.chillTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                // Both buttons carry the same content shape so the HStack splits
                // evenly. Previously the spinner sat beside a full-width label,
                // making "Back up now" measure far wider than "Restore".
                Button(action: saveNow) {
                    Label {
                        Text("Back up now")
                    } icon: {
                        if isWorking {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "icloud.and.arrow.up.fill")
                        }
                    }
                    .font(.headline)
                    .chillLineLimit(1, scale: 0.75)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: true))
                .disabled(isWorking || !isEnabled)

                Button(action: restore) {
                    Label("Restore", systemImage: "icloud.and.arrow.down.fill")
                        .font(.headline)
                        .chillLineLimit(1, scale: 0.75)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: false))
                .disabled(isWorking)
            }

            Button(role: .destructive, action: deleteBackups) {
                Label("Delete iCloud backups", systemImage: "trash.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .red))
            .disabled(isWorking)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)
    }
}

struct PINLockCard: View {
    let isEnabled: Bool
    let setPIN: () -> Void
    let turnOff: () -> Void

    var body: some View {
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

                Text(isEnabled ? String(localized: "PIN is on. Tap to change.") : String(localized: "Add a 4 to 8 digit PIN alongside Face ID."))
                    .font(.caption)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if isEnabled {
                HStack(spacing: 8) {
                    Button("Change", action: setPIN)
                        .font(.caption.weight(.bold))
                        .buttonStyle(.bordered)
                        .tint(.chillPrimary)
                    Button("Off", role: .destructive, action: turnOff)
                        .font(.caption.weight(.bold))
                        .buttonStyle(.bordered)
                        .tint(.red)
                }
            } else {
                Button("Set PIN", action: setPIN)
                    .font(.caption.weight(.bold))
                    .buttonStyle(ChillPillButtonStyle(prominent: true))
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
    }
}

struct PINSetupView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var pin = ""
    @State private var confirmPIN = ""
    @State private var message: String?
    @State private var isShowingDiscardWarning = false

    let isChangingExistingPIN: Bool
    /// Setting the second PIN rather than the real one. Changes the copy, and adds
    /// the one rule the real PIN does not have.
    var isDuress: Bool = false
    let save: (String) -> Void

    private var canSave: Bool {
        guard LocalSecurityService.isValidPIN(pin), pin == confirmPIN else { return false }
        // A second PIN identical to the first could never be entered, and setting
        // one would leave somebody believing they had protection they do not.
        return isDuress ? LocalSecurityService.isAcceptableDuressPIN(pin) : true
    }

    private var titleText: String {
        if isDuress {
            return isChangingExistingPIN
                ? String(localized: "Change your second PIN")
                : String(localized: "Set a second PIN")
        }
        return isChangingExistingPIN ? String(localized: "Change your PIN") : String(localized: "Set a PIN")
    }

    private var explanationText: String {
        isDuress
            ? String(localized: "Use 4-8 numbers, different from your real PIN. Entering this one unlocks the app exactly as normal, but opens it empty. Nothing is deleted: your real PIN brings everything back.")
            : String(localized: "Use 4-8 numbers. This PIN unlocks the app on this device and works alongside Face ID.")
    }

    private var duressWarning: String? {
        guard isDuress, LocalSecurityService.isValidPIN(pin), pin == confirmPIN,
              !LocalSecurityService.isAcceptableDuressPIN(pin) else { return nil }
        return String(localized: "That is your real PIN. The second one has to be different.")
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
                            .disablesRootSwipeBack()

                        Text(titleText)
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.chillText)

                        Text(explanationText)
                            .font(.callout)
                            .lineSpacing(3)
                            .foregroundStyle(Color.chillSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let duressWarning {
                            Label(duressWarning, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(22)
                    .glassSurface(radius: 34, tint: .black.opacity(0.04), interactive: true)

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
                    .glassSurface(radius: 24, tint: .black.opacity(0.04), interactive: true)
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
        if hasInput {
            isShowingDiscardWarning = true
        } else {
            dismiss()
        }
    }
}

struct WatchCompanionSettingsCard: View {
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

            Text("These settings control the Apple Watch companion: hydration reminders, elevated heart-rate warnings, haptic breathing, discreet check-ins, timer visibility, and a strain warning that combines heart rate with heart-rate variability.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            SettingsToggleLine(title: String(localized: "Hydration reminders"), symbol: "drop.fill", isOn: $hydrationReminders)
            SettingsToggleLine(title: String(localized: "Elevated heart-rate warnings"), symbol: "heart.fill", isOn: $heartRateWarnings)
            SettingsToggleLine(title: String(localized: "Breathing haptics"), symbol: "lungs.fill", isOn: $breathingHaptics)
            SettingsToggleLine(title: String(localized: "Discreet haptic check-ins"), symbol: "applewatch.radiowaves.left.and.right", isOn: $discreetCheckIns)
            SettingsToggleLine(title: String(localized: "Visible timers and complications"), symbol: "timer", isOn: $visibleTimers)
            SettingsToggleLine(title: String(localized: "Strain warnings"), symbol: "thermometer.medium", isOn: $stressAndTemperatureDetection)
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

struct BackgroundLibraryCard: View {
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

                            Text(style.localizedDisplayName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.chillText)
                        }
                        .padding(10)
                        .background(.white.opacity(selectedStyle == style.rawValue ? 0.55 : 0.24), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(ChillPlainButtonStyle())
                }
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Add photo background", systemImage: "photo.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChillPillButtonStyle(prominent: true))
            .onChange(of: selectedPhoto) { _, newValue in
                updatePhoto(newValue)
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
    }
}

struct STIReminderIntervalCard: View {
    @Binding var selectedMonths: Int

    private let options = [(1, "Every month"), (2, "Every 2 months"), (3, "Every 3 months"), (6, "Every 6 months"), (12, "Once a year")]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Reminder interval", systemImage: "calendar.badge.clock")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Picker("Interval", selection: $selectedMonths) {
                ForEach(options, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.chillPrimary)
        }
        .padding(16)
        .glassSurface(radius: 24, tint: Color.chillMint.opacity(0.08), interactive: true)
    }
}

struct ReductionGoalCard: View {
    @Binding var goalSessions: Int
    @Binding var substanceOnly: Bool

    private let options = [(0, "No limit"), (1, "1 session"), (2, "2 sessions"), (3, "3 sessions"), (4, "4 sessions"), (6, "6 sessions"), (8, "8 sessions"), (10, "10 sessions")]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Reduction goal", systemImage: "chart.line.downtrend.xyaxis")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("Set a monthly session limit. The dashboard will show how you're tracking against your goal.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Goal sessions per month", selection: $goalSessions) {
                ForEach(options, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.chillPrimary)

            Toggle(isOn: $substanceOnly) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Count substance use only")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                    Text("When off, all tracked Chills count toward the goal.")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                }
            }
            .tint(Color.chillPrimary)

            if goalSessions > 0 {
                Text("Goal active: max \(goalSessions) \(goalSessions == 1 ? String(localized: "session") : String(localized: "sessions")) per month (\(substanceOnly ? String(localized: "substance use only") : String(localized: "all Chills"))).")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillMint)
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)
    }
}
