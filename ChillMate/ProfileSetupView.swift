import Contacts
import ContactsUI
import CoreMotion
import PhotosUI
import StoreKit
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

#if canImport(DeclaredAgeRange)
@unsafe @preconcurrency import DeclaredAgeRange
#endif
private enum ProfileSetupStep: Int, CaseIterable, Identifiable {
    case basicDetails = 1
    case identityAndHealth = 2
    case safetyAndEmergency = 3
    case featuresAndPermissions = 4

    var id: Int { rawValue }
}

/// Optional, privacy-preserving 18+ confirmation backed by Apple's
/// `DeclaredAgeRange`. It augments the self-entered date of birth: the app never
/// receives a birthdate from Apple, only a coarse age-range signal the user
/// explicitly chooses to share.
struct AgeAssuranceRow: View {
    let verified: Bool
    let underage: Bool
    let isChecking: Bool
    let message: String?
    let action: () -> Void

    private var icon: String {
        if verified { return "checkmark.seal.fill" }
        if underage { return "exclamationmark.triangle.fill" }
        return "person.badge.shield.checkmark"
    }

    private var iconTint: Color {
        if verified { return .chillIconGreen }
        if underage { return .chillIconRed }
        return .chillPrimary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(iconTint)
                    .frame(width: 30, height: 30)
                    .glassSurface(radius: 15, tint: iconTint.opacity(0.14))

                VStack(alignment: .leading, spacing: 2) {
                    Text(verified ? "Age confirmed with Apple" : "Confirm you're 18 or older")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                    Text(verified
                        ? String(localized: "Verified privately through your Apple Account.")
                        : String(localized: "Optional. Uses Apple's age range, never your birthdate."))
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if !verified {
                    Button(action: action) {
                        if isChecking {
                            ProgressView().tint(Color.chillPrimary)
                        } else {
                            Text("Confirm")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.chillPrimary)
                        }
                    }
                    .disabled(isChecking)
                }
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(underage ? .red : Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

/// Collapsible, plain-language explainer shown next to the age gate so people
/// understand why ChillMate asks their age and how the privacy-preserving check
/// works. Collapsed by default to keep the setup step calm.
struct AgeVerificationInfo: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.chillPrimary)
                    Text("Why verify your age, and how it works")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                    Spacer(minLength: 4)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.chillSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ChillMate is an adults-only wellbeing app. It includes harm-reduction, sexual-health, and substance-safety information written for people 18 and older, so it checks your age before creating a profile.")
                    Text("You can confirm your age in two private ways. The date of birth you enter stays on this device. The optional Apple Account check returns only a yes-or-no \"18 or older\" answer from Apple; it never shares your birthdate or name with the app.")
                    Text("Your age is used only on this device to unlock ChillMate. It is never sent to the developer, never uploaded, and never shared. You can leave the Apple check off and simply use your date of birth.")
                }
                .font(.caption)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

struct ProfileSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(DefaultsKey.healthKitAutoSync) private var healthKitAutoSync = false
    @AppStorage(DefaultsKey.healthKitSexualActivityWriteEnabled) private var healthKitSexualActivityWriteEnabled = false
    @AppStorage(DefaultsKey.healthKitSleepReadWriteEnabled) private var healthKitSleepReadWriteEnabled = false
    @AppStorage(DefaultsKey.healthKitHeartRateReadEnabled) private var healthKitHeartRateReadEnabled = false
    @AppStorage(DefaultsKey.healthKitHRVReadEnabled) private var healthKitHRVReadEnabled = false
    @AppStorage(DefaultsKey.healthKitWorkoutReadEnabled) private var healthKitWorkoutReadEnabled = false
    // Defaults to the language the app actually resolved, not a hard "en".
    // LocalizationService seeds the stored key at launch on every device whose
    // language ChillMate ships, so this fallback only matters on a device set to
    // a sixth language, where the app really is running in English.
    @AppStorage(DefaultsKey.appLanguage) private var appLanguage = LocalizationService.selected.rawValue
    @AppStorage(DefaultsKey.country) private var country = "Netherlands"
    @AppStorage(DefaultsKey.notificationsEnabled) private var notificationsEnabled = false
    @AppStorage(DefaultsKey.dailyAffirmationsEnabled) private var dailyAffirmationsEnabled = false
    @AppStorage(DefaultsKey.requiresFaceID) private var requiresFaceID = false
    @AppStorage(DefaultsKey.locationServicesChecked) private var locationServicesChecked = false
    @AppStorage(DefaultsKey.iCloudBackupEnabled) private var iCloudBackupEnabled = false
    @AppStorage(DefaultsKey.lastICloudBackupStatus) private var lastICloudBackupStatus = ""
    @AppStorage(DefaultsKey.trustedContactName) private var trustedContactName = ""
    @AppStorage(DefaultsKey.trustedContactPhone) private var trustedContactPhone = ""
    @AppStorage(DefaultsKey.trustedContactMessage) private var trustedContactMessage = TrustedContactDefaults.message

    @State private var hasSeenIntroduction = false
    @State private var setupStep: ProfileSetupStep = .basicDetails
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImageData: Data?
    @State private var hasAgreed = false
    @State private var name = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date.now) ?? Date.now
    @State private var sex: ProfileSex = .preferNotToSay
    @State private var sexualOrientation: SexualOrientation = .preferNotToSay
    @State private var sexualRole: SexualRole = .preferNotToSay
    @State private var isOnPrEP = false
    @State private var prepStartDate = Date.now
    @State private var prepSchedule: PrEPSchedule = .daily
    @State private var weightKg = 75.0
    @State private var heightCm = 175.0
    @State private var homeStreet = ""
    @State private var homeHouseNumber = ""
    @State private var homePostalCode = ""
    @State private var homeCity = ""
    @State private var homeCountry = "Netherlands"
    @State private var usesCurrentMedication = false
    @State private var medications: [ProfileMedication] = []
    @State private var medicationName = ""
    @State private var medicationDosage = ""
    @State private var medicationTakenAt = Date.now
    @State private var medicationEffectiveHours = 8.0
    @State private var permissionMessage: String?
    @State private var backupImportMessage: String?
    @State private var isCheckingPermissions = false
    @State private var isShowingPermissionWarning = false
    @State private var isShowingBackupImporter = false
    @State private var isImportingBackup = false
    @State private var isRestoringICloudBackup = false
    @State private var isShowingTrustedContactPicker = false
    @State private var isShowingQuickStart = false

    // MARK: Age assurance (DeclaredAgeRange)
    /// Set once Apple's age-range signal confirms 18+, so we don't re-prompt.
    @AppStorage(DefaultsKey.ageAssuranceVerifiedAdult) private var ageAssuranceVerifiedAdult = false
    /// True only when Apple positively reports the account is under 18. Persisted
    /// so the 18+ block survives an app relaunch (a determined relaunch must not
    /// silently clear an authoritative under-18 signal).
    @AppStorage(DefaultsKey.ageAssuranceUnderage) private var ageAssuranceUnderage = false
    @State private var isCheckingAgeRange = false
    @State private var ageAssuranceMessage: String?
    #if canImport(DeclaredAgeRange)
    @Environment(\.requestAgeRange) private var requestAgeRange
    #endif

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && calculatedAge >= 18
    }

    private var calculatedAge: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: .now).year ?? 18
    }

    private var shouldShowSexualRole: Bool {
        let eligibleSex = sex == .male || sex == .nonBinary
        let eligibleOrientation = sexualOrientation == .gay
            || sexualOrientation == .bisexual
            || sexualOrientation == .queer
            || sexualOrientation == .questioning

        return eligibleSex && eligibleOrientation
    }

    private var allPersonalizationFeaturesEnabled: Bool {
        healthKitAutoSync && notificationsEnabled && locationServicesChecked && iCloudBackupEnabled
    }

    private var formattedHomeAddress: String {
        let streetLine = [homeStreet, homeHouseNumber]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let cityLine = [homePostalCode, homeCity]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return [streetLine, cityLine, homeCountry.trimmingCharacters(in: .whitespacesAndNewlines)]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                if hasSeenIntroduction {
                    VStack(spacing: 0) {
                        SetupWizardProgressBar(step: setupStep)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 2)

                        TabView(selection: $setupStep) {
                            ForEach(ProfileSetupStep.allCases) { step in
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 22) {
                                        stepContent(step)
                                    }
                                    .frame(maxWidth: 600, alignment: .leading)
                                    .frame(maxWidth: .infinity)
                                    .padding(20)
                                    .padding(.bottom, 24)
                                }
                                .scrollIndicators(.hidden)
                                .scrollDismissesKeyboard(.interactively)
                                .tag(step)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut(duration: 0.3), value: setupStep)

                        SetupWizardFooter(
                            step: setupStep,
                            canAdvance: footerCanAdvance,
                            reason: footerDisabledReason,
                            onBack: goToPreviousStep,
                            onNext: goToNextStep,
                            onSkip: { isShowingQuickStart = true }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    }
                    // The wizard rises softly into place as the intro dissolves, so the
                    // two read as one continuous flow rather than a hard cut.
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    ProfileIntroductionView {
                        withAnimation(.easeInOut(duration: 0.55)) {
                            hasSeenIntroduction = true
                        }
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle(Text(verbatim: ""))
            .liquidGlassAlert(
                isPresented: $isShowingPermissionWarning,
                title: String(localized: "Continue without everything on?"),
                message: String(localized: "ChillMate still works. Apple Health, notifications, location, and iCloud backup just make reminders, recovery, emergency messages, and restore easier."),
                primaryTitle: String(localized: "Yes, continue"),
                primaryAction: createProfile,
                secondaryTitle: String(localized: "Review permissions")
            )
            .fileImporter(
                isPresented: $isShowingBackupImporter,
                allowedContentTypes: [UTType(filenameExtension: "cmbak") ?? .data, .data, .json],
                allowsMultipleSelection: false,
                onCompletion: handleBackupImport
            )
            .sheet(isPresented: $isShowingTrustedContactPicker) {
                ContactPicker { contact in
                    trustedContactName = contact.name
                    trustedContactPhone = contact.phoneNumber
                }
            }
            .sheet(isPresented: $isShowingQuickStart) {
                QuickStartSheet(
                    hasAgreed: $hasAgreed,
                    isUnderage: ageAssuranceUnderage,
                    age: calculatedAge,
                    start: {
                        isShowingQuickStart = false
                        createProfile()
                    }
                )
            }
            .endEditingOnTap()
            .onChange(of: selectedPhoto) { _, newValue in
                loadProfilePhoto(newValue)
            }
        }
    }

    @ViewBuilder
    private func stepContent(_ step: ProfileSetupStep) -> some View {
        switch step {
        case .basicDetails:
            basicDetailsStep
        case .identityAndHealth:
            identityStep
        case .safetyAndEmergency:
            safetyStep
        case .featuresAndPermissions:
            permissionsStep
        }
    }

    @ViewBuilder
    private var basicDetailsStep: some View {
        ProfileSetupPhotoPicker(imageData: profileImageData, selectedPhoto: $selectedPhoto)

                VStack(alignment: .leading, spacing: 16) {
                    ProfileSetupSectionHeader(
                        eyebrow: String(localized: "Step 1 of 4"),
                        title: String(localized: "Let’s set up your profile"),
                        subtitle: String(localized: "Add what feels useful now. You can change it later.")
                    )

                    ProfileSetupBackupImportCard(
                        isImporting: isImportingBackup,
                        isRestoringICloud: isRestoringICloudBackup,
                        message: backupImportMessage,
                        importAction: {
                            isShowingBackupImporter = true
                        },
                        restoreICloudAction: {
                            restoreICloudBackup()
                        }
                    )

                    VStack(spacing: 0) {
                        ProfileSetupPickerRow(
                            title: String(localized: "Language"),
                            systemImage: "globe"
                        ) {
                            Picker("Language", selection: $appLanguage) {
                                ForEach(AppLanguage.allCases) { language in
                                    Text(verbatim: language.endonym).tag(language.rawValue)
                                }
                            }
                        }
                        .onChange(of: appLanguage) { _, newValue in
                            // Writes AppleLanguages, which is what actually selects
                            // the bundle's .lproj. Without this the picker only
                            // stored a string nothing read.
                            guard let language = AppLanguage.matching(newValue) else { return }
                            LocalizationService.apply(language)
                        }

                        if LocalizationService.pendingRestart {
                            // Bundle localization is resolved once at process start,
                            // so the new language applies on the next launch. Say so
                            // rather than letting the screen look broken.
                            Label(
                                String(localized: "Reopen ChillMate to finish switching language."),
                                systemImage: "arrow.clockwise"
                            )
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }

                        // This picker and Settings > ChillMate > Language write the
                        // same iOS preference, and the app now lets the more recent
                        // of the two win. Two controls over one value are only
                        // confusing while they pretend not to know about each other,
                        // so name the relationship and offer the way over there.
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "iOS Settings can set ChillMate’s language too. Whichever you change last is the one that\u{00A0}applies."))
                                .font(.caption)
                                .foregroundStyle(Color.chillSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if let settingsURL = LocalizationService.systemSettingsURL {
                                Link(destination: settingsURL) {
                                    Label(
                                        String(localized: "Open ChillMate in iOS Settings"),
                                        systemImage: "gear"
                                    )
                                    .font(.caption.weight(.semibold))
                                }
                                .tint(Color.chillPrimary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)

                        ProfileSetupRowDivider()

                        ProfileSetupPickerRow(
                            title: String(localized: "Country"),
                            systemImage: "mappin.and.ellipse"
                        ) {
                            // Names come from Locale, so they translate with the app
                            // instead of being hard-coded English. The tag stays the
                            // English rawValue because it is the persisted key that
                            // SupportResource and EmergencyContactInfo match on.
                            Picker("Country", selection: $country) {
                                ForEach(SupportedCountry.allCases) { supported in
                                    Text(supported.displayName).tag(supported.rawValue)
                                }
                            }
                        }

                        ProfileSetupRowDivider()

                        ProfileSetupTextField(
                            title: String(localized: "Name"),
                            placeholder: String(localized: "Enter your name"),
                            text: $name,
                            systemImage: "person.fill"
                        )

                        ProfileSetupRowDivider()

                        ProfileSetupDateRow(
                            title: String(localized: "Date of birth (\(calculatedAge))"),
                            date: $dateOfBirth,
                            systemImage: "calendar"
                        )

                        if calculatedAge < 18 {
                            ProfileSetupRowDivider()

                            Text("ChillMate is for adults. You need to be 18 or older to create an account.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        }

                        #if canImport(DeclaredAgeRange)
                        ProfileSetupRowDivider()

                        AgeAssuranceRow(
                            verified: ageAssuranceVerifiedAdult,
                            underage: ageAssuranceUnderage,
                            isChecking: isCheckingAgeRange,
                            message: ageAssuranceMessage,
                            action: { Task { await verifyAgeWithAppleAccount() } }
                        )
                        #endif

                        ProfileSetupRowDivider()

                        AgeVerificationInfo()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
                }
    }

    @ViewBuilder
    private var identityStep: some View {
                VStack(alignment: .leading, spacing: 16) {
                    ProfileSetupSectionHeader(
                        eyebrow: String(localized: "Step 2 of 4"),
                        title: String(localized: "Identity & preferences"),
                        subtitle: String(localized: "(Optional) This helps ChillMate make your overview feel more personal.")
                    )

                    VStack(spacing: 0) {
                        ProfileSetupPickerRow(
                            title: String(localized: "Sex"),
                            systemImage: "person.2.fill"
                        ) {
                            Picker("Sex", selection: $sex) {
                                ForEach(ProfileSex.allCases) { option in
                                    Text(option.localizedDisplayName).tag(option)
                                }
                            }
                        }

                        ProfileSetupRowDivider()

                        ProfileSetupPickerRow(
                            title: String(localized: "Orientation"),
                            systemImage: "heart.fill"
                        ) {
                            Picker("Sexual orientation", selection: $sexualOrientation) {
                                ForEach(SexualOrientation.allCases) { option in
                                    Text(option.localizedDisplayName).tag(option)
                                }
                            }
                        }

                        if shouldShowSexualRole {
                            ProfileSetupRowDivider()

                            ProfileSetupPickerRow(
                                title: String(localized: "Role"),
                                systemImage: "arrow.left.arrow.right"
                            ) {
                                Picker("Role", selection: $sexualRole) {
                                    ForEach(SexualRole.allCases.filter { $0 != .notApplicable }) { option in
                                        Text(option.localizedDisplayName).tag(option)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
                }
    }

    @ViewBuilder
    private var safetyStep: some View {
                VStack(alignment: .leading, spacing: 16) {
                    ProfileSetupSectionHeader(
                        eyebrow: String(localized: "Step 3 of 4"),
                        title: String(localized: "Home information"),
                        subtitle: String(localized: "Optional. This helps the Route tab get you home faster.")
                    )

                    VStack(spacing: 0) {
                        ProfileSetupTextField(
                            title: String(localized: "Street"),
                            placeholder: String(localized: "Street name"),
                            text: $homeStreet,
                            systemImage: "house.fill"
                        )

                        ProfileSetupRowDivider()

                        ProfileSetupTextField(
                            title: String(localized: "House number"),
                            placeholder: String(localized: "Number or addition"),
                            text: $homeHouseNumber,
                            systemImage: "number"
                        )

                        ProfileSetupRowDivider()

                        ProfileSetupTextField(
                            title: String(localized: "Postal code"),
                            placeholder: String(localized: "Postal code"),
                            text: $homePostalCode,
                            systemImage: "envelope.fill"
                        )

                        ProfileSetupRowDivider()

                        ProfileSetupTextField(
                            title: String(localized: "City"),
                            placeholder: String(localized: "City"),
                            text: $homeCity,
                            systemImage: "building.2.fill"
                        )

                        ProfileSetupRowDivider()

                        ProfileSetupTextField(
                            title: String(localized: "Country"),
                            placeholder: String(localized: "Country"),
                            text: $homeCountry,
                            systemImage: "globe.europe.africa.fill"
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
                }

                VStack(alignment: .leading, spacing: 16) {
                    ProfileSetupSectionHeader(
                        eyebrow: String(localized: "Step 3 of 4"),
                        title: String(localized: "Emergency contact"),
                        subtitle: String(localized: "Optional, but helpful. You can call or message this person from Emergency, Panic support, and Safe Route.")
                    )

                    VStack(spacing: 0) {
                        // Import from Contacts button
                        Button {
                            isShowingTrustedContactPicker = true
                        } label: {
                            HStack(spacing: 12) {
                                ProfileSetupIcon(systemImage: "person.crop.circle.badge.plus")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trustedContactName.isEmpty ? String(localized: "Import from Contacts") : trustedContactName)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(trustedContactName.isEmpty ? Color.chillPrimary : Color.chillText)
                                    if !trustedContactPhone.isEmpty {
                                        Text(trustedContactPhone)
                                            .font(.caption)
                                            .foregroundStyle(Color.chillSecondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.chillTertiary)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(ChillPlainButtonStyle())

                        ProfileSetupRowDivider()

                        ProfileSetupTextField(
                            title: String(localized: "Message to send"),
                            placeholder: String(localized: "Short message to send if you need help"),
                            text: $trustedContactMessage,
                            systemImage: "message.fill"
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassSurface(radius: 28, tint: Color.chillMint.opacity(0.08), interactive: true)
                }

                VStack(alignment: .leading, spacing: 16) {
                    ProfileSetupSectionHeader(
                        eyebrow: String(localized: "Health context"),
                        title: String(localized: "Body information"),
                        subtitle: String(localized: "This helps with your profile and timer estimates.")
                    )

                    VStack(spacing: 0) {
                        ProfileSetupMeasurementRow(
                            title: String(localized: "Weight"),
                            value: $weightKg,
                            range: 35...180,
                            unit: "kg",
                            systemImage: "scalemass.fill"
                        )

                        ProfileSetupRowDivider()

                        ProfileSetupMeasurementRow(
                            title: String(localized: "Height"),
                            value: $heightCm,
                            range: 130...220,
                            unit: "cm",
                            systemImage: "ruler.fill"
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
                }

                VStack(alignment: .leading, spacing: 16) {
                    ProfileSetupSectionHeader(
                        eyebrow: String(localized: "Health context"),
                        title: String(localized: "PrEP status"),
                        subtitle: String(localized: "Optional. Add it if you want reminders or easier planning.")
                    )

                    VStack(spacing: 0) {
                        ProfileSetupToggleRow(
                            title: String(localized: "On PrEP"),
                            subtitle: isOnPrEP ? "Enabled" : "Not enabled",
                            isOn: $isOnPrEP,
                            systemImage: "cross.case.fill"
                        )

                        if isOnPrEP {
                            ProfileSetupRowDivider()

                            ProfileSetupPickerRow(
                                title: String(localized: "PrEP schedule"),
                                systemImage: "clock.badge.checkmark.fill"
                            ) {
                                Picker("PrEP schedule", selection: $prepSchedule) {
                                    ForEach(PrEPSchedule.allCases) { option in
                                        Text(option.localizedDisplayName).tag(option)
                                    }
                                }
                            }

                            ProfileSetupRowDivider()

                            ProfileSetupDateRow(
                                title: String(localized: "Since"),
                                date: $prepStartDate,
                                systemImage: "calendar.badge.clock"
                            )

                            if prepSchedule == .daily && Calendar.current.dateComponents([.day], from: prepStartDate, to: .now).day ?? 0 < 7 {
                                ProfileSetupRowDivider()

                                Text("Daily PrEP needs about 7 days to reach maximum protection for receptive anal sex. Until then, use extra protection and follow medical advice.")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.red)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
                }

                ProfileSetupMedicationSection(
                    isEnabled: $usesCurrentMedication,
                    medications: $medications,
                    name: $medicationName,
                    dosage: $medicationDosage,
                    takenAt: $medicationTakenAt,
                    effectiveHours: $medicationEffectiveHours
                )
    }

    @ViewBuilder
    private var permissionsStep: some View {
        ProfilePermissionsPage(
            healthKitAutoSync: $healthKitAutoSync,
            notificationsEnabled: $notificationsEnabled,
            dailyAffirmationsEnabled: $dailyAffirmationsEnabled,
            requiresFaceID: $requiresFaceID,
            locationServicesChecked: $locationServicesChecked,
            iCloudBackupEnabled: $iCloudBackupEnabled,
            message: permissionMessage,
            isChecking: isCheckingPermissions,
            requestHealth: requestHealthPermission,
            requestNotifications: requestNotificationPermission,
            requestFaceID: requestFaceID,
            requestLocation: requestLocationPermission,
            requestICloud: requestICloudBackup,
            hasAgreed: $hasAgreed
        )
    }

    #if canImport(DeclaredAgeRange)
    /// Asks Apple for a privacy-preserving age-range signal (18+ gate). The app
    /// only learns whether the account is 18+ or under, never a birthdate.
    /// Declining, or any error (Simulator / unsupported region throws
    /// `.notAvailable`), simply falls back to the self-entered date of birth.
    @MainActor
    private func verifyAgeWithAppleAccount() async {
        isCheckingAgeRange = true
        defer { isCheckingAgeRange = false }
        do {
            let response = try await requestAgeRange(ageGates: 18)
            switch response {
            case .sharing(let range):
                if let lower = range.lowerBound, lower >= 18 {
                    ageAssuranceVerifiedAdult = true
                    ageAssuranceUnderage = false
                    ageAssuranceMessage = String(localized: "Age confirmed with your Apple Account.")
                } else {
                    ageAssuranceVerifiedAdult = false
                    ageAssuranceUnderage = true
                    ageAssuranceMessage = String(localized: "Your Apple Account indicates you are under 18.")
                }
            case .declinedSharing:
                ageAssuranceMessage = String(localized: "No problem. Your date of birth will be used instead.")
            @unknown default:
                ageAssuranceMessage = nil
            }
        } catch {
            ageAssuranceMessage = String(localized: "Apple's age check isn't available here. Your date of birth will be used.")
        }
    }
    #endif

    private var footerCanAdvance: Bool {
        switch setupStep {
        case .basicDetails:
            return canCreate
        case .featuresAndPermissions:
            return canCreate && hasAgreed
        default:
            return true
        }
    }

    /// Explains why the footer's primary action is blocked, so a swipe-ahead
    /// never leaves the user with a mystery-disabled button.
    private var footerDisabledReason: String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch setupStep {
        case .basicDetails:
            if trimmedName.isEmpty { return String(localized: "Enter your name to continue.") }
            if ageAssuranceUnderage { return String(localized: "Your Apple Account indicates you are under 18.") }
            if calculatedAge < 18 { return String(localized: "You must be 18 or older to use ChillMate.") }
            return nil
        case .featuresAndPermissions:
            if trimmedName.isEmpty { return String(localized: "Add your name on the first step to finish.") }
            if ageAssuranceUnderage { return String(localized: "Your Apple Account indicates you are under 18.") }
            if calculatedAge < 18 { return String(localized: "You must be 18 or older to use ChillMate.") }
            if !hasAgreed { return String(localized: "Please read and agree to the statement to finish.") }
            return nil
        default:
            return nil
        }
    }

    private func goToNextStep() {
        switch setupStep {
        case .basicDetails:
            withAnimation { setupStep = .identityAndHealth }
        case .identityAndHealth:
            withAnimation { setupStep = .safetyAndEmergency }
        case .safetyAndEmergency:
            withAnimation { setupStep = .featuresAndPermissions }
        case .featuresAndPermissions:
            finishSetup()
        }
    }

    private func goToPreviousStep() {
        switch setupStep {
        case .basicDetails:
            break
        case .identityAndHealth:
            withAnimation { setupStep = .basicDetails }
        case .safetyAndEmergency:
            withAnimation { setupStep = .identityAndHealth }
        case .featuresAndPermissions:
            withAnimation { setupStep = .safetyAndEmergency }
        }
    }

    private func loadProfilePhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            let optimized = await ChillImageOptimizer.downsampledJPEG(from: data, maxPixelSize: 640, compressionQuality: 0.84)
            profileImageData = optimized
        }
    }

    private func finishSetup() {
        if allPersonalizationFeaturesEnabled {
            createProfile()
        } else {
            isShowingPermissionWarning = true
        }
    }

    private func createProfile() {
        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            age: calculatedAge,
            dateOfBirth: dateOfBirth,
            sex: sex,
            sexualOrientation: sexualOrientation,
            sexualRole: shouldShowSexualRole ? sexualRole : .notApplicable,
            isOnPrEP: isOnPrEP,
            prepStartDate: prepStartDate,
            prepSchedule: prepSchedule,
            weightKg: weightKg,
            heightCm: heightCm,
            homeAddress: formattedHomeAddress,
            medications: usesCurrentMedication ? medications : [],
            profileImageData: profileImageData
        )

        modelContext.insert(profile)
        modelContext.saveChanges()
    }

    private func requestHealthPermission() {
        isCheckingPermissions = true
        permissionMessage = nil

        Task {
            do {
                try await HealthKitService.shared.requestAuthorization(scopes: Set(HealthKitPermissionScope.allCases))
                await MainActor.run {
                    healthKitAutoSync = true
                    healthKitSexualActivityWriteEnabled = true
                    healthKitSleepReadWriteEnabled = true
                    healthKitHeartRateReadEnabled = true
                    healthKitHRVReadEnabled = true
                    healthKitWorkoutReadEnabled = true
                    permissionMessage = String(localized: "Apple Health Sync is connected for logs, sleep, heart rate, HRV, and workouts.")
                    isCheckingPermissions = false
                }
            } catch {
                await MainActor.run {
                    healthKitAutoSync = false
                    healthKitSexualActivityWriteEnabled = false
                    healthKitSleepReadWriteEnabled = false
                    healthKitHeartRateReadEnabled = false
                    healthKitHRVReadEnabled = false
                    healthKitWorkoutReadEnabled = false
                    permissionMessage = error.localizedDescription
                    isCheckingPermissions = false
                }
            }
        }
    }

    private func requestNotificationPermission() {
        isCheckingPermissions = true
        permissionMessage = nil

        Task {
            do {
                let granted = try await NotificationService.shared.requestAuthorization()
                await MainActor.run {
                    notificationsEnabled = granted
                    if granted {
                        NotificationService.shared.scheduleCheckInReminder()
                        NotificationService.shared.scheduleInactivityReminders()
                    }
                    permissionMessage = granted ? "Notifications are on." : "Notification permission was not granted."
                    isCheckingPermissions = false
                }
            } catch {
                await MainActor.run {
                    notificationsEnabled = false
                    permissionMessage = error.localizedDescription
                    isCheckingPermissions = false
                }
            }
        }
    }

    private func requestLocationPermission() {
        isCheckingPermissions = true
        permissionMessage = nil

        Task {
            do {
                _ = try await LocationLookupService.shared.currentLoggedLocation()
                await MainActor.run {
                    locationServicesChecked = true
                    permissionMessage = String(localized: "Location is ready for logs and emergency messages.")
                    isCheckingPermissions = false
                }
            } catch {
                await MainActor.run {
                    locationServicesChecked = false
                    permissionMessage = error.localizedDescription
                    isCheckingPermissions = false
                }
            }
        }
    }

    private func requestFaceID() {
        isCheckingPermissions = true
        permissionMessage = nil

        Task {
            let success = try? await AppAuthenticator.authenticate(reason: String(localized: "Protect ChillMate with Face ID"))
            await MainActor.run {
                if success == true {
                    requiresFaceID = true
                    permissionMessage = String(localized: "Face ID lock is enabled.")
                } else {
                    requiresFaceID = false
                    permissionMessage = String(localized: "Face ID could not be enabled.")
                }
                isCheckingPermissions = false
            }
        }
    }

    private func requestICloudBackup() {
        isCheckingPermissions = true
        permissionMessage = nil

        Task {
            await MainActor.run {
                if ICloudBackupService.shared.isAvailable {
                    iCloudBackupEnabled = true
                    lastICloudBackupStatus = ICloudBackupService.shared.statusLine
                    permissionMessage = String(localized: "iCloud backup is ready. ChillMate will save encrypted backup files to iCloud Drive.")
                } else {
                    iCloudBackupEnabled = false
                    permissionMessage = ICloudBackupError.iCloudUnavailable.localizedDescription
                }
                isCheckingPermissions = false
            }
        }
    }

    private func restoreICloudBackup() {
        isRestoringICloudBackup = true
        backupImportMessage = nil

        Task {
            do {
                let summary = try ICloudBackupService.shared.restoreLatestBackup(into: modelContext)
                await MainActor.run {
                    iCloudBackupEnabled = true
                    backupImportMessage = String(localized: "Restored from iCloud. \(summary.displayText)")
                    isRestoringICloudBackup = false
                }
            } catch {
                await MainActor.run {
                    backupImportMessage = String(localized: "Could not restore iCloud backup: \(error.localizedDescription)")
                    isRestoringICloudBackup = false
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
            backupImportMessage = error.localizedDescription
        }
    }

    private func importBackup(from url: URL) {
        isImportingBackup = true
        backupImportMessage = nil

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
                    backupImportMessage = summary.displayText
                    isImportingBackup = false
                }
            } catch {
                await MainActor.run {
                    backupImportMessage = String(localized: "Could not import backup: \(error.localizedDescription)")
                    isImportingBackup = false
                }
            }
        }
    }
}

/// The shortest honest way into the app.
///
/// Two things cannot be skipped and both are here: being eighteen, and reading
/// what ChillMate does not claim to do. Everything the wizard asks for after
/// that — name, height, weight, medication, permissions, emergency contact — is
/// useful and none of it is a condition of entry, so it waits on the profile
/// screen until somebody has a calmer minute.
///
/// It creates a real profile with whatever has been filled in so far, which is
/// often nothing. An empty name is already handled everywhere it is read.
private struct QuickStartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasAgreed: Bool
    let isUnderage: Bool
    let age: Int
    let start: () -> Void

    private var canStart: Bool {
        hasAgreed && !isUnderage && age >= 18
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Go straight in"),
                            subtitle: String(localized: "You can set up your profile whenever you want. Two things first, and then you are in."),
                            symbol: "bolt.horizontal.circle.fill",
                            tint: Color.chillPrimary
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            CareSectionTitle(title: String(localized: "What ChillMate is not"), symbol: "info.circle.fill")

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

                        if isUnderage || age < 18 {
                            Text("ChillMate is for adults. Confirm your age on the first step to continue.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        GlassActionButton(prominent: true, action: start) {
                            Label("Take me in", systemImage: "arrow.right.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(!canStart)
                        .opacity(canStart ? 1 : 0.55)
                        .accessibilityIdentifier(AccessibilityID.setupQuickStartButton)

                        Text("Your profile lives on this device and nowhere else. Filling it in later makes the timers and the combination checker more useful to you, and nothing in the app is locked behind it.")
                            .font(.caption)
                            .foregroundStyle(Color.chillSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back to setup") { dismiss() }
                }
            }
        }
    }
}

private struct SetupWizardProgressBar: View {
    let step: ProfileSetupStep

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                ForEach(ProfileSetupStep.allCases) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? Color.chillPrimary : Color.chillPrimary.opacity(0.18))
                        .frame(height: 6)
                        .frame(maxWidth: .infinity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: step)

            Text("Step \(step.rawValue) of \(ProfileSetupStep.allCases.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue) of \(ProfileSetupStep.allCases.count)")
    }
}

private struct SetupWizardFooter: View {
    let step: ProfileSetupStep
    let canAdvance: Bool
    let reason: String?
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    private var isFirst: Bool { step == .basicDetails }
    private var isLast: Bool { step == .featuresAndPermissions }

    var body: some View {
        VStack(spacing: 8) {
            if let reason, !canAdvance {
                Text(reason)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }

            HStack(spacing: 12) {
                if !isFirst {
                    Button(action: onBack) {
                        Label("Back", systemImage: "chevron.left")
                            .font(.headline)
                            .chillLineLimit(1, scale: 0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChillPillButtonStyle(prominent: false))
                }

                GlassActionButton(prominent: true, action: onNext) {
                    Label(
                        isLast ? String(localized: "Create account") : String(localized: "Continue"),
                        systemImage: isLast ? "person.crop.circle.badge.checkmark" : "arrow.right.circle.fill"
                    )
                    .font(.headline)
                    .chillLineLimit(1, scale: 0.8)
                    .frame(maxWidth: .infinity)
                }
                .disabled(!canAdvance)
                .opacity(canAdvance ? 1 : 0.55)
            }

            // Available from the first screen, not buried at the end.
            //
            // Somebody installing a harm-reduction app is sometimes installing it
            // because of tonight. Four screens of height, weight, medication and
            // permissions between them and the combination checker is four
            // screens too many, and the ones who need it most are the least able
            // to sit through them. Everything here can be filled in later from
            // the profile screen, and the two things that cannot be skipped —
            // being eighteen, and reading what the app does not claim to do —
            // are what the sheet behind this button asks for.
            if !isLast {
                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ChillPlainButtonStyle())
                .accessibilityIdentifier(AccessibilityID.setupSkipButton)
                .accessibilityHint(Text("Go straight into ChillMate. You can finish your profile later."))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: reason)
    }
}

private struct ProfileSetupPhotoPicker: View {
    let imageData: Data?
    @Binding var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color.chillPrimary.opacity(0.62))
                            .padding(26)
                    }
                }
                .frame(width: 116, height: 116)
                .clipShape(Circle())
                .glassSurface(radius: 58, tint: Color.chillPrimary.opacity(0.18))

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.chillText)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay {
                            Circle().stroke(.white.opacity(0.35), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
                }
                .accessibilityLabel("Add profile picture")
            }

            Text(image == nil ? String(localized: "Add a photo (optional)") : String(localized: "Tap to change photo"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if image == nil, let imageData {
                image = UIImage(data: imageData)
            }
        }
        .onChange(of: imageData) { _, newValue in
            image = newValue.flatMap(UIImage.init(data:))
        }
    }
}

private struct ProfilePermissionsPage: View {
    @Binding var healthKitAutoSync: Bool
    @Binding var notificationsEnabled: Bool
    @Binding var dailyAffirmationsEnabled: Bool
    @Binding var requiresFaceID: Bool
    @Binding var locationServicesChecked: Bool
    @Binding var iCloudBackupEnabled: Bool
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
    let requestICloud: () -> Void
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
                                NotificationService.shared.scheduleWeekendSafetyCheckIns()
                            } else {
                                NotificationService.shared.clearWeekendSafetyCheckIns()
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
                                NotificationService.shared.scheduleWeeklySummary(streak: 0, score: 0)
                            } else {
                                NotificationService.shared.clearWeeklySummary()
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
                                NotificationService.shared.scheduleSTIReminder(dueDate: dueDate)
                            } else {
                                NotificationService.shared.clearSTIReminder()
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
                    subtitle: String(localized: "Request read/write access for logs, sleep, heart rate, HRV, and workouts."),
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

                ProfileSetupRowDivider()

                PermissionSetupCard(
                    title: String(localized: "iCloud Backup"),
                    subtitle: String(localized: "Save and restore encrypted ChillMate backups through iCloud Drive."),
                    symbol: "icloud.fill",
                    isOn: iCloudBackupEnabled,
                    action: requestICloud
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

            Text("Your profile stays private on this device. If iCloud Backup is on, ChillMate saves encrypted backup files to iCloud Drive.")
                .font(.footnote)
                .foregroundStyle(Color.chillSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
    }
}

struct ProfileSetupBackupImportCard: View {
    let isImporting: Bool
    let isRestoringICloud: Bool
    let message: String?
    let importAction: () -> Void
    let restoreICloudAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ProfileSetupIcon(systemImage: "externaldrive.badge.plus")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Have a backup?")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                    Text("Restore from iCloud or import a previous encrypted ChillMate backup before creating a new profile.")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button(action: restoreICloudAction) {
                    HStack {
                        if isRestoringICloud {
                            ProgressView()
                        }
                        Label("iCloud", systemImage: "icloud.and.arrow.down.fill")
                            .font(.headline)
                            .chillLineLimit(1, scale: 0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: true))
                .disabled(isRestoringICloud || isImporting)

                Button(action: importAction) {
                    HStack {
                        if isImporting {
                            ProgressView()
                        }
                        Label("File", systemImage: "square.and.arrow.down.fill")
                            .font(.headline)
                            .chillLineLimit(1, scale: 0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .chillSecondaryBlue))
                .disabled(isImporting || isRestoringICloud)
            }

            if let message {
                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08), interactive: true)
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

struct ProfileSetupMedicationSection: View {
    @Binding var isEnabled: Bool
    @Binding var medications: [ProfileMedication]
    @Binding var name: String
    @Binding var dosage: String
    @Binding var takenAt: Date
    @Binding var effectiveHours: Double

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProfileSetupSectionHeader(
                eyebrow: String(localized: "Medication"),
                title: String(localized: "Current medication"),
                subtitle: String(localized: "Turn this on only if you want ChillMate to remember medication for check-ins and risk checks.")
            )

            medicationCard
        }
    }

    private func addMedication() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        medications.append(
            ProfileMedication(
                name: trimmedName,
                dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines),
                takenAt: takenAt,
                effectiveHours: effectiveHours
            )
        )
        name = ""
        dosage = ""
        takenAt = .now
        effectiveHours = 8
    }

    /// Toggle and medication rows, split out of a 107-line body.
    @ViewBuilder
    private var medicationCard: some View {
        VStack(spacing: 0) {
            ProfileSetupToggleRow(
                title: String(localized: "I use current medication"),
                subtitle: isEnabled ? "Medication fields are shown" : "No medication fields needed",
                isOn: $isEnabled,
                systemImage: "pills.fill"
            )

            if isEnabled {
                ProfileSetupRowDivider()

                ProfileSetupTextField(
                    title: String(localized: "Medication name"),
                    placeholder: String(localized: "For example sertraline"),
                    text: $name,
                    systemImage: "pills.fill"
                )

                ProfileSetupRowDivider()

                ProfileSetupTextField(
                    title: String(localized: "Prescription amount"),
                    placeholder: String(localized: "As written on your label"),
                    text: $dosage,
                    systemImage: "number"
                )

                ProfileSetupRowDivider()

                ProfileSetupDateRow(
                    title: String(localized: "Last taken"),
                    date: $takenAt,
                    systemImage: "clock.fill"
                )

                ProfileSetupRowDivider()

                ProfileSetupMeasurementRow(
                    title: String(localized: "Medication duration"),
                    value: $effectiveHours,
                    range: 0.5...72,
                    unit: "h",
                    systemImage: "timer"
                )

                GlassActionButton(prominent: false, action: addMedication) {
                    Label("Add medication", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canAdd)
                .opacity(canAdd ? 1 : 0.55)
                .padding(.top, 14)

                if medications.isEmpty {
                    Text("No medication saved yet.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                } else {
                    VStack(spacing: 8) {
                        ForEach(medications) { medication in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "pills.circle.fill")
                                    .foregroundStyle(Color.chillPrimary)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(medication.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.chillText)
                                    Text(medication.timingSummary)
                                        .font(.caption)
                                        .foregroundStyle(Color.chillSecondary)
                                }

                                Spacer()

                                Button {
                                    medications.removeAll { $0.id == medication.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(ChillPlainButtonStyle())
                                .foregroundStyle(Color.chillSecondary)
                            }
                            .padding(10)
                            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
    }
}
