import SwiftUI
import ChillMateCore

// The profile wizard's last step: each permission, asked for with its reason.

struct ProfilePermissionsPage: View {
    @Environment(\.services) private var services
    @Binding var healthKitAutoSync: Bool
    @Binding var notificationsEnabled: Bool
    @Binding var dailyAffirmationsEnabled: Bool
    @Binding var requiresFaceID: Bool
    @Binding var locationServicesChecked: Bool
    @AppStorage(DefaultsKey.discreetNotifications) private var discreetNotifications = false
    @AppStorage(DefaultsKey.weekendSafetyEnabled) private var weekendSafetyEnabled = false
    @AppStorage(DefaultsKey.safetyCheckInsEnabled) private var safetyCheckInsEnabled = false
    @AppStorage(DefaultsKey.weeklyDigestEnabled) private var weeklyDigestEnabled = false
    @AppStorage(DefaultsKey.stiReminderEnabled) private var stiReminderEnabled = false
    let message: String?
    let isChecking: Bool
    let requestHealth: () -> Void
    let requestNotifications: () -> Void
    let requestFaceID: () -> Void
    let requestLocation: () -> Void
    @Binding var hasAgreed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ProfileSetupSectionHeader(
                eyebrow: String(localized: "Step 4 of 4"),
                title: String(localized: "Features & Permissions"),
                subtitle: String(localized: "Choose which system features ChillMate can use. You can change these later in Settings.")
            )

            profilePermissionsPageContinued
        }
    }

    /// Second half of `ProfilePermissionsPage`'s body, which ran to 150 lines.
    ///
    /// Split purely for readability: these are the same views in the same
    /// order, still direct children of the same container.
    @ViewBuilder
    private var profilePermissionsPageContinued: some View {
            VStack(spacing: 0) {
                PermissionSetupCard(
                    title: String(localized: "Face ID"),
                    subtitle: String(localized: "Require Face ID to open ChillMate and protect your local data."),
                    symbol: "faceid",
                    isOn: requiresFaceID,
                    action: requestFaceID
                )

                ProfileSetupRowDivider()

                PermissionSetupCard(
                    title: String(localized: "Notifications"),
                    subtitle: String(localized: "Reminders for safe plans, STI results, aftercare, and private check-ins."),
                    symbol: "bell.badge.fill",
                    isOn: notificationsEnabled,
                    action: requestNotifications
                )

                if notificationsEnabled {
                    ProfileSetupRowDivider()

                    PermissionSetupCard(
                        title: String(localized: "Discreet notifications"),
                        subtitle: String(localized: "Keep lock-screen wording vague. Off shows the full reminder text."),
                        symbol: "eye.slash.fill",
                        isOn: discreetNotifications,
                        action: { discreetNotifications.toggle() }
                    )

                    ProfileSetupRowDivider()

                    PermissionSetupCard(
                        title: String(localized: "Night safety check-ins"),
                        subtitle: String(localized: "On weekend nights (12 to 6 am), a discreet “you okay?” with one-tap help."),
                        symbol: "moon.stars.fill",
                        isOn: weekendSafetyEnabled,
                        action: {
                            weekendSafetyEnabled.toggle()
                            if weekendSafetyEnabled {
                                services.notifications.scheduleWeekendSafetyCheckIns()
                            } else {
                                services.notifications.clearWeekendSafetyCheckIns()
                            }
                        }
                    )

                    ProfileSetupRowDivider()

                    PermissionSetupCard(
                        title: String(localized: "Session safety check-ins"),
                        subtitle: String(localized: "While a dose timer runs, more noticeable check-ins with fast help."),
                        symbol: "shield.lefthalf.filled",
                        isOn: safetyCheckInsEnabled,
                        action: { safetyCheckInsEnabled.toggle() }
                    )

                    ProfileSetupRowDivider()

                    PermissionSetupCard(
                        title: String(localized: "Weekly summary"),
                        subtitle: String(localized: "A Sunday-evening digest of your streak and score."),
                        symbol: "calendar.badge.clock",
                        isOn: weeklyDigestEnabled,
                        action: {
                            weeklyDigestEnabled.toggle()
                            if weeklyDigestEnabled {
                                // Placeholder figures. Home reschedules with the real streak and score
                                // the next time it recomputes metrics, which is on its next appearance.
                                services.notifications.scheduleWeeklySummary(streak: 0, score: 0)
                            } else {
                                services.notifications.clearWeeklySummary()
                            }
                        }
                    )

                    ProfileSetupRowDivider()

                    PermissionSetupCard(
                        title: String(localized: "STI test reminders"),
                        subtitle: String(localized: "A gentle reminder to test on a regular schedule."),
                        symbol: "cross.case.fill",
                        isOn: stiReminderEnabled,
                        action: {
                            stiReminderEnabled.toggle()
                            if stiReminderEnabled {
                                let dueDate = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
                                services.notifications.scheduleSTIReminder(dueDate: dueDate)
                            } else {
                                services.notifications.clearSTIReminder()
                            }
                        }
                    )
                }

                ProfileSetupRowDivider()

                PermissionSetupCard(
                    title: String(localized: "Daily Affirmations"),
                    subtitle: String(localized: "Receive a gentle affirmation when you open the app."),
                    symbol: "quote.bubble.fill",
                    isOn: dailyAffirmationsEnabled,
                    action: {
                        dailyAffirmationsEnabled.toggle()
                    }
                )

                ProfileSetupRowDivider()

                PermissionSetupCard(
                    title: String(localized: "Apple Health Sync"),
                    subtitle: String(localized: "Saves when your nights happened, fills in how long you slept, and reads heart rate and HRV for your recovery score."),
                    symbol: "heart.text.square.fill",
                    isOn: healthKitAutoSync,
                    action: requestHealth
                )

                ProfileSetupRowDivider()

                PermissionSetupCard(
                    title: String(localized: "Location"),
                    subtitle: String(localized: "Attach a location to logs and include your current location in emergency messages."),
                    symbol: "location.fill",
                    isOn: locationServicesChecked,
                    action: requestLocation
                )

            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)

            profilePermissionsPageContinuedTail
    }

    /// Second half of `ProfilePermissionsPage`'s body, which ran to 192 lines.
    ///
    /// Split purely for readability: these are the same views in the same
    /// order, still direct children of the same container.
    @ViewBuilder
    private var profilePermissionsPageContinuedTail: some View {
            if isChecking {
                Label("Checking permission", systemImage: "hourglass")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .padding(14)
                    .glassSurface(radius: 20, tint: .black.opacity(0.04))
            }

            if let message {
                Text(message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .glassSurface(radius: 20, tint: .black.opacity(0.04))
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Before you start", systemImage: "doc.text.fill")
                    .font(.headline)
                    .foregroundStyle(Color.chillText)

                Text("ChillMate supports reflection, recovery, STI care, privacy, and emergency planning. It does not replace a clinician, diagnose conditions, decide whether something is safe, or recommend amounts, timing, or substance use. Its information is drawn from verified, official public-health sources and is updated over time as those sources change. ChillMate and its maker are not liable in any way for decisions made using the app. If someone may be in immediate danger, call local emergency services.")
                    .font(.footnote)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: $hasAgreed.animation(.snappy)) {
                    Text("I have read and agree to this.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                }
                .tint(.chillMint)
            }
            .padding(16)
            .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)

            Text("Your profile stays private on this device. Nothing is copied to iCloud unless you turn on iCloud sync.")
                .font(.footnote)
                .foregroundStyle(Color.chillSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
    }
}

private struct PermissionSetupCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ProfileSetupIcon(systemImage: symbol)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                    Text(isOn ? String(localized: "Enabled") : subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: isOn ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.chillMint : Color.chillPrimary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(ChillPlainButtonStyle())
    }
}
