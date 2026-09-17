import PhotosUI
import SwiftData
import SwiftUI

/// The profile: overview, photo header, editor, medication, and the detail
/// sections behind it.
///
/// Split out of `DashboardView.swift` unchanged.

struct ProfileOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(ChillMateQueries.profile) private var profiles: [UserProfile]
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isShowingProfileEditor = false
    let showsBackButton: Bool

    init(showsBackButton: Bool = true) {
        self.showsBackButton = showsBackButton
    }

    private var profile: UserProfile? {
        profiles.first
    }

    private var details: [ProfileDetail] {
        guard let profile else {
            return []
        }

        // `group` is an enum, not the label. Sections used to be filtered by
        // comparing the localized label against English literals, so every
        // section came out empty in Dutch, German, French and Spanish.
        var items = [
            ProfileDetail(group: .identity, label: String(localized: "Name"), value: profile.name, symbol: "person.fill"),
            ProfileDetail(group: .identity, label: String(localized: "Date of birth"), value: "\(profile.dateOfBirth.formatted(date: .abbreviated, time: .omitted)) (\(profile.calculatedAge))", symbol: "calendar"),
            ProfileDetail(group: .body, label: String(localized: "Weight"), value: "\(Int(profile.weightKg.rounded())) kg", symbol: "scalemass.fill"),
            ProfileDetail(group: .body, label: String(localized: "Height"), value: "\(Int(profile.heightCm.rounded())) cm", symbol: "ruler.fill"),
            ProfileDetail(group: .identity, label: String(localized: "Sex"), value: profile.sex, symbol: "person.2.fill"),
            ProfileDetail(group: .identity, label: String(localized: "Sexual orientation"), value: profile.sexualOrientation, symbol: "heart.fill")
        ]

        if profile.sexualRole != SexualRole.notApplicable.rawValue {
            items.append(ProfileDetail(group: .identity, label: String(localized: "Role"), value: profile.sexualRole, symbol: "arrow.left.arrow.right"))
        }

        items.append(
            ProfileDetail(
                group: .health,
                label: String(localized: "PrEP"),
                value: profile.isOnPrEP ? String(localized: "Yes") : String(localized: "No"),
                symbol: "cross.case.fill"
            )
        )

        if profile.isOnPrEP {
            items.append(
                ProfileDetail(
                    group: .health,
                    label: String(localized: "PrEP schedule"),
                    value: profile.prepSchedule,
                    symbol: "clock.badge.checkmark.fill"
                )
            )
            items.append(
                ProfileDetail(
                    group: .health,
                    label: String(localized: "PrEP since"),
                    value: profile.prepStartDate.formatted(date: .abbreviated, time: .omitted),
                    symbol: "calendar.badge.clock"
                )
            )
        }

        return items
    }

    var body: some View {
        ZStack {
            DashboardBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                        if profile == nil {
                            MissingProfileCard()
                        } else {
                            if profile?.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                                UnfinishedProfileCard { isShowingProfileEditor = true }
                            }

                            ProfilePhotoHeader(
                                profileImageData: profile?.profileImageData,
                                selectedPhoto: $selectedPhoto,
                                updatePhoto: updateProfilePhoto
                            )

                            ProfileAllSections(details: details, medications: profile?.medications ?? [])
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if profile != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingProfileEditor = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.headline.weight(.bold))
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(ChillPlainButtonStyle())
                        .foregroundStyle(Color.chillText)
                        .glassSurface(radius: 18, tint: .white.opacity(0.28), interactive: true)
                        .accessibilityLabel("Edit")
                    }
                }
            }
            .fullScreenCover(isPresented: $isShowingProfileEditor) {
                if let profile {
                    ProfileEditView(profile: profile)
                }
            }
    }

    private func updateProfilePhoto(_ item: PhotosPickerItem?) {
        guard let item else {
            return
        }

        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                return
            }

            let optimizedData = await ChillImageOptimizer.downsampledJPEG(from: data, maxPixelSize: 640, compressionQuality: 0.84)

            guard let profile = profiles.first else {
                return
            }

            profile.profileImageData = optimizedData
            modelContext.saveChanges()
        }
    }
}

private struct ProfilePhotoHeader: View {
    let profileImageData: Data?
    @Binding var selectedPhoto: PhotosPickerItem?
    let updatePhoto: (PhotosPickerItem?) -> Void
    @State private var profileImage: UIImage?

    private var imageIdentifier: String {
        guard let profileImageData else {
            return "none"
        }

        let prefixHash = profileImageData.prefix(32).reduce(0) { partial, byte in
            (partial &* 31) &+ Int(byte)
        }
        return "\(profileImageData.count)-\(prefixHash)"
    }

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color.chillPrimary.opacity(0.62))
                            .padding(28)
                    }
                }
                .frame(width: 132, height: 132)
                .clipShape(Circle())
                .glassSurface(radius: 66, tint: Color.chillPrimary.opacity(0.18))

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.35), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
                }
                .onChange(of: selectedPhoto) { _, newValue in
                    updatePhoto(newValue)
                }
                .accessibilityLabel("Add profile picture")
            }

            Text("Your profile overview")
                .font(.title2.bold())
                .foregroundStyle(Color.chillText)

            Text("Keep the details that shape your private overview up to date.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.chillSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .glassSurface(radius: 34, tint: .white.opacity(0.12))
        .task(id: imageIdentifier) {
            guard let profileImageData else {
                profileImage = nil
                return
            }

            let optimizedData = await ChillImageOptimizer.downsampledJPEG(from: profileImageData, maxPixelSize: 640, compressionQuality: 0.84)
            profileImage = UIImage(data: optimizedData)
        }
    }
}

private struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(DefaultsKey.lastDailyRecoveryScore) private var lastDailyRecoveryScore = 42
    @AppStorage(DefaultsKey.country) private var country = "Netherlands"
    @Bindable var profile: UserProfile

    private var palette: DailyScorePalette {
        DailyScorePalette(score: lastDailyRecoveryScore)
    }

    private var sexBinding: Binding<ProfileSex> {
        Binding {
            ProfileSex(rawValue: profile.sex) ?? .male
        } set: { value in
            profile.sex = value.rawValue
            modelContext.saveChanges()
        }
    }

    private var roleBinding: Binding<SexualRole> {
        Binding {
            SexualRole(rawValue: profile.sexualRole) ?? .notApplicable
        } set: { value in
            profile.sexualRole = value.rawValue
            modelContext.saveChanges()
        }
    }

    private var prepScheduleBinding: Binding<PrEPSchedule> {
        Binding {
            PrEPSchedule(rawValue: profile.prepSchedule) ?? .daily
        } set: { value in
            profile.prepSchedule = value.rawValue
            modelContext.saveChanges()
        }
    }

    private var dailyPrEPNotice: Bool {
        profile.isOnPrEP &&
        (PrEPSchedule(rawValue: profile.prepSchedule) ?? .daily) == .daily &&
        (Calendar.current.dateComponents([.day], from: profile.prepStartDate, to: .now).day ?? 0) < 7
    }

    var body: some View {
        NavigationStack {
            profileEditContent
            .navigationTitle(Text(verbatim: ""))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BackChevronButton {
                        dismiss()
                    }
                }
            }
        }
        .edgeSwipeToDismiss()
        .endEditingOnTap()
        .onChange(of: profile.dateOfBirth) { _, _ in
            profile.age = profile.calculatedAge
            modelContext.saveChanges()
        }
        .onChange(of: profile.weightKg) { _, _ in
            modelContext.saveChanges()
        }
        .onChange(of: profile.heightCm) { _, _ in
            modelContext.saveChanges()
        }
        .onChange(of: profile.homeAddress) { _, _ in
            modelContext.saveChanges()
        }
        .onChange(of: profile.isOnPrEP) { _, _ in
            modelContext.saveChanges()
        }
        .onChange(of: profile.prepStartDate) { _, _ in
            modelContext.saveChanges()
        }
    }

    /// Form content, split out of a 181-line body.
    @ViewBuilder
    private var profileEditContent: some View {
        ZStack {
            DashboardBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Edit profile")
                            .font(.largeTitle.bold())
                            .foregroundStyle(palette.heroText)
                            .disablesRootSwipeBack()

                        Text("These details keep your overview and timer estimates personal.")
                            .font(.callout)
                            .foregroundStyle(palette.heroSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 44)

                    VStack(spacing: 0) {
                        ProfileSetupDateRow(
                            title: String(localized: "Date of birth (\(profile.calculatedAge))"),
                            date: $profile.dateOfBirth,
                            systemImage: "calendar"
                        )

                        ProfileSetupRowDivider()

                        ProfileSetupMeasurementRow(title: String(localized: "Weight"), value: $profile.weightKg, range: 35...180, unit: "kg", systemImage: "scalemass.fill")

                        ProfileSetupRowDivider()

                        ProfileSetupMeasurementRow(title: String(localized: "Height"), value: $profile.heightCm, range: 130...220, unit: "cm", systemImage: "ruler.fill")

                        ProfileSetupRowDivider()

                        ProfileSetupTextField(
                            title: String(localized: "Home address"),
                            placeholder: String(localized: "Street, number, and city"),
                            text: $profile.homeAddress,
                            systemImage: "house.fill",
                            axis: .vertical
                        )

                        ProfileSetupRowDivider()

                        ProfileSetupPickerRow(title: String(localized: "Country"), systemImage: "mappin.and.ellipse") {
                            Picker("Country", selection: $country) {
                                ForEach(EmergencyContactInfo.selectableCountries, id: \.self) { name in
                                    Text(LocalizedStringKey(name)).tag(name)
                                }
                                Text("Other").tag("Other")
                            }
                        }

                        Text("Sets your default emergency number and the support resources shown across the app.")
                            .font(.caption)
                            .foregroundStyle(palette.heroSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 6)

                        ProfileSetupRowDivider()

                        ProfileSetupPickerRow(title: String(localized: "Sex"), systemImage: "person.2.fill") {
                            Picker("Sex", selection: sexBinding) {
                                ForEach(ProfileSex.allCases) { option in
                                    Text(option.localizedDisplayName).tag(option)
                                }
                            }
                        }

                        ProfileSetupRowDivider()

                        ProfileSetupPickerRow(title: String(localized: "Role"), systemImage: "arrow.left.arrow.right") {
                            Picker("Role", selection: roleBinding) {
                                ForEach(SexualRole.allCases) { option in
                                    Text(option.localizedDisplayName).tag(option)
                                }
                            }
                        }

                        ProfileSetupRowDivider()

                        ProfileSetupToggleRow(
                            title: String(localized: "On PrEP"),
                            subtitle: profile.isOnPrEP ? String(localized: "Enabled") : String(localized: "Not enabled"),
                            isOn: $profile.isOnPrEP,
                            systemImage: "cross.case.fill"
                        )

                        if profile.isOnPrEP {
                            ProfileSetupRowDivider()

                            ProfileSetupPickerRow(title: String(localized: "PrEP schedule"), systemImage: "clock.badge.checkmark.fill") {
                                Picker("PrEP schedule", selection: prepScheduleBinding) {
                                    ForEach(PrEPSchedule.allCases) { option in
                                        Text(option.localizedDisplayName).tag(option)
                                    }
                                }
                            }

                            ProfileSetupRowDivider()

                            ProfileSetupDateRow(
                                title: String(localized: "PrEP since"),
                                date: $profile.prepStartDate,
                                systemImage: "calendar.badge.clock"
                            )

                            if dailyPrEPNotice {
                                ProfileSetupRowDivider()

                                Text("Daily PrEP needs about 7 days to reach maximum protection for receptive anal sex. Until then, use extra protection and follow medical advice.")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.red)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                            }
                        }

                        ProfileSetupRowDivider()

                        Text("Changes save automatically.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)

                    ProfileMedicationEditor(profile: profile)
                }
                .padding(20)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

private struct ProfileMeasurementStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String

    var body: some View {
        Stepper(value: $value, in: range, step: 1) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.chillText)
                Spacer()
                Text("\(Int(value.rounded())) \(unit)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.chillSecondary)
            }
        }
        .tint(Color.chillPrimary)
    }
}

private struct ProfileMedicationEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile
    @State private var name = ""
    @State private var dosage = ""
    @State private var takenAt = Date.now
    @State private var effectiveHours = 8.0

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: String(localized: "Medication"), symbol: "pills.fill")

            VStack(spacing: 10) {
                TextField("Medication name", text: $name)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.chillText)
                    .padding(14)
                    .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                TextField("Medication amount from your prescription, optional", text: $dosage)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.chillText)
                    .padding(14)
                    .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                DatePicker("Usually taken", selection: $takenAt, displayedComponents: [.hourAndMinute])
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.chillText)
                    .tint(Color.chillPrimary)

                Stepper(value: $effectiveHours, in: 0.5...72, step: 0.5) {
                    HStack {
                        Text("Works for")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.chillText)
                        Spacer()
                        Text("\(effectiveHours.formatted(.number.precision(.fractionLength(0...1)))) h")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.chillSecondary)
                    }
                }
                .tint(Color.chillPrimary)

                GlassActionButton(prominent: true, action: addMedication) {
                    Label("Add medication", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canAdd)
                .opacity(canAdd ? 1 : 0.55)
            }

            if profile.medications.isEmpty {
                Text("No medication saved yet.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(profile.medications) { medication in
                        ProfileMedicationEditableRow(medication: medication) {
                            removeMedication(medication)
                        }
                    }
                }
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08), interactive: true)
    }

    private func addMedication() {
        let medication = ProfileMedication(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines),
            takenAt: takenAt,
            effectiveHours: effectiveHours
        )
        var medications = profile.medications
        medications.append(medication)
        profile.medications = medications
        modelContext.saveChanges()
        name = ""
        dosage = ""
        takenAt = .now
        effectiveHours = 8
    }

    private func removeMedication(_ medication: ProfileMedication) {
        var medications = profile.medications
        medications.removeAll { $0.id == medication.id }
        profile.medications = medications
        modelContext.saveChanges()
    }
}

private struct ProfileMedicationEditableRow: View {
    let medication: ProfileMedication
    let remove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "pills.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.chillSecondaryBlue)
                .frame(width: 36, height: 36)
                .glassSurface(radius: 18, tint: Color.chillSecondaryBlue.opacity(0.10))

            VStack(alignment: .leading, spacing: 3) {
                Text(medication.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.chillText)
                Text(medication.timingSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
            }

            Spacer(minLength: 0)

            Button(role: .destructive, action: remove) {
                Image(systemName: "trash.fill")
            }
            .buttonStyle(ChillPlainButtonStyle())
            .foregroundStyle(Color.chillSecondary)
        }
        .padding(12)
        .glassSurface(radius: 20, tint: .black.opacity(0.04), interactive: true)
    }
}

private struct ProfileMedicationDetailCard: View {
    let medication: ProfileMedication

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "pills.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.chillSecondaryBlue)
                .frame(width: 40, height: 40)
                .glassSurface(radius: 20, tint: Color.chillSecondaryBlue.opacity(0.10))

            VStack(alignment: .leading, spacing: 4) {
                Text(medication.name)
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
                Text(medication.timingSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassSurface(radius: 24, tint: .black.opacity(0.04))
    }
}

/// Shown when somebody took the short way in and has not filled anything in yet.
///
/// Deliberately an invitation and not a warning. Skipping setup is a supported
/// choice, not an error state — the app works without any of it — so this says
/// what filling it in actually buys rather than telling somebody they are
/// incomplete.
private struct UnfinishedProfileCard: View {
    let edit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CareSectionTitle(title: String(localized: "Finish this whenever"), symbol: "person.crop.circle.badge.plus")

            Text("You went straight in, which is fine. Height and weight make the check-in windows fit you, and your medication list is what the combination checker reads. Nothing here is required.")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: edit) {
                Label("Fill in my profile", systemImage: "square.and.pencil")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChillPillButtonStyle(prominent: true))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.10), interactive: true)
    }
}

private struct MissingProfileCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Color.chillPrimary)
                .frame(width: 86, height: 86)
                .glassSurface(radius: 43, tint: Color.chillPrimary.opacity(0.14))

            Text("No profile yet")
                .font(.title3.bold())
                .foregroundStyle(Color.chillText)

            Text("Create your profile from setup to see your details here.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.chillSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassSurface(radius: 30, tint: .black.opacity(0.04))
    }
}

private struct ProfileDetailList: View {
    let details: [ProfileDetail]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(details) { detail in
                ProfileDetailRow(detail: detail)
            }
        }
    }
}

private enum ProfileSectionPage: String, CaseIterable, Identifiable {
    case identity = "Identity"
    case body = "Body"
    case health = "Health"
    case medications = "Medication"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .identity:
            "person.text.rectangle.fill"
        case .body:
            "ruler.fill"
        case .health:
            "cross.case.fill"
        case .medications:
            "pills.fill"
        }
    }
}

/// One page with everything on it. Profile used to be four rows that reported
/// only how many items each held, so reading your own details took four taps
/// and four screens.
private struct ProfileAllSections: View {
    let details: [ProfileDetail]
    let medications: [ProfileMedication]

    var body: some View {
        VStack(spacing: 20) {
            ForEach(ProfileSectionPage.allCases) { page in
                let rows = details.filter { $0.group == page }

                if page == .medications || !rows.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: page.symbol)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.chillPrimary)
                                .frame(width: 30, height: 30)
                                .glassSurface(radius: 10, tint: Color.chillPrimary.opacity(0.12))
                                .accessibilityHidden(true)

                            Text(page.localizedDisplayName)
                                .font(.headline)
                                .foregroundStyle(Color.chillText)

                            Spacer(minLength: 0)
                        }
                        .accessibilityAddTraits(.isHeader)

                        if page == .medications {
                            if medications.isEmpty {
                                EmptyGlassState(text: String(localized: "No medication saved yet. Use Edit on your profile to add medication, prescription amount, timing, and duration."))
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(medications) { medication in
                                        ProfileMedicationDetailCard(medication: medication)
                                    }
                                }
                            }
                        } else {
                            ProfileDetailList(details: rows)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct ProfileDetailRow: View {
    let detail: ProfileDetail

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: detail.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.chillPrimary)
                .frame(width: 40, height: 40)
                .glassSurface(radius: 20, tint: Color.chillPrimary.opacity(0.12))

            VStack(alignment: .leading, spacing: 4) {
                Text(detail.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondary)

                Text(detail.displayValue)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.chillText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassSurface(radius: 24, tint: .black.opacity(0.04))
    }
}

private struct ProfileDetail: Identifiable {
    let group: ProfileSectionPage
    let label: String
    let value: String
    let symbol: String

    var id: String { label }

    var displayValue: String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? String(localized: "Not added yet") : trimmedValue
    }
}
