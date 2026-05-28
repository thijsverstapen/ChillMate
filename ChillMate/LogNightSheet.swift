import CoreLocation
import Contacts
import ContactsUI
import MapKit
import SwiftData
import SwiftUI

struct LogNightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("healthKitAutoSync") private var healthKitAutoSync = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false

    @Query(sort: \NightEntry.date, order: .reverse) private var entries: [NightEntry]

    @State private var startDate = Date.now
    @State private var endDate = Date.now.addingTimeInterval(60 * 60)
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

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BackChevronButton {
                        attemptDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
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
        try? modelContext.save()

        if healthKitAutoSync {
            let snapshot = HealthLogSnapshot(entry: entry)
            Task {
                try? await HealthKitService.shared.save(snapshot)
            }
        }

        let warningEntries = entries + [entry]
        if notificationsEnabled, HealthWarning.shouldWarn(entries: warningEntries) {
            let count = HealthWarning.recentRiskCount(entries: warningEntries)
            NotificationService.shared.scheduleRiskWarning(count: count)
        }

        if isTracked {
            let aftercareDate = Calendar.current.date(byAdding: .day, value: 1, to: endDate) ?? endDate.addingTimeInterval(24 * 60 * 60)
            Task {
                if (try? await NotificationService.shared.requestAuthorization()) == true {
                    await MainActor.run {
                        notificationsEnabled = true
                        NotificationService.shared.scheduleAftercareReminder(entryID: entry.id, after: aftercareDate)
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
                let location = try await LocationLookupService.shared.currentLoggedLocation()
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
}

struct LoggedLocation: Equatable, Sendable {
    let name: String
    let latitude: Double
    let longitude: Double

    var coordinateSummary: String {
        let latitudeText = latitude.formatted(.number.precision(.fractionLength(4)))
        let longitudeText = longitude.formatted(.number.precision(.fractionLength(4)))
        return "\(latitudeText), \(longitudeText)"
    }

    var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Current location" : trimmedName
    }
}

private struct LocationCaptureCard: View {
    let location: LoggedLocation?
    let isFetching: Bool
    let message: String?
    let capture: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Location", systemImage: "location.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            if let location {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.teal)
                        .frame(width: 44, height: 44)
                        .glassSurface(radius: 22, tint: .teal.opacity(0.14))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(location.displayName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.chillText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(location.coordinateSummary)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    Button(action: capture) {
                        Label("Change", systemImage: "location.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.teal)
                    .disabled(isFetching)

                    Button(role: .destructive, action: remove) {
                        Image(systemName: "trash.fill")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 46, height: 36)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Remove location")
                }
            } else {
                Text("Attach your current location to this private log.")
                    .font(.callout)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: capture) {
                    HStack {
                        if isFetching {
                            ProgressView()
                        }

                        Label(isFetching ? "Finding location" : "Use current location", systemImage: "location.circle.fill")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(isFetching)
            }

            if let message {
                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .teal.opacity(0.10), interactive: true)
    }
}

private struct PartnerCountCard: View {
    @Binding var partnerCount: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.chillPrimary)
                .frame(width: 42, height: 42)
                .glassSurface(radius: 21, tint: Color.chillPrimary.opacity(0.12))

            Stepper(value: $partnerCount, in: 1...50) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How many people did you have sex with?")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)

                    Text("An estimate is more than enough.")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)

                    Text("\(partnerCount) \(partnerCount == 1 ? "person" : "people")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                }
            }
            .tint(Color.chillPrimary)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.09), interactive: true)
    }
}

private struct SexPartnerDetailsCard: View {
    @Binding var partners: [SexPartnerRecord]
    @Binding var partnerName: String
    @Binding var partnerPhoneNumber: String
    @Binding var partnerTheyWerePenetrated: Bool
    @Binding var partnerUserWasPenetrated: Bool
    @Binding var partnerCount: Int
    let addFromContacts: () -> Void

    private var canAddPartner: Bool {
        !partnerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !partnerPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text("Add names only if it helps you remember who to contact later. Phone numbers are used for the STI warning message shortcut.")
                    .font(.caption)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: addFromContacts) {
                    Label("Add from Contacts", systemImage: "person.crop.circle.badge.plus")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.chillPrimary)

                TextField("Name or nickname", text: $partnerName)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.chillText)
                    .padding(14)
                    .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                TextField("Phone number for iMessage", text: $partnerPhoneNumber)
                    .keyboardType(.phonePad)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.chillText)
                    .padding(14)
                    .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                Toggle("This person was penetrated", isOn: $partnerTheyWerePenetrated)
                    .tint(Color.chillPrimary)

                Toggle("I was penetrated by this person", isOn: $partnerUserWasPenetrated)
                    .tint(Color.chillPrimary)

                GlassActionButton(prominent: false, action: addPartner) {
                    Label("Add person", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canAddPartner)
                .opacity(canAddPartner ? 1 : 0.55)

                if !partners.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(partners) { partner in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundStyle(Color.chillPrimary)
                                    .frame(width: 30, height: 30)
                                    .glassSurface(radius: 15, tint: Color.chillPrimary.opacity(0.12))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(partner.displayName)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.chillText)

                                    if !partner.normalizedPhoneNumber.isEmpty {
                                        Text(partner.phoneNumber)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.chillSecondary)
                                    }

                                    Text(positionSummary(for: partner))
                                        .font(.caption)
                                        .foregroundStyle(Color.chillSecondary)
                                }

                                Spacer()

                                Button {
                                    partners.removeAll { $0.id == partner.id }
                                    partnerCount = max(1, partners.count)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.chillSecondary)
                            }
                            .padding(10)
                            .glassSurface(radius: 18, tint: .black.opacity(0.04))
                        }
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            Label("People involved", systemImage: "person.crop.circle.badge.plus")
                .font(.headline)
                .foregroundStyle(Color.chillText)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.chillText)
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.09), interactive: true)
    }

    private func addPartner() {
        let name = partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = partnerPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty || !phone.isEmpty else {
            return
        }

        partners.append(
            SexPartnerRecord(
                name: name,
                phoneNumber: phone,
                theyWerePenetrated: partnerTheyWerePenetrated,
                userWasPenetrated: partnerUserWasPenetrated
            )
        )
        partnerCount = max(partnerCount, partners.count)
        partnerName = ""
        partnerPhoneNumber = ""
        partnerTheyWerePenetrated = false
        partnerUserWasPenetrated = false
    }

    private func positionSummary(for partner: SexPartnerRecord) -> String {
        switch (partner.theyWerePenetrated, partner.userWasPenetrated) {
        case (true, true):
            "Both penetration directions recorded"
        case (true, false):
            "This person was penetrated"
        case (false, true):
            "You were penetrated"
        case (false, false):
            "No penetration detail recorded"
        }
    }
}

private struct SaferSexCard: View {
    @Binding var usedCondom: Bool
    @Binding var wasPenetrated: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Sex details", systemImage: "shield.lefthalf.filled")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Toggle("Condom used", isOn: $usedCondom)
                .tint(Color.chillPrimary)

            Toggle("I was penetrated", isOn: $wasPenetrated)
                .tint(Color.chillPrimary)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.chillText)
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.09), interactive: true)
    }
}

private struct TimeFrameCard: View {
    @Binding var startDate: Date
    @Binding var endDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Time frame", systemImage: "clock.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            VStack(spacing: 12) {
                DatePicker(
                    "Started",
                    selection: $startDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .tint(Color.chillAccentTeal)

                DatePicker(
                    "Ended",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .tint(Color.chillAccentTeal)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.chillText)

            if endDate <= startDate {
                Text("End time should be after the start time.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillAccentTeal.opacity(0.08), interactive: true)
        .onChange(of: startDate) { _, newValue in
            if endDate <= newValue {
                endDate = newValue.addingTimeInterval(60 * 60)
            }
        }
    }
}

private struct SubstancePicker: View {
    @Binding var selectedSubstances: Set<Substance>
    @Binding var otherSubstance: String
    @Binding var didInjectDrugs: Bool
    @Binding var injectionSubstance: String
    @Binding var injectedSubstances: [String]
    let availableInjectionSubstances: [String]
    let columns: [GridItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Drugs taken", systemImage: "pills.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Substance.allCases) { substance in
                    SubstanceChip(
                        substance: substance,
                        isSelected: selectedSubstances.contains(substance)
                    ) {
                        toggle(substance)
                    }
                }
            }

            if selectedSubstances.contains(.other) {
                TextField("Name the other substance", text: $otherSubstance)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.chillText)
                    .padding(14)
                    .glassSurface(radius: 18, tint: .teal.opacity(0.12), interactive: true)
            }

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Yes, slamming/injecting happened", isOn: $didInjectDrugs)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                        .tint(Color.chillAccentTeal)

                    if didInjectDrugs {
                        HStack {
                            Picker("Substance", selection: $injectionSubstance) {
                                ForEach(availableInjectionSubstances, id: \.self) { substance in
                                    Text(substance).tag(substance)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.chillVisibleMint)

                            Button {
                                addInjectedSubstance()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.chillVisibleMint)
                        }

                        if injectedSubstances.isEmpty {
                            Text("Add one or more injected substances if you want them saved.")
                                .font(.caption)
                                .foregroundStyle(Color.chillSecondary)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(injectedSubstances, id: \.self) { substance in
                                    Button {
                                        injectedSubstances.removeAll { $0 == substance }
                                    } label: {
                                        Label(substance, systemImage: "xmark.circle.fill")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.chillText)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .glassSurface(radius: 14, tint: Color.chillAccentTeal.opacity(0.12))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                Label("Slamming / injecting", systemImage: "syringe.fill")
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillAccentTeal.opacity(0.08))
    }

    private func toggle(_ substance: Substance) {
        if selectedSubstances.contains(substance) {
            selectedSubstances.remove(substance)
        } else {
            selectedSubstances.insert(substance)
        }
    }

    private func addInjectedSubstance() {
        let candidate = injectionSubstance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, !injectedSubstances.contains(candidate) else {
            return
        }
        injectedSubstances.append(candidate)
    }
}

private struct SubstanceChip: View {
    let substance: Substance
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: substance.symbolName)
                    .font(.caption.weight(.bold))
                Text(substance.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(Color.chillText)
            .frame(maxWidth: .infinity, minHeight: 42)
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
        .glassSurface(
            radius: 21,
            tint: isSelected ? substance.tint.opacity(0.32) : .black.opacity(0.04),
            interactive: true
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(substance.tint.opacity(0.42), lineWidth: 1)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct TriggerMapCard: View {
    @Binding var selectedTriggers: Set<ChillTrigger>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Trigger map", systemImage: "map.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("Optional. Tag what led into this Chill so patterns are easier to notice later.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            FlowLayout(spacing: 8) {
                ForEach(ChillTrigger.allCases) { trigger in
                    SelectableTextChip(
                        title: trigger.rawValue,
                        isSelected: selectedTriggers.contains(trigger),
                        tint: Color.chillVisibleMint
                    ) {
                        toggle(trigger)
                    }
                }
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillVisibleMint.opacity(0.08))
    }

    private func toggle(_ trigger: ChillTrigger) {
        if selectedTriggers.contains(trigger) {
            selectedTriggers.remove(trigger)
        } else {
            selectedTriggers.insert(trigger)
        }
    }
}

private struct WhatChangedInputCard: View {
    @Binding var selectedReasons: Set<ChangeReason>

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text("Only select what feels relevant. This is for spotting trends, not judging yourself.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                FlowLayout(spacing: 8) {
                    ForEach(ChangeReason.allCases) { reason in
                        SelectableTextChip(
                            title: reason.rawValue,
                            isSelected: selectedReasons.contains(reason),
                            tint: Color.chillVisibleBlue
                        ) {
                            toggle(reason)
                        }
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Did something change recently?", systemImage: "waveform.path.ecg")
                .font(.headline)
                .foregroundStyle(Color.chillText)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillVisibleBlue.opacity(0.08))
    }

    private func toggle(_ reason: ChangeReason) {
        if selectedReasons.contains(reason) {
            selectedReasons.remove(reason)
        } else {
            selectedReasons.insert(reason)
        }
    }
}

private struct MemoryGapProtocolCard: View {
    @Binding var reportedMemoryGap: Bool
    @Binding var safeNow: Bool
    @Binding var injuries: Bool
    @Binding var consentConcern: Bool
    @Binding var needsHelp: Bool
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $reportedMemoryGap) {
                Label("I do not remember parts", systemImage: "questionmark.bubble.fill")
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
            }
            .tint(Color.chillPrimary)

            if reportedMemoryGap {
                Text("Calm mode: answer only what matters right now.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)

                VStack(spacing: 10) {
                    Toggle("I am safe right now", isOn: $safeNow)
                    Toggle("I may have injuries", isOn: $injuries)
                    Toggle("I have consent concerns", isOn: $consentConcern)
                    Toggle("I want help or a trusted contact", isOn: $needsHelp)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)
                .tint(Color.chillPrimary)

                TextField("Anything essential to remember?", text: $notes, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.chillText)
                    .padding(14)
                    .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                if injuries || consentConcern || needsHelp || !safeNow {
                    Text("If you are unsafe, injured, cannot wake someone, or feel at risk, call 112 or a trusted person now.")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)
    }
}

private struct SelectableTextChip: View {
    let title: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .glassSurface(radius: 16, tint: isSelected ? tint.opacity(0.20) : Color.black.opacity(0.04), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SkippedNightMessage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Skipped check-in", systemImage: "moon.zzz.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("This records the Chill as checked with no sex or substance tags.")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .indigo.opacity(0.12))
    }
}

struct PickedContact {
    let name: String
    let phoneNumber: String
}

struct ContactPicker: UIViewControllerRepresentable {
    let select: (PickedContact) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(select: select, dismiss: dismiss)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let select: (PickedContact) -> Void
        let dismiss: DismissAction

        init(select: @escaping (PickedContact) -> Void, dismiss: DismissAction) {
            self.select = select
            self.dismiss = dismiss
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let formattedName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            let phoneNumber = contact.phoneNumbers.first?.value.stringValue ?? ""
            select(PickedContact(name: formattedName, phoneNumber: phoneNumber))
            Task { @MainActor [dismiss] in
                dismiss()
            }
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            Task { @MainActor [dismiss] in
                dismiss()
            }
        }
    }
}

private struct SleepCheckCard: View {
    @Binding var sleptYet: Bool
    @Binding var sleepHours: Double

    private var mood: SleepMood {
        SleepMood(hours: sleepHours)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $sleptYet) {
                Label("Slept yet?", systemImage: "bed.double.fill")
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
            }
            .tint(Color.chillMint)

            if sleptYet {
                HStack(spacing: 14) {
                    Text(mood.emoji)
                        .font(.system(size: 42))
                        .frame(width: 54, height: 54)
                        .glassSurface(radius: 27, tint: .yellow.opacity(0.18))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(mood.label)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.chillText)
                        Text("\(sleepHours.formatted(.number.precision(.fractionLength(0...1)))) hours")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                    }

                    Spacer()
                }

                Slider(value: $sleepHours, in: 0...12, step: 0.5)
                    .tint(Color.chillMint)

                HStack {
                    Text("😢 <2h")
                    Spacer()
                    Text("😊 6h+")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillTertiary)
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillMint.opacity(0.10), interactive: true)
    }
}

final class LocationLookupService: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    static let shared = LocationLookupService()

    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    @MainActor
    func currentLoggedLocation() async throws -> LoggedLocation {
        let location = try await currentLocation()
        let name = await placeName(for: location)

        return LoggedLocation(
            name: name,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    @MainActor
    private func currentLocation() async throws -> CLLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationLookupError.servicesDisabled
        }

        if manager.authorizationStatus == .notDetermined {
            try await requestAuthorization()
        }

        guard manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways else {
            throw LocationLookupError.permissionDenied
        }

        guard locationContinuation == nil else {
            throw LocationLookupError.requestInProgress
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    @MainActor
    private func requestAuthorization() async throws {
        guard authorizationContinuation == nil else {
            throw LocationLookupError.requestInProgress
        }

        try await withCheckedThrowingContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func placeName(for location: CLLocation) async -> String {
        if #available(iOS 26.0, *), let request = MKReverseGeocodingRequest(location: location) {
            return await withCheckedContinuation { continuation in
                request.getMapItems { mapItems, _ in
                    let mapItem = mapItems?.first
                    var namedParts = [
                        mapItem?.name,
                        mapItem?.address?.shortAddress
                    ]
                    .compactMap { part -> String? in
                        let trimmed = part?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        return trimmed.isEmpty ? nil : trimmed
                    }

                    if namedParts.isEmpty, let fullAddress = mapItem?.address?.fullAddress {
                        namedParts = [fullAddress]
                    }

                    continuation.resume(returning: Self.displayName(from: namedParts))
                }
            }
        }

        return "Current location"
    }

    private static func displayName(from namedParts: [String]) -> String {
        guard !namedParts.isEmpty else {
            return "Current location"
        }

        let uniqueParts = Array(NSOrderedSet(array: namedParts)) as? [String] ?? namedParts
        return uniqueParts.prefix(2).joined(separator: ", ")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation = authorizationContinuation else {
            return
        }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            authorizationContinuation = nil
            continuation.resume()
        case .denied, .restricted:
            authorizationContinuation = nil
            continuation.resume(throwing: LocationLookupError.permissionDenied)
        case .notDetermined:
            break
        @unknown default:
            authorizationContinuation = nil
            continuation.resume(throwing: LocationLookupError.permissionDenied)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation = locationContinuation else {
            return
        }

        locationContinuation = nil

        if let location = locations.last {
            continuation.resume(returning: location)
        } else {
            continuation.resume(throwing: LocationLookupError.locationUnavailable)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation = locationContinuation else {
            return
        }

        locationContinuation = nil
        continuation.resume(throwing: error)
    }
}

enum LocationLookupError: LocalizedError {
    case servicesDisabled
    case permissionDenied
    case locationUnavailable
    case requestInProgress

    var errorDescription: String? {
        switch self {
        case .servicesDisabled:
            "Location services are turned off for this device."
        case .permissionDenied:
            "Location permission is needed to attach your current location."
        case .locationUnavailable:
            "ChillMate could not find your current location."
        case .requestInProgress:
            "ChillMate is already checking your location."
        }
    }
}
