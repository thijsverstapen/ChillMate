import SwiftUI
import ChillMateCore

// The cards the night log is built from, each asking one thing.

struct LocationCaptureCard: View {
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
                    .buttonStyle(ChillPillButtonStyle(prominent: false))
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
                .buttonStyle(ChillPillButtonStyle(prominent: true))
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

struct PartnerCountCard: View {
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

                    Text("\(partnerCount) person")
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

struct SexPartnerDetailsCard: View {
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
                .buttonStyle(ChillPillButtonStyle(prominent: true))

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
                                .buttonStyle(ChillPlainButtonStyle())
                                .foregroundStyle(Color.chillSecondary)
                                .accessibilityLabel(String(localized: "Remove person"))
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
            String(localized: "Both top and bottom recorded")
        case (true, false):
            String(localized: "They were the bottom")
        case (false, true):
            String(localized: "You were the bottom")
        case (false, false):
            String(localized: "No position detail saved")
        }
    }
}

struct SaferSexCard: View {
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

struct TimeFrameCard: View {
    @Binding var startDate: Date
    @Binding var endDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Time frame", systemImage: "clock.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            VStack(spacing: 12) {
                DatePicker(
                    String(localized: "Started"),
                    selection: $startDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .tint(Color.chillAccentTeal)

                DatePicker(
                    String(localized: "Ended"),
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

struct SubstancePicker: View {
    @Binding var selectedSubstances: Set<Substance>
    @Binding var otherSubstance: String
    @Binding var didInjectDrugs: Bool
    @Binding var injectionSubstance: String
    @Binding var injectedSubstances: [String]
    let availableInjectionSubstances: [String]
    let columns: [GridItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Substances involved", systemImage: "pills.fill")
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
                    Toggle("Injection use happened", isOn: $didInjectDrugs)
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
                            .tint(Color.chillMint)

                            Button {
                                addInjectedSubstance()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(ChillPlainButtonStyle())
                            .foregroundStyle(Color.chillMint)
                            .accessibilityLabel(String(localized: "Add injected substance"))
                .accessibilityInputLabels([
                    String(localized: "Add"),
                    String(localized: "Add injected substance")
                ])
                        }

                        if injectedSubstances.isEmpty {
                            Text("Add one or more substances only if it helps with later health or STI support.")
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
                                    .buttonStyle(ChillPlainButtonStyle())
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                Label("Injection context", systemImage: "syringe.fill")
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
                Text(substance.localizedDisplayName)
                    .font(.subheadline.weight(.semibold))
                    .chillLineLimit(1, scale: 0.78)
            }
            .foregroundStyle(Color.chillText)
            .frame(maxWidth: .infinity, minHeight: 42)
            .padding(.horizontal, 10)
        }
        .buttonStyle(ChillPlainButtonStyle())
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

struct TriggerMapCard: View {
    @Binding var selectedTriggers: Set<ChillTrigger>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What led to this?", systemImage: "map.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("Optional. Tag anything that played a role so patterns are easier to notice later.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            FlowLayout(spacing: 8) {
                ForEach(ChillTrigger.allCases) { trigger in
                    SelectableTextChip(
                        title: trigger.localizedDisplayName,
                        isSelected: selectedTriggers.contains(trigger),
                        tint: Color.chillMint
                    ) {
                        toggle(trigger)
                    }
                }
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillMint.opacity(0.08))
    }

    private func toggle(_ trigger: ChillTrigger) {
        if selectedTriggers.contains(trigger) {
            selectedTriggers.remove(trigger)
        } else {
            selectedTriggers.insert(trigger)
        }
    }
}

struct WhatChangedInputCard: View {
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
                            title: reason.localizedDisplayName,
                            isSelected: selectedReasons.contains(reason),
                            tint: Color.chillSecondaryBlue
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
        .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08))
    }

    private func toggle(_ reason: ChangeReason) {
        if selectedReasons.contains(reason) {
            selectedReasons.remove(reason)
        } else {
            selectedReasons.insert(reason)
        }
    }
}

struct MemoryGapProtocolCard: View {
    @Binding var reportedMemoryGap: Bool
    @Binding var safeNow: Bool
    @Binding var injuries: Bool
    @Binding var consentConcern: Bool
    @Binding var needsHelp: Bool
    @Binding var notes: String

    @AppStorage(DefaultsKey.trustedContactPhone) private var trustedContactPhone = ""
    @Environment(\.openURL) private var openURL
    @State private var showSafetyCheck = false

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
                    Text("If you are unsafe, injured, cannot wake someone, or feel at risk, call \(EmergencyContactInfo.number) or a trusted person now.")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)
        .onChange(of: [injuries, consentConcern, needsHelp]) { oldValue, newValue in
            // Surface an actionable check the moment a concerning field is turned on
            // (being "safe right now" never triggers it).
            if newValue.contains(true) && !oldValue.contains(true) {
                showSafetyCheck = true
            }
        }
        .alert("Do you want to reach out for help?", isPresented: $showSafetyCheck) {
            Button("Call \(EmergencyContactInfo.number)", role: .destructive) { call(EmergencyContactInfo.number) }
            if !trustedContactPhone.isEmpty {
                Button("Call trusted contact") { call(trustedContactPhone) }
            }
            Button("Do nothing", role: .cancel) { }
        } message: {
            Text("You marked something that may need attention. You can reach out now, or just keep going. This stays private.")
        }
    }

    private func call(_ number: String) {
        let digits = number.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "tel://\(digits)") else { return }
        openURL(url)
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
        .buttonStyle(ChillPlainButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SkippedNightMessage: View {
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

struct SleepCheckCard: View {
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
                        .chillScaledFont(size: 42, relativeTo: .largeTitle)
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
