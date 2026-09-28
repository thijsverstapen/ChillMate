import SwiftData
import SwiftUI
import ChillMateCore

struct LogNightSheet: View {
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DefaultsKey.oneHandedControls) private var oneHandedControls = true

    private var saveButton: some View {
        Button("Save") {
            save()
        }
        .disabled(!canSave)
        .accessibilityIdentifier(AccessibilityID.logSaveButton)
    }

    /// Save pinned to the bottom, for Settings > Accessibility > "Prefer bottom
    /// actions". Save is the reach-critical control on the app's longest form, and
    /// the top-right corner is the hardest point to reach one-handed on a large
    /// phone.
    ///
    /// `safeAreaInset` rather than a `.bottomBar` toolbar item: the bottom bar drew
    /// the button floating over the last row of the form, because the form does not
    /// inset itself for it, and giving the bar a background did not fix it.
    /// `safeAreaInset` both places the bar and shrinks the scrollable area, so no
    /// row can ever end up hidden behind Save.
    private var bottomSaveBar: some View {
        Button {
            save()
        } label: {
            // The label carries the width, not an outer frame: the pill style sizes
            // itself to its label, so stretching from outside leaves a narrow
            // capsule floating in a full-width bar.
            Text("Save").frame(maxWidth: .infinity)
        }
        .buttonStyle(ChillPillButtonStyle())
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.5)
        .accessibilityIdentifier(AccessibilityID.logSaveButton)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
    }

    @Environment(\.modelContext) private var modelContext
    @AppStorage(DefaultsKey.healthKitAutoSync) private var healthKitAutoSync = false
    @AppStorage(DefaultsKey.healthKitSleepReadWriteEnabled) private var healthKitSleepReadEnabled = false
    @AppStorage(DefaultsKey.notificationsEnabled) private var notificationsEnabled = false

    @Query(ChillMateQueries.recentEntries) private var entries: [NightEntry]

    /// Recent entries, only so the sheet can offer to repeat the last one.
    @Query(ChillMateQueries.recentEntries) private var recentEntries: [NightEntry]

    @State private var startDate = Date.now
    @State private var endDate = Date.now.addingTimeInterval(60 * 60)
    @State private var saveHaptic = 0
    @State private var mode: LogMode = .tracked
    @State private var selectedSubstances: Set<Substance> = []
    @State private var partnerCount = 1
    @State private var partnerDetails: [SexPartnerRecord] = []
    @State private var partnerName = ""
    @State private var partnerPhoneNumber = ""
    @State private var partnerTheyWerePenetrated = false
    @State private var partnerUserWasPenetrated = false
    @State private var isShowingContactPicker = false
    @State private var usedCondom = false
    @State private var wasPenetrated = false
    @State private var sleptYet = false
    @State private var sleepHours = 6.0
    @State private var otherSubstance = ""
    @State private var didInjectDrugs = false
    @State private var injectionSubstance = Substance.threeMMC.rawValue
    @State private var injectedSubstances: [String] = []
    @State private var selectedTriggers: Set<ChillTrigger> = []
    @State private var selectedChangeReasons: Set<ChangeReason> = []
    @State private var reportedMemoryGap = false
    @State private var memorySafeNow = false
    @State private var memoryInjuries = false
    @State private var memoryConsentConcern = false
    @State private var memoryNeedsHelp = false
    @State private var memoryNotes = ""
    @State private var isShowingMemoryGapAlert = false
    @AppStorage(DefaultsKey.trustedContactPhone) private var trustedContactPhone = ""
    @State private var note = ""
    @State private var attachedLocation: LoggedLocation?
    @State private var locationMessage: String?
    @State private var isFetchingLocation = false
    @State private var isShowingDiscardWarning = false

    private let columns = [
        GridItem(.adaptive(minimum: 132), spacing: 10)
    ]

    private var chosenSubstanceNames: [String] {
        var names = Substance.allCases
            .filter { selectedSubstances.contains($0) && $0 != .other }
            .map(\.rawValue)

        if selectedSubstances.contains(.other) {
            let trimmed = otherSubstance.trimmingCharacters(in: .whitespacesAndNewlines)
            names.append(trimmed.isEmpty ? Substance.other.rawValue : trimmed)
        }

        return names
    }

    private var selectedSubstanceNamesForInjection: [String] {
        let names = chosenSubstanceNames
        return names.isEmpty ? Substance.allCases.filter { $0 != .unknown && $0 != .other }.map(\.rawValue) : names
    }

    private var canSave: Bool {
        mode == .skipped || (!chosenSubstanceNames.isEmpty && endDate > startDate)
    }

    private var hasUnsavedChanges: Bool {
        mode != .tracked ||
        !Calendar.current.isDate(startDate, equalTo: .now, toGranularity: .minute) ||
        abs(endDate.timeIntervalSince(Date.now.addingTimeInterval(60 * 60))) > 60 ||
        !selectedSubstances.isEmpty ||
        partnerCount != 1 ||
        !partnerDetails.isEmpty ||
        !partnerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !partnerPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        partnerTheyWerePenetrated ||
        partnerUserWasPenetrated ||
        usedCondom ||
        wasPenetrated ||
        sleptYet ||
        !otherSubstance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        didInjectDrugs ||
        !injectedSubstances.isEmpty ||
        !selectedTriggers.isEmpty ||
        !selectedChangeReasons.isEmpty ||
        reportedMemoryGap ||
        memorySafeNow ||
        memoryInjuries ||
        memoryConsentConcern ||
        memoryNeedsHelp ||
        !memoryNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        attachedLocation != nil
    }

    /// Written out, though it does nothing the synthesized one would not. With
    /// this many property-wrapped stored properties, resolving the synthesized
    /// initializer cost every call site 140 to 190 ms of type-checking.
    init() {}

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                logForm
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .accessibilityIdentifier(AccessibilityID.logSheet)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BackChevronButton {
                        attemptDismiss()
                    }
                    .accessibilityIdentifier(AccessibilityID.logCancelButton)
                }

                // Settings > Accessibility > "Prefer bottom actions" moves Save to
                // a pinned bar at the bottom instead (see `bottomSaveBar`).
                if !oneHandedControls {
                    ToolbarItem(placement: .confirmationAction) { saveButton }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if oneHandedControls {
                    bottomSaveBar
                }
            }
            .discardChangesDialog(isPresented: $isShowingDiscardWarning) {
                dismiss()
            }
            .sheet(isPresented: $isShowingContactPicker) {
                ContactPicker { contact in
                    partnerName = contact.name
                    partnerPhoneNumber = contact.phoneNumber
                }
            }
            .edgeSwipeBack(attemptDismiss)
            .endEditingOnTap()
            .alert("You may need support right now", isPresented: $isShowingMemoryGapAlert) {
                if !trustedContactPhone.isEmpty {
                    Button("Call trusted contact") {
                        guard let url = URL(string: "tel://\(trustedContactPhone.filter { $0.isNumber || $0 == "+" })") else { return }
                        UIApplication.shared.open(url)
                    }
                }
                Button("Call \(EmergencyContactInfo.number)") {
                    guard let url = EmergencyContactInfo.dialURL else { return }
                    UIApplication.shared.open(url)
                }
                Button("I'm okay for now", role: .cancel) { }
            } message: {
                Text("It sounds like something serious may have happened. You don't have to deal with this alone.")
            }
        }
    }

    private func attemptDismiss() {
        if hasUnsavedChanges {
            isShowingDiscardWarning = true
        } else {
            dismiss()
        }
    }

    private func save() {
        let isTracked = mode == .tracked
        let entry = NightEntry(
            date: startDate,
            startDate: startDate,
            endDate: isTracked ? endDate : startDate,
            hadSex: isTracked,
            partnerCount: isTracked ? max(partnerCount, partnerDetails.count) : 0,
            usedCondom: isTracked && usedCondom,
            wasPenetrated: isTracked && (wasPenetrated || partnerDetails.contains(where: \.userWasPenetrated)),
            partnerDetails: isTracked ? partnerDetails : [],
            skippedNight: !isTracked,
            substances: isTracked ? chosenSubstanceNames : [],
            injectionSubstances: isTracked && didInjectDrugs ? injectedSubstances : [],
            triggerTags: isTracked ? Array(selectedTriggers).sorted { $0.rawValue < $1.rawValue } : [],
            changeReasons: isTracked ? Array(selectedChangeReasons).sorted { $0.rawValue < $1.rawValue } : [],
            reportedMemoryGap: isTracked && reportedMemoryGap,
            memorySafeNow: isTracked && reportedMemoryGap && memorySafeNow,
            memoryInjuries: isTracked && reportedMemoryGap && memoryInjuries,
            memoryConsentConcern: isTracked && reportedMemoryGap && memoryConsentConcern,
            memoryNeedsHelp: isTracked && reportedMemoryGap && memoryNeedsHelp,
            memoryNotes: isTracked && reportedMemoryGap ? memoryNotes.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            sleptYet: sleptYet,
            sleepHours: sleptYet ? sleepHours : 0,
            locationName: attachedLocation?.name ?? "",
            locationLatitude: attachedLocation?.latitude,
            locationLongitude: attachedLocation?.longitude,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        modelContext.insert(entry)
        modelContext.saveChanges()

        saveHaptic += 1

        if healthKitAutoSync {
            let snapshot = HealthLogSnapshot(entry: entry)
            let sleepReadAllowed = healthKitSleepReadEnabled
            Task {
                try? await services.health.save(snapshot, sleepReadAllowed: sleepReadAllowed)
            }
        }

        // A night logged the morning after already has its sleep in Health. This
        // used to read sixteen hours from the start of the night the moment it was
        // saved — usually before anybody had slept, so it found nothing, and when
        // it did find something it could be half a night. The backfill waits until
        // the sleep is over, and also runs whenever the app is opened.
        if isTracked, !sleptYet, healthKitSleepReadEnabled {
            let ctx = modelContext
            let services = services
            Task {
                await SleepBackfill.run(context: ctx, services: services)
            }
        }

        let warningEntries = entries + [entry]
        if notificationsEnabled, HealthWarning.shouldWarn(entries: warningEntries) {
            let count = HealthWarning.recentRiskCount(entries: warningEntries)
            services.notifications.scheduleRiskWarning(count: count)
        }

        if isTracked {
            let aftercareDate = Calendar.current.date(byAdding: .day, value: 1, to: endDate) ?? endDate.addingTimeInterval(24 * 60 * 60)
            Task {
                if (try? await services.notifications.requestAuthorization()) == true {
                    await MainActor.run {
                        notificationsEnabled = true
                        services.notifications.scheduleAftercareReminder(entryID: entry.id, after: aftercareDate)
                        services.notifications.schedule48hFollowUp(entryID: entry.id, sessionDate: endDate)
                    }
                }
            }
        }

        dismiss()
    }

    private func fetchLocation() {
        guard !isFetchingLocation else {
            return
        }

        isFetchingLocation = true
        locationMessage = nil

        Task {
            do {
                let location = try await services.location.currentLoggedLocation()
                await MainActor.run {
                    attachedLocation = location
                    locationMessage = nil
                    isFetchingLocation = false
                }
            } catch {
                await MainActor.run {
                    locationMessage = error.localizedDescription
                    isFetchingLocation = false
                }
            }
        }
    }

    private func clearLocation() {
        attachedLocation = nil
        locationMessage = nil
    }

    /// The last tracked night that actually recorded something, if there is one.
    private var lastTrackedEntry: NightEntry? {
        recentEntries
            .filter { !$0.skippedNight && $0.hasSubstances }
            .max { $0.date < $1.date }
    }

    /// Offers to fill the form from the last night, and only while the form is
    /// still empty.
    ///
    /// Logging is the habit the rest of the app depends on — insights, streaks,
    /// the risk checker's history all run on it — and it was a long form every
    /// single time, even though most nights closely resemble the one before.
    ///
    /// It fills, it does not save. Writing an entry from one tap would put a night
    /// in someone's history that they never confirmed, in an app whose whole
    /// premise is that the record is theirs and accurate. The dates are
    /// deliberately not copied either: this is tonight, not a duplicate of a
    /// previous night.
    @ViewBuilder
    private var repeatLastCard: some View {
        if mode == .tracked, selectedSubstances.isEmpty, let last = lastTrackedEntry {
            Button {
                fill(from: last)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.chillPrimary)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Same as last time")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.chillText)
                        Text(last.substances.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(Color.chillSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
            .buttonStyle(ChillPlainButtonStyle())
            .glassSurface(radius: 22, tint: Color.chillPrimary.opacity(0.08), interactive: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Same as last time. Fills in \(last.substances.joined(separator: ", "))"))
            .accessibilityHint(Text("Fills the form. Nothing is saved until you tap Save."))
        }
    }

    /// Copies what a night was, never when it was.
    private func fill(from entry: NightEntry) {
        selectedSubstances = Set(entry.substances.compactMap(Substance.init(rawValue:)))
        let unknownNames = entry.substances.filter { Substance(rawValue: $0) == nil }
        if let first = unknownNames.first {
            selectedSubstances.insert(.other)
            otherSubstance = first
        }
        didInjectDrugs = entry.hasInjectionSubstances
        injectedSubstances = entry.injectionSubstances
        saveHaptic += 1
    }

    /// Scrolling form, split out of a 161-line body.
    @ViewBuilder
    private var logForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Chill type", selection: $mode) {
                    Label("I used", systemImage: "heart.fill")
                        .tag(LogMode.tracked)
                    Label("I didn't use", systemImage: "moon.zzz.fill")
                        .tag(LogMode.skipped)
                }
                .pickerStyle(.segmented)
                .padding(4)
                .glassSurface(radius: 22, tint: .black.opacity(0.04), interactive: true)
                .sensoryFeedback(.impact(weight: .medium), trigger: saveHaptic)
                .disablesRootSwipeBack()

                repeatLastCard

                if mode == .tracked {
                    TimeFrameCard(startDate: $startDate, endDate: $endDate)
                } else {
                    DatePicker("Chill", selection: $startDate, displayedComponents: [.date])
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                        .tint(Color.chillAccentTeal)
                        .padding(16)
                        .glassSurface(radius: 24, tint: .black.opacity(0.04), interactive: true)
                }

                if mode == .tracked {
                    LocationCaptureCard(
                        location: attachedLocation,
                        isFetching: isFetchingLocation,
                        message: locationMessage,
                        capture: fetchLocation,
                        remove: clearLocation
                    )

                    SleepCheckCard(sleptYet: $sleptYet, sleepHours: $sleepHours)

                    PartnerCountCard(partnerCount: $partnerCount)

                    SexPartnerDetailsCard(
                        partners: $partnerDetails,
                        partnerName: $partnerName,
                        partnerPhoneNumber: $partnerPhoneNumber,
                        partnerTheyWerePenetrated: $partnerTheyWerePenetrated,
                        partnerUserWasPenetrated: $partnerUserWasPenetrated,
                        partnerCount: $partnerCount,
                        addFromContacts: {
                            isShowingContactPicker = true
                        }
                    )

                    SaferSexCard(
                        usedCondom: $usedCondom,
                        wasPenetrated: $wasPenetrated
                    )

                    SubstancePicker(
                        selectedSubstances: $selectedSubstances,
                        otherSubstance: $otherSubstance,
                        didInjectDrugs: $didInjectDrugs,
                        injectionSubstance: $injectionSubstance,
                        injectedSubstances: $injectedSubstances,
                        availableInjectionSubstances: selectedSubstanceNamesForInjection,
                        columns: columns
                    )

                    TriggerMapCard(selectedTriggers: $selectedTriggers)

                    WhatChangedInputCard(selectedReasons: $selectedChangeReasons)

                    MemoryGapProtocolCard(
                        reportedMemoryGap: $reportedMemoryGap,
                        safeNow: $memorySafeNow,
                        injuries: $memoryInjuries,
                        consentConcern: $memoryConsentConcern,
                        needsHelp: $memoryNeedsHelp,
                        notes: $memoryNotes
                    )
                    .onChange(of: memoryInjuries) { _, val in
                        if val && reportedMemoryGap { isShowingMemoryGapAlert = true }
                    }
                    .onChange(of: memoryConsentConcern) { _, val in
                        if val && reportedMemoryGap { isShowingMemoryGapAlert = true }
                    }
                    .onChange(of: memoryNeedsHelp) { _, val in
                        if val && reportedMemoryGap { isShowingMemoryGapAlert = true }
                    }
                } else {
                    SkippedNightMessage()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Private note", systemImage: "lock.fill")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)

                    TextField("Optional context", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.chillText)
                        .padding(14)
                        .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)
                }
                .padding(16)
                .glassSurface(radius: 28, tint: .black.opacity(0.04))
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }
}
