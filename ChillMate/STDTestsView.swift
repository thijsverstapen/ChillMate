import Foundation
import PhotosUI
import MapKit
import SwiftData
import SwiftUI
import UIKit

struct STDTestsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(ChillMateQueries.recentTests) private var tests: [STDTestRecord]
    @Query(ChillMateQueries.recentEntries) private var entries: [NightEntry]

    @State private var testDate = Date.now
    @State private var oralResult: STDResultStatus = .pending
    @State private var genitalResult: STDResultStatus = .pending
    @State private var analResult: STDResultStatus = .pending
    @State private var foundSTIs: [String] = []
    @State private var selectedSTI = STIOption.chlamydia.rawValue
    @State private var customSTIName = ""
    @State private var notes = ""
    @State private var isShowingDiscardWarning = false
    @State private var resultPhotoItem: PhotosPickerItem?
    @State private var resultPhotoData: Data?

    private var hasPositiveSelection: Bool {
        oralResult == .positive || genitalResult == .positive || analResult == .positive
    }

    private var hasUnsavedChanges: Bool {
        !Calendar.current.isDate(testDate, inSameDayAs: .now) ||
        oralResult != .pending ||
        genitalResult != .pending ||
        analResult != .pending ||
        !foundSTIs.isEmpty ||
        !customSTIName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        resultPhotoData != nil
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "STI tests"),
                            subtitle: String(localized: "Record test dates and fill in oral, genital, and anal results when they arrive. Save the test date now, then add results later; positive results can generate partner warning messages."),
                            symbol: "cross.case.fill",
                            tint: Color.chillMint
                        )

                        STIExposureGuideCard()

                        stdTestsViewContinued
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: saveTest) {
                        Text("Save").font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(Color.chillPrimary)
                }
            }
            .endEditingOnTap()
        }
    }

    /// Second half of `STDTestsView`'s body, which ran to 114 lines.
    ///
    /// Split purely for readability: these are the same views in the same
    /// order, still direct children of the same container.
    @ViewBuilder
    private var stdTestsViewContinued: some View {
            VStack(alignment: .leading, spacing: 14) {
                DatePicker("Test date", selection: $testDate, displayedComponents: [.date])
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
                    .tint(Color.chillMint)

                ResultPickerRow(title: String(localized: "Oral"), result: $oralResult)
                ResultPickerRow(title: String(localized: "Genital"), result: $genitalResult)
                ResultPickerRow(title: String(localized: "Anal"), result: $analResult)

                if hasPositiveSelection {
                    PositiveSTIDetailsDisclosure(
                        foundSTIs: $foundSTIs,
                        selectedSTI: $selectedSTI,
                        customSTIName: $customSTIName
                    )
                }

                TextField("Notes, clinic, or reference", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.chillText)
                    .padding(14)
                    .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                // Resolved outside the picker's Sendable label closure;
                // also makes the ternary actually hit the string catalog.
                let resultPhotoLabel = resultPhotoData == nil
                    ? String(localized: "Add photo of result")
                    : String(localized: "Change result photo")
                PhotosPicker(selection: $resultPhotoItem, matching: .images) {
                    Label(resultPhotoLabel, systemImage: "paperclip")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: false))

                if let data = resultPhotoData, let image = UIImage(data: data) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Button {
                            resultPhotoData = nil
                            resultPhotoItem = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white, .black.opacity(0.5))
                                .padding(8)
                        }
                        .accessibilityLabel("Remove result photo")
                    }
                }

                GlassActionButton(prominent: true, action: saveTest) {
                    Label("Save test", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .glassSurface(radius: 28, tint: Color.chillMint.opacity(0.10), interactive: true)
            .onChange(of: resultPhotoItem) { _, newItem in
                guard let newItem else { return }
                // The Task inherits the view's main actor, so the @State
                // assignment is safe without a MainActor.run hop.
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        resultPhotoData = await ChillImageOptimizer.downsampledJPEG(from: data, maxPixelSize: 1400, compressionQuality: 0.8)
                    }
                }
            }

            stdTestsViewContinuedTail
    }

    /// Second half of `STDTestsView`'s body, which ran to 126 lines.
    ///
    /// Split purely for readability: these are the same views in the same
    /// order, still direct children of the same container.
    @ViewBuilder
    private var stdTestsViewContinuedTail: some View {
            VStack(alignment: .leading, spacing: 12) {
                CareSectionTitle(title: String(localized: "Current and past STI tests"), symbol: "list.bullet.rectangle")

                if tests.isEmpty {
                    CareEmptyState(text: String(localized: "No STI tests saved yet."))
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(tests) { test in
                            STDTestCard(test: test, contacts: warningContacts(for: test))
                        }
                    }
                }
            }
    }

    private func saveTest() {
        let record = STDTestRecord(
            testDate: testDate,
            oralResult: oralResult,
            genitalResult: genitalResult,
            analResult: analResult,
            foundSTIs: hasPositiveSelection ? foundSTIs : [],
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            resultPhotoData: resultPhotoData
        )
        modelContext.insert(record)
        modelContext.saveChanges()

        Task {
            if (try? await NotificationService.shared.requestAuthorization()) == true {
                NotificationService.shared.scheduleSTDResultReminder(testID: record.id, dueDate: record.resultsDueDate)
            }
        }

        notes = ""
        foundSTIs = []
        selectedSTI = STIOption.chlamydia.rawValue
        customSTIName = ""
        oralResult = .pending
        genitalResult = .pending
        analResult = .pending
        testDate = .now
        resultPhotoData = nil
        resultPhotoItem = nil
    }

    private func warningContacts(for test: STDTestRecord) -> [SexPartnerRecord] {
        let lowerBound = Calendar.current.date(byAdding: .month, value: -6, to: test.testDate) ?? .distantPast
        var seenNumbers: Set<String> = []

        return entries
            .filter { $0.date >= lowerBound && $0.date <= test.testDate }
            .flatMap(\.partnerDetails)
            .filter { !$0.normalizedPhoneNumber.isEmpty }
            .filter { partner in
                let key = partner.normalizedPhoneNumber
                guard !seenNumbers.contains(key) else {
                    return false
                }
                seenNumbers.insert(key)
                return true
            }
    }
}

private struct STDTestCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Bindable var test: STDTestRecord
    let contacts: [SexPartnerRecord]
    @State private var selectedSTI = STIOption.chlamydia.rawValue
    @State private var customSTIName = ""
    @State private var positiveDetailsUnlocked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(test.testDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                    Text("Reminder: \(test.resultsDueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                }

                Spacer()

                Button(role: .destructive) {
                    RecentlyDeletedStore.record(
                        kind: "STI test",
                        title: String(localized: "STI test"),
                        detail: test.testDate.formatted(date: .abbreviated, time: .omitted)
                    )
                    modelContext.delete(test)
                    modelContext.saveChanges()
                } label: {
                    Image(systemName: "trash.fill")
                }
                .buttonStyle(ChillPlainButtonStyle())
                .foregroundStyle(Color.chillSecondary)
                .accessibilityLabel(String(localized: "Delete STI test"))
            }

            ResultPickerRow(title: String(localized: "Oral"), result: resultBinding(\.oralResult))
            ResultPickerRow(title: String(localized: "Genital"), result: resultBinding(\.genitalResult))
            ResultPickerRow(title: String(localized: "Anal"), result: resultBinding(\.analResult))

            if test.hasPositiveResult {
                if positiveDetailsUnlocked {
                    PositiveSTIDetailsDisclosure(
                        foundSTIs: foundSTIsBinding,
                        selectedSTI: $selectedSTI,
                        customSTIName: $customSTIName
                    )

                    STIWarningMessagePanel(
                        test: test,
                        contacts: contacts,
                        openMessage: { contact in
                            if let url = warningMessageURL(for: contact) {
                                openURL(url)
                            }
                        }
                    )
                } else {
                    Button {
                        Task {
                            if let ok = try? await AppAuthenticator.authenticate(reason: String(localized: "View positive STI result details")),
                               ok {
                                await MainActor.run { positiveDetailsUnlocked = true }
                            }
                        }
                    } label: {
                        Label("Unlock positive result details", systemImage: "lock.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .red))
                }
            }

            if !test.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(test.notes)
                    .font(.footnote)
                    .foregroundStyle(Color.chillSecondary)
            }

            // Attached result photo. For positive results it stays behind the same
            // authentication gate as the positive-result details.
            if let data = test.resultPhotoData,
               let image = UIImage(data: data),
               !test.hasPositiveResult || positiveDetailsUnlocked {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .glassSurface(radius: 24, tint: .black.opacity(0.04))
    }

    private var foundSTIsBinding: Binding<[String]> {
        Binding {
            test.foundSTIs
        } set: { newValue in
            test.foundSTIs = newValue
            modelContext.saveChanges()
        }
    }

    private func resultBinding(_ keyPath: ReferenceWritableKeyPath<STDTestRecord, String>) -> Binding<STDResultStatus> {
        Binding {
            STDResultStatus(rawValue: test[keyPath: keyPath]) ?? .pending
        } set: { newValue in
            test[keyPath: keyPath] = newValue.rawValue
            modelContext.saveChanges()
        }
    }

    private func warningMessageURL(for contact: SexPartnerRecord) -> URL? {
        var components = URLComponents()
        components.scheme = "sms"
        components.path = contact.normalizedPhoneNumber
        components.queryItems = [
            URLQueryItem(name: String(localized: "body"), value: warningMessage(for: contact))
        ]
        return components.url
    }

    private func warningMessage(for contact: SexPartnerRecord) -> String {
        let found = test.foundSTIs.isEmpty ? "an STI" : test.foundSTIs.joined(separator: ", ")
        let areas = positiveAreas
        let areaText = areas.isEmpty ? "" : " The positive result was marked for: \(areas.joined(separator: ", "))."
        return "Hi \(contact.displayName), I wanted to let you know that I recently had an STI test with a positive result for \(found).\(areaText) It may be a good idea to get tested and contact your GP or a sexual-health clinic. This is a private heads-up from ChillMate."
    }

    private var positiveAreas: [String] {
        [
            test.oralResult == STDResultStatus.positive.rawValue ? "oral" : nil,
            test.genitalResult == STDResultStatus.positive.rawValue ? "genital" : nil,
            test.analResult == STDResultStatus.positive.rawValue ? "anal" : nil
        ].compactMap(\.self)
    }
}

private enum STIOption: String, CaseIterable, Identifiable {
    case chlamydia = "Chlamydia"
    case gonorrhea = "Gonorrhea"
    case syphilis = "Syphilis"
    case hiv = "HIV"
    case hepatitisB = "Hepatitis B"
    case hepatitisC = "Hepatitis C"
    case herpes = "Herpes"
    case hpv = "HPV"
    case mycoplasma = "Mycoplasma genitalium"
    case trichomoniasis = "Trichomoniasis"
    case other = "Other"

    var id: String { rawValue }
}

private struct PositiveSTIDetailsDisclosure: View {
    @Binding var foundSTIs: [String]
    @Binding var selectedSTI: String
    @Binding var customSTIName: String

    private var canAdd: Bool {
        let candidate = candidateName
        return !candidate.isEmpty && !foundSTIs.contains(candidate)
    }

    private var candidateName: String {
        if selectedSTI == STIOption.other.rawValue {
            return customSTIName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return selectedSTI
    }

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Picker("STI", selection: $selectedSTI) {
                    ForEach(STIOption.allCases) { option in
                        Text(option.localizedDisplayName).tag(option.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .tint(.red)

                if selectedSTI == STIOption.other.rawValue {
                    TextField("Name the STI", text: $customSTIName)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.chillText)
                        .padding(14)
                        .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)
                }

                GlassActionButton(prominent: false, action: addSTI) {
                    Label("Add STI", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canAdd)
                .opacity(canAdd ? 1 : 0.55)

                if foundSTIs.isEmpty {
                    Text("Add one or more positive findings if you want them included in warning messages.")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(foundSTIs, id: \.self) { sti in
                            Button {
                                foundSTIs.removeAll { $0 == sti }
                            } label: {
                                Label(sti, systemImage: "xmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.chillText)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .glassSurface(radius: 14, tint: .red.opacity(0.12))
                            }
                            .buttonStyle(ChillPlainButtonStyle())
                        }
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Label("What was found", systemImage: "cross.case.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)
        }
        .padding(12)
        .glassSurface(radius: 18, tint: .red.opacity(0.08), interactive: true)
    }

    private func addSTI() {
        let candidate = candidateName
        guard !candidate.isEmpty, !foundSTIs.contains(candidate) else {
            return
        }

        foundSTIs.append(candidate)
        if selectedSTI == STIOption.other.rawValue {
            customSTIName = ""
        }
    }
}

private struct STIWarningMessagePanel: View {
    let test: STDTestRecord
    let contacts: [SexPartnerRecord]
    let openMessage: (SexPartnerRecord) -> Void

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                Text("Sending a warning is voluntary. Review and edit every message before it leaves Messages. A GP or sexual-health clinic can also help with partner notification.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if contacts.isEmpty {
                    Text("No partner phone numbers are saved in recent logs. Add phone numbers in a log to generate message shortcuts here.")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(contacts) { contact in
                        Button {
                            openMessage(contact)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "message.fill")
                                    .foregroundStyle(Color.chillMint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Message \(contact.displayName)")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.chillText)
                                    Text(contact.phoneNumber)
                                        .font(.caption)
                                        .foregroundStyle(Color.chillSecondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .glassSurface(radius: 16, tint: Color.chillMint.opacity(0.08), interactive: true)
                        }
                        .buttonStyle(ChillPlainButtonStyle())
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Generate iMessage warning", systemImage: "message.badge.waveform.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)
        }
        .padding(12)
        .glassSurface(radius: 18, tint: Color.chillMint.opacity(0.08), interactive: true)
    }
}

private struct STIExposureGuideCard: View {
    private let rows = [
        ("Oral", "Ask whether throat testing is included when oral exposure matters.", "May miss infections if only genital samples are tested."),
        ("Genital", "Covers genital swabs or urine samples depending on the clinic/test type.", "Does not automatically cover throat or rectal exposure."),
        ("Anal", "Ask for rectal testing when anal exposure matters.", "May be missed by urine-only or genital-only testing.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CareSectionTitle(title: String(localized: "What tests cover"), symbol: "cross.case.circle.fill")

            Text("Use oral, genital, and anal fields to match where testing was done. If you are unsure, mark pending and ask the clinic what samples were included.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(rows, id: \.0) { row in
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.0)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.chillText)
                    Text(row.1)
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                    Text(row.2)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillIconOrange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .glassSurface(radius: 18, tint: Color.chillMint.opacity(0.06))
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillMint.opacity(0.08))
    }
}

private struct ResultPickerRow: View {
    let title: String
    @Binding var result: STDResultStatus

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)

            Spacer()

            Picker(title, selection: $result) {
                ForEach(STDResultStatus.allCases) { status in
                    Text(status.localizedDisplayName).tag(status)
                }
            }
            .pickerStyle(.menu)
            .tint(result == .positive ? .red : Color.chillMint)
        }
        .padding(12)
        .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)
    }
}
