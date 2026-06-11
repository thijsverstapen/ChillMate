import Foundation
import PhotosUI
import MapKit
import SwiftData
import SwiftUI
import UIKit

enum CareToolPage: String, Identifiable {
    case safetyAutopilot
    case saferPlanning
    case stdTests
    case drugTimers
    case emergency
    case panicSupport
    case drugInfo
    case aftercare
    case combinationRisk
    case consentBoundaries
    case recoveryMode
    case privateInsights
    case helperBridge
    case drugChecking

    var id: String { rawValue }
}

struct CareToolDefinition: Identifiable {
    let page: CareToolPage
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var id: String { page.id }
}

struct CareToolsSection: View {
    let open: (CareToolPage) -> Void

    private let tools: [CareToolDefinition] = [
        CareToolDefinition(page: .safetyAutopilot, title: String(localized: "Safety autopilot"), subtitle: String(localized: "Helper summary & checking info"), symbol: "sparkles.rectangle.stack.fill", tint: Color.chillSecondaryBlue),
        CareToolDefinition(page: .emergency, title: String(localized: "Emergency Information"), subtitle: String(localized: "112, trusted contact, and location message"), symbol: "sos.circle.fill", tint: Color.chillIconRed),
        CareToolDefinition(page: .panicSupport, title: String(localized: "Panic support"), subtitle: String(localized: "Breathing, contact, and grounding"), symbol: "lungs.fill", tint: Color.chillIconPurple),
        CareToolDefinition(page: .saferPlanning, title: String(localized: "Plan"), subtitle: String(localized: "Before-Chill checklist"), symbol: "checkmark.shield.fill", tint: Color.chillMint),
        CareToolDefinition(page: .drugTimers, title: String(localized: "Check-ins"), subtitle: String(localized: "Recovery reminders"), symbol: "timer", tint: Color.chillIconAmber),
        CareToolDefinition(page: .aftercare, title: String(localized: "Aftercare"), subtitle: String(localized: "Check in tomorrow"), symbol: "heart.text.square.fill", tint: Color.chillIconPink),
        CareToolDefinition(page: .stdTests, title: String(localized: "STI tests"), subtitle: String(localized: "Dates and results"), symbol: "cross.case.fill", tint: Color.chillIconTeal),
        CareToolDefinition(page: .recoveryMode, title: String(localized: "Recovery mode"), subtitle: String(localized: "Goals and cravings"), symbol: "figure.mind.and.body", tint: Color.chillIconGreen)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {            CareSectionTitle(title: String(localized: "Care tools"), symbol: "heart.text.square.fill")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(tools) { tool in
                    CareToolCard(tool: tool, open: open)
                }
            }
        }
    }
}



struct InsightsToolsSection: View {
    let open: (CareToolPage) -> Void

    private let tools: [CareToolDefinition] = [
        CareToolDefinition(page: .combinationRisk, title: String(localized: "Risk checker"), subtitle: String(localized: "Safety signals"), symbol: "exclamationmark.shield.fill", tint: Color.chillIconOrange),
        CareToolDefinition(page: .drugInfo, title: String(localized: "Substance info"), subtitle: String(localized: "Safety reference"), symbol: "pills.fill", tint: Color.chillIconPurple),
        CareToolDefinition(page: .consentBoundaries, title: String(localized: "Boundaries"), subtitle: String(localized: "Consent and exit plan"), symbol: "hand.raised.fill", tint: Color.chillIconTeal),
        CareToolDefinition(page: .privateInsights, title: String(localized: "Insights"), subtitle: String(localized: "Private patterns"), symbol: "chart.xyaxis.line", tint: Color.chillSecondaryBlue)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CareSectionTitle(title: String(localized: "Insights"), symbol: "chart.xyaxis.line")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(tools) { tool in
                    CareToolCard(tool: tool, open: open)
                }
            }
        }
    }
}

private struct CareToolCard: View {
    let tool: CareToolDefinition
    let open: (CareToolPage) -> Void

    var body: some View {
        Button {
            open(tool.page)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tool.tint.opacity(0.20))
                        .frame(width: 42, height: 42)
                    Image(systemName: tool.symbol)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(tool.tint)
                        .symbolRenderingMode(.hierarchical)
                }
                .shadow(color: tool.tint.opacity(0.40), radius: 8, y: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(tool.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.chillText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                    Text(tool.subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .padding(14)
        }
        .buttonStyle(ChillPlainButtonStyle())
        .glassSurface(radius: 24, tint: .clear, interactive: true)
    }
}

struct STDTestsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \STDTestRecord.testDate, order: .reverse) private var tests: [STDTestRecord]
    @Query(sort: \NightEntry.date, order: .reverse) private var entries: [NightEntry]

    @State private var testDate = Date.now
    @State private var oralResult: STDResultStatus = .pending
    @State private var genitalResult: STDResultStatus = .pending
    @State private var analResult: STDResultStatus = .pending
    @State private var foundSTIs: [String] = []
    @State private var selectedSTI = STIOption.chlamydia.rawValue
    @State private var customSTIName = ""
    @State private var notes = ""
    @State private var isShowingDiscardWarning = false

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
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
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

                            GlassActionButton(prominent: true, action: saveTest) {
                                Label("Save test", systemImage: "checkmark.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: Color.chillMint.opacity(0.10), interactive: true)

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
        if hasUnsavedChanges {
            isShowingDiscardWarning = true
        } else {
            dismiss()
        }
    }

    private func saveTest() {
        let record = STDTestRecord(
            testDate: testDate,
            oralResult: oralResult,
            genitalResult: genitalResult,
            analResult: analResult,
            foundSTIs: hasPositiveSelection ? foundSTIs : [],
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(record)
        try? modelContext.save()

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
                    try? modelContext.save()
                } label: {
                    Image(systemName: "trash.fill")
                }
                .buttonStyle(ChillPlainButtonStyle())
                .foregroundStyle(Color.chillSecondary)
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
        }
        .padding(16)
        .glassSurface(radius: 24, tint: .black.opacity(0.04))
    }

    private var foundSTIsBinding: Binding<[String]> {
        Binding {
            test.foundSTIs
        } set: { newValue in
            test.foundSTIs = newValue
            try? modelContext.save()
        }
    }

    private func resultBinding(_ keyPath: ReferenceWritableKeyPath<STDTestRecord, String>) -> Binding<STDResultStatus> {
        Binding {
            STDResultStatus(rawValue: test[keyPath: keyPath]) ?? .pending
        } set: { newValue in
            test[keyPath: keyPath] = newValue.rawValue
            try? modelContext.save()
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
        return "Hi \(contact.displayName), I wanted to let you know that I recently had an STI test with a positive result for \(found).\(areaText) It may be a good idea to get tested and contact your GP, GGD, or sexual health clinic. This is a private heads-up from ChillMate."
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
                Text("Sending a warning is voluntary. Review and edit every message before it leaves Messages. A GP, GGD, or sexual-health clinic can also help with partner notification.")
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

struct SaferSessionPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SaferSessionPlan.createdAt, order: .reverse) private var plans: [SaferSessionPlan]

    @AppStorage("trustedContactName") private var trustedContactName = ""
    @AppStorage("trustedContactPhone") private var trustedContactPhone = ""

    @State private var plannedDate = Date.now
    @State private var sleepChecked = false
    @State private var hydrationChecked = false
    @State private var medicationInteractionChecked = false
    @State private var medicationNotes = ""
    @State private var plannedSubstanceLimits = ""
    @State private var emergencyContactReady = false
    @State private var transportPlanned = false
    @State private var transportPlan = ""
    @State private var condomsPacked = false
    @State private var lubePacked = false
    @State private var prepTaken = false
    @State private var prepRemindersEnabled = false
    @State private var dontMixAcknowledged = false
    @State private var partnerModeEnabled = false
    @State private var sharedSafetyPlan = ""
    @State private var agreedBoundaries = ""
    @State private var groupMemberName = ""
    @State private var groupMemberNames: [String] = []
    @State private var groupCheckInMinutes = 90
    @State private var aftercareReminderForEveryone = false
    @State private var endingDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date.now) ?? Date.now.addingTimeInterval(4 * 60 * 60)
    @State private var isShowingDiscardWarning = false

    private var riskAssessment: SaferPlanRiskAssessment {
        SaferPlanRiskAssessment(
            sleepChecked: sleepChecked,
            hydrationChecked: hydrationChecked,
            medicationInteractionChecked: medicationInteractionChecked,
            plannedSubstanceLimits: plannedSubstanceLimits,
            emergencyContactReady: emergencyContactReady,
            transportPlanned: transportPlanned,
            transportPlan: transportPlan,
            condomsPacked: condomsPacked,
            lubePacked: lubePacked,
            prepTaken: prepTaken,
            dontMixAcknowledged: dontMixAcknowledged,
            partnerModeEnabled: partnerModeEnabled,
            agreedBoundaries: agreedBoundaries,
            plannedDate: plannedDate,
            endingDate: endingDate
        )
    }

    private var completedCount: Int {
        [
            sleepChecked,
            hydrationChecked,
            medicationInteractionChecked,
            emergencyContactReady,
            transportPlanned,
            condomsPacked,
            lubePacked,
            prepTaken,
            dontMixAcknowledged
        ].filter { $0 }.count
    }

    private var canSavePlan: Bool {
        dontMixAcknowledged &&
        endingDate > plannedDate &&
        (!transportPlanned || !transportPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var hasUnsavedChanges: Bool {
        !Calendar.current.isDate(plannedDate, equalTo: .now, toGranularity: .minute) ||
        abs(endingDate.timeIntervalSince(Date.now.addingTimeInterval(4 * 60 * 60))) > 60 ||
        sleepChecked ||
        hydrationChecked ||
        medicationInteractionChecked ||
        !medicationNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !plannedSubstanceLimits.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        emergencyContactReady ||
        transportPlanned ||
        !transportPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        condomsPacked ||
        lubePacked ||
        prepTaken ||
        prepRemindersEnabled ||
        dontMixAcknowledged ||
        partnerModeEnabled ||
        !sharedSafetyPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !agreedBoundaries.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !groupMemberNames.isEmpty ||
        groupCheckInMinutes != 90 ||
        aftercareReminderForEveryone
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Safer plan"),
                            subtitle: String(localized: "Set the basics before a Chill starts: rest, water, limits, travel, contacts, condoms, lube, and combinations to avoid. Use the checks as a practical stop point; saving can schedule ending-time reminders and PrEP prompts."),
                            symbol: "checkmark.shield.fill",
                            tint: Color.chillMint
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                CareSectionTitle(title: String(localized: "This Chill"), symbol: "calendar.badge.clock")
                                Spacer()
                                Text("\(completedCount)/9")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(Color.chillMint)
                            }

                            DatePicker("Planned time", selection: $plannedDate, displayedComponents: [.date, .hourAndMinute])
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.chillText)
                                .tint(.green)

                            DatePicker("Ending time", selection: $endingDate, displayedComponents: [.date, .hourAndMinute])
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.chillText)
                                .tint(.green)

                            SaferPlanToggle(title: String(localized: "Sleep check"), subtitle: String(localized: "I have enough rest or a realistic plan to stop."), symbol: "bed.double.fill", isOn: $sleepChecked)
                            SaferPlanToggle(title: String(localized: "Hydration check"), subtitle: String(localized: "Water or electrolytes are ready before leaving."), symbol: "drop.fill", isOn: $hydrationChecked)
                            SaferPlanToggle(title: String(localized: "Medication interaction check"), subtitle: String(localized: "Current meds and substances have been checked."), symbol: "pills.fill", isOn: $medicationInteractionChecked)

                            TextField("Current meds or interaction notes", text: $medicationNotes, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color.chillText)
                                .padding(14)
                                .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                            TextField("Personal boundaries for the night", text: $plannedSubstanceLimits, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color.chillText)
                                .padding(14)
                                .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: .green.opacity(0.10), interactive: true)

                        VStack(alignment: .leading, spacing: 14) {
                            CareSectionTitle(title: String(localized: "Support and supplies"), symbol: "bag.fill")

                            SaferPlanToggle(title: String(localized: "Emergency contact"), subtitle: contactSubtitle, symbol: "person.crop.circle.badge.checkmark", isOn: $emergencyContactReady)
                            SaferPlanToggle(title: String(localized: "Transport"), subtitle: String(localized: "A way home is planned before the Chill starts."), symbol: "car.fill", isOn: $transportPlanned)
                            if transportPlanned {
                                TextField("What is the transport plan?", text: $transportPlan, axis: .vertical)
                                    .lineLimit(1...3)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(Color.chillText)
                                    .padding(14)
                                    .glassSurface(radius: 18, tint: transportPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .red.opacity(0.08) : .black.opacity(0.04), interactive: true)

                                if transportPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Add the plan before saving.")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.red)
                                }
                            }
                            SaferPlanToggle(title: String(localized: "Condoms"), subtitle: String(localized: "Condoms are packed or available."), symbol: "checkmark.seal.fill", isOn: $condomsPacked)
                            SaferPlanToggle(title: String(localized: "Lube"), subtitle: String(localized: "Lube is packed or available."), symbol: "drop.circle.fill", isOn: $lubePacked)
                            SaferPlanToggle(title: String(localized: "PrEP taken"), subtitle: String(localized: "I have taken PrEP as planned."), symbol: "cross.case.fill", isOn: $prepTaken)
                            SaferPlanToggle(title: String(localized: "PrEP reminders"), subtitle: String(localized: "Schedule around-sex PrEP reminders for this plan."), symbol: "bell.badge.fill", isOn: $prepRemindersEnabled)
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: Color.chillMint.opacity(0.10), interactive: true)

                        PrepGuideCard()

                        DontMixWarningCard(isAcknowledged: $dontMixAcknowledged)

                        SaferPlanRiskCard(assessment: riskAssessment)

                        PartnerSessionModeCard(
                            isEnabled: $partnerModeEnabled,
                            sharedSafetyPlan: $sharedSafetyPlan,
                            agreedBoundaries: $agreedBoundaries,
                            groupMemberName: $groupMemberName,
                            groupMemberNames: $groupMemberNames,
                            groupCheckInMinutes: $groupCheckInMinutes,
                            aftercareReminderForEveryone: $aftercareReminderForEveryone
                        )

                        GlassActionButton(prominent: true, action: savePlan) {
                            Label("Save plan", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(!canSavePlan)
                        .opacity(canSavePlan ? 1 : 0.55)

                        if !plans.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                CareSectionTitle(title: String(localized: "Current and past plans"), symbol: "clock.arrow.circlepath")

                                LazyVStack(spacing: 12) {
                                    ForEach(plans) { plan in
                                        SaferPlanCard(plan: plan)
                                    }
                                }
                            }
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
            .toolbarBackground(.hidden, for: .navigationBar)
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
            .onChange(of: plannedDate) { _, newDate in
                if endingDate <= newDate {
                    endingDate = Calendar.current.date(byAdding: .hour, value: 4, to: newDate) ?? newDate.addingTimeInterval(4 * 60 * 60)
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

    private var contactSubtitle: String {
        if trustedContactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Add a trusted contact in Emergency Information."
        }

        if trustedContactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(trustedContactName) is selected; add a phone number when possible."
        }

        return "\(trustedContactName) is ready."
    }

    private func savePlan() {
        let plan = SaferSessionPlan(
            plannedDate: plannedDate,
            endingDate: endingDate,
            sleepChecked: sleepChecked,
            hydrationChecked: hydrationChecked,
            medicationInteractionChecked: medicationInteractionChecked,
            medicationNotes: medicationNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            plannedSubstanceLimits: plannedSubstanceLimits.trimmingCharacters(in: .whitespacesAndNewlines),
            emergencyContactReady: emergencyContactReady,
            transportPlanned: transportPlanned,
            transportPlan: transportPlan.trimmingCharacters(in: .whitespacesAndNewlines),
            condomsPacked: condomsPacked,
            lubePacked: lubePacked,
            prepTaken: prepTaken,
            dontMixAcknowledged: dontMixAcknowledged,
            partnerModeEnabled: partnerModeEnabled,
            sharedSafetyPlan: sharedSafetyPlan.trimmingCharacters(in: .whitespacesAndNewlines),
            agreedBoundaries: agreedBoundaries.trimmingCharacters(in: .whitespacesAndNewlines),
            groupMemberNames: groupMemberNames,
            groupCheckInMinutes: groupCheckInMinutes,
            aftercareReminderForEveryone: aftercareReminderForEveryone
        )
        modelContext.insert(plan)
        try? modelContext.save()

        Task {
            if (try? await NotificationService.shared.requestAuthorization()) == true {
                NotificationService.shared.scheduleSaferPlanReminders(planID: plan.id, endingAt: plan.endingDate)
                NotificationService.shared.scheduleSessionCheckIns(
                    id: plan.id,
                    startsAt: plan.plannedDate,
                    endsAt: plan.endingDate,
                    destination: .saferPlan
                )
                if prepRemindersEnabled {
                    NotificationService.shared.schedulePrepReminders(planID: plan.id, plannedSexAt: plan.plannedDate)
                }
            }
        }

        plannedDate = .now
        endingDate = Calendar.current.date(byAdding: .hour, value: 4, to: plannedDate) ?? plannedDate.addingTimeInterval(4 * 60 * 60)
        sleepChecked = false
        hydrationChecked = false
        medicationInteractionChecked = false
        medicationNotes = ""
        plannedSubstanceLimits = ""
        emergencyContactReady = false
        transportPlanned = false
        transportPlan = ""
        condomsPacked = false
        lubePacked = false
        prepTaken = false
        prepRemindersEnabled = false
        dontMixAcknowledged = false
        partnerModeEnabled = false
        sharedSafetyPlan = ""
        agreedBoundaries = ""
        groupMemberName = ""
        groupMemberNames = []
        groupCheckInMinutes = 90
        aftercareReminderForEveryone = false
    }
}

private struct SaferPlanToggle: View {
    let title: String
    let subtitle: String
    let symbol: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isOn ? .green : Color.chillSecondary)
                    .frame(width: 32, height: 32)
                    .glassSurface(radius: 16, tint: (isOn ? Color.green : Color.black).opacity(0.08))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.chillText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(.green)
    }
}

private struct DontMixWarningCard: View {
    @Binding var isAcknowledged: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Do not mix these", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 8) {
                WarningLine(text: String(localized: "GHB or GBL with alcohol, benzos, opioids, or ketamine"))
                WarningLine(text: String(localized: "Multiple stimulants such as cocaine, 3MMC, and MDMA"))
                WarningLine(text: String(localized: "Poppers with Viagra, Kamagra, or other erectile dysfunction medication"))
                WarningLine(text: String(localized: "Injection use, shared equipment, unknown amounts, or pressure to continue"))
                WarningLine(text: String(localized: "Unknown substances with anything else"))
            }

            Toggle("I have read this warning", isOn: $isAcknowledged)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)
                .tint(.orange)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .orange.opacity(0.12), interactive: true)
    }
}

private struct SaferPlanRiskAssessment {
    let score: Int

    init(
        sleepChecked: Bool,
        hydrationChecked: Bool,
        medicationInteractionChecked: Bool,
        plannedSubstanceLimits: String,
        emergencyContactReady: Bool,
        transportPlanned: Bool,
        transportPlan: String,
        condomsPacked: Bool,
        lubePacked: Bool,
        prepTaken: Bool,
        dontMixAcknowledged: Bool,
        partnerModeEnabled: Bool,
        agreedBoundaries: String,
        plannedDate: Date,
        endingDate: Date
    ) {
        var score = 0
        if !sleepChecked { score += 1 }
        if !hydrationChecked { score += 1 }
        if !medicationInteractionChecked { score += 2 }
        if plannedSubstanceLimits.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 2 }
        if !emergencyContactReady { score += 1 }
        if !transportPlanned || transportPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 1 }
        if !condomsPacked { score += 1 }
        if !lubePacked { score += 1 }
        if !prepTaken { score += 1 }
        if !dontMixAcknowledged { score += 3 }
        if partnerModeEnabled && agreedBoundaries.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 1 }
        if endingDate.timeIntervalSince(plannedDate) > 8 * 60 * 60 { score += 1 }
        self.score = score
    }

    var level: String {
        switch score {
        case 0...2:
            String(localized: "Low")
        case 3...6:
            String(localized: "Caution")
        default:
            String(localized: "High-risk")
        }
    }

    var color: Color {
        switch score {
        case 0...2:
            .green
        case 3...6:
            .orange
        default:
            .red
        }
    }

    var advice: String {
        switch score {
        case 0...2:
            String(localized: "Your plan has the basics covered. Keep it simple, check in with yourself, and leave room to stop early.")
        case 3...6:
            String(localized: "A few supports are missing. Consider adding limits, water, transport, and a person you can call before you start.")
        default:
            String(localized: "This plan has several risk points. Slow down, remove unknowns, avoid mixing, and consider postponing or talking to someone you trust.")
        }
    }
}

private struct SaferPlanRiskCard: View {
    let assessment: SaferPlanRiskAssessment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(assessment.color)
                    .frame(width: 38, height: 38)
                    .glassSurface(radius: 19, tint: assessment.color.opacity(0.14))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Plan risk: \(assessment.level)")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                    Text("Score \(assessment.score)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(assessment.color)
                }
            }

            Text(assessment.advice)
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: assessment.color.opacity(0.10), interactive: true)
    }
}

private struct PartnerSessionModeCard: View {
    @Binding var isEnabled: Bool
    @Binding var sharedSafetyPlan: String
    @Binding var agreedBoundaries: String
    @Binding var groupMemberName: String
    @Binding var groupMemberNames: [String]
    @Binding var groupCheckInMinutes: Int
    @Binding var aftercareReminderForEveryone: Bool

    private var canAddMember: Bool {
        !groupMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Use partner / group session mode", isOn: $isEnabled)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.chillText)
                    .tint(Color.chillPrimary)

                if isEnabled {
                    TextField("Shared safety plan", text: $sharedSafetyPlan, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.chillText)
                        .padding(14)
                        .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                    TextField("Agreed boundaries", text: $agreedBoundaries, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.chillText)
                        .padding(14)
                        .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                    Stepper(value: $groupCheckInMinutes, in: 30...180, step: 15) {
                        Text("Check-in every \(groupCheckInMinutes) min")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.chillText)
                    }
                    .tint(Color.chillPrimary)

                    Toggle("Aftercare reminders for everyone", isOn: $aftercareReminderForEveryone)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                        .tint(Color.chillPrimary)

                    HStack(spacing: 10) {
                        TextField("Add person", text: $groupMemberName)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Color.chillText)
                            .padding(12)
                            .glassSurface(radius: 16, tint: .black.opacity(0.04), interactive: true)

                        Button(action: addMember) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .frame(width: 38, height: 38)
                        }
                        .buttonStyle(ChillPlainButtonStyle())
                        .foregroundStyle(canAddMember ? Color.chillPrimary : Color.chillTertiary)
                        .disabled(!canAddMember)
                    }

                    FlowLayout(spacing: 8) {
                        ForEach(Array(groupMemberNames.enumerated()), id: \.offset) { index, name in
                            Button {
                                guard groupMemberNames.indices.contains(index) else { return }
                                groupMemberNames.remove(at: index)
                            } label: {
                                Label(name, systemImage: "xmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.chillText)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .glassSurface(radius: 14, tint: Color.chillPrimary.opacity(0.12))
                            }
                            .buttonStyle(ChillPlainButtonStyle())
                        }
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Partner / group session mode", systemImage: "person.3.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)
    }

    private func addMember() {
        let name = groupMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return
        }

        if !groupMemberNames.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            groupMemberNames.append(name)
        }
        groupMemberName = ""
    }
}

private struct PrepGuideCard: View {
    private let steps = [
        String(localized: "Use this only for around-sex PrEP when PrEP is not taken daily."),
        String(localized: "Follow the exact timing and amount from your prescriber or GGD."),
        String(localized: "Set reminders from your own prescription instructions."),
        String(localized: "If anything feels unclear, contact your prescriber, GGD, or pharmacist before relying on the plan.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CareSectionTitle(title: String(localized: "Around-sex PrEP guide"), symbol: "cross.case.fill")

            Text("This is a reminder aid, not a PrEP prescription or dosage guide. Use it only if PrEP has been prescribed to you and your clinician has told you this schedule fits your body and sex type.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.chillMint))

                    Text(step)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillMint.opacity(0.08))
    }
}

private struct WarningLine: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "xmark.octagon.fill")
            .font(.callout)
            .foregroundStyle(Color.chillSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SaferPlanCard: View {
    @Environment(\.modelContext) private var modelContext
    let plan: SaferSessionPlan

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.chillMint)
                .frame(width: 42, height: 42)
                .glassSurface(radius: 21, tint: Color.chillMint.opacity(0.10))

            VStack(alignment: .leading, spacing: 5) {
                Text(plan.plannedDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                    .foregroundStyle(Color.chillText)

                Text("Ends \(plan.endingDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)

                Text("\(plan.completedCount)/9 checks done")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillMint)

                if plan.transportPlanned, !plan.transportPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Transport: \(plan.transportPlan)")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .lineLimit(2)
                }

                if !plan.plannedSubstanceLimits.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(plan.plannedSubstanceLimits)
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button(role: .destructive) {
                RecentlyDeletedStore.record(
                    kind: "Plan",
                    title: String(localized: "Before-Chill plan"),
                    detail: plan.plannedDate.formatted(date: .abbreviated, time: .shortened)
                )
                modelContext.delete(plan)
                try? modelContext.save()
            } label: {
                Image(systemName: "trash.fill")
            }
            .buttonStyle(ChillPlainButtonStyle())
            .foregroundStyle(Color.chillSecondary)
        }
        .padding(16)
        .glassSurface(radius: 24, tint: .black.opacity(0.04))
    }
}

struct DrugTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("drugTimerTrackedPeople") private var trackedPeopleData = Data("[]".utf8)
    @Query(sort: \DrugDoseTimerRecord.startedAt, order: .reverse) private var timers: [DrugDoseTimerRecord]
    @Query(sort: \UserProfile.createdAt, order: .forward) private var profiles: [UserProfile]

    @State private var selectedSubstance: Substance = .cannabis
    @State private var timerScope: TimerScope = .myself
    @State private var selectedAdministrationRoute: AdministrationRoute?
    @State private var selectedTrackedPerson = ""
    @State private var newTrackedPerson = ""
    @State private var startedAt = Date.now
    @State private var doseNote = ""
    @State private var isShowingDiscardWarning = false

    private let timerSubstances = Substance.allCases.filter { $0 != .unknown && $0 != .other }

    private var adjustedDefaultDuration: Double {
        guard let profile = profiles.first else {
            return selectedSubstance.defaultTimerHours
        }

        return selectedSubstance.adjustedTimerHours(weightKg: profile.weightKg, heightCm: profile.heightCm)
    }

    private var profileAdjustmentCaption: String {
        guard let profile = profiles.first else {
            return "Add height and weight in Profile to personalize the reminder window."
        }

        return "Reminder window adjusted from \(Int(profile.weightKg.rounded())) kg and \(Int(profile.heightCm.rounded())) cm."
    }

    private var trackedPeople: [String] {
        (try? JSONDecoder().decode([String].self, from: trackedPeopleData)) ?? []
    }

    private var visibleTimers: [DrugDoseTimerRecord] {
        timers.filter { timer in
            let isOther = !timer.personName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return timerScope == .myself ? !isOther : isOther
        }
    }

    private var canStartTimer: Bool {
        selectedAdministrationRoute != nil &&
        (timerScope == .myself || !selectedTrackedPerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var hasUnsavedChanges: Bool {
        selectedSubstance != .cannabis ||
        timerScope != .myself ||
        selectedAdministrationRoute != nil ||
        !selectedTrackedPerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !newTrackedPerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !Calendar.current.isDate(startedAt, equalTo: .now, toGranularity: .minute) ||
        !doseNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Check-in timers"),
                            subtitle: String(localized: "Set private wellbeing reminders after a substance-related log. This is for reflection and support, not dosing advice or a safety approval."),
                            symbol: "timer",
                            tint: Color.chillSecondaryBlue
                        )

                        MedicalSafetyDisclaimerCard(compact: true)

                        VStack(alignment: .leading, spacing: 14) {
                            Picker("Timer type", selection: $timerScope) {
                                ForEach(TimerScope.allCases) { scope in
                                    Text(scope.localizedDisplayName).tag(scope)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(4)
                            .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                            if timerScope == .others {
                                TimerPeopleManager(
                                    people: trackedPeople,
                                    selectedPerson: $selectedTrackedPerson,
                                    newPerson: $newTrackedPerson,
                                    addPerson: addTrackedPerson,
                                    removePerson: removeTrackedPerson
                                )
                            }

                            Picker("Substance", selection: $selectedSubstance) {
                                ForEach(timerSubstances) { substance in
                                    Text(substance.localizedDisplayName).tag(substance)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.chillSecondaryBlue)

                            AdministrationRoutePicker(selectedRoute: $selectedAdministrationRoute)

                            DatePicker("Taken at", selection: $startedAt, displayedComponents: [.date, .hourAndMinute])
                                .tint(Color.chillSecondaryBlue)

                            StaticEffectWindowSummary(
                                substance: selectedSubstance,
                                adjustedDuration: adjustedDefaultDuration,
                                profileCaption: profileAdjustmentCaption
                            )

                            TextField("Private note, optional", text: $doseNote)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color.chillText)
                                .padding(14)
                                .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                            GlassActionButton(prominent: true, action: startTimer) {
                                Label("Start check-in", systemImage: "timer.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(!canStartTimer)
                            .opacity(canStartTimer ? 1 : 0.55)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                        .padding(16)
                        .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.10), interactive: true)

                        VStack(alignment: .leading, spacing: 12) {
                            CareSectionTitle(title: String(localized: "Current and past check-ins"), symbol: "clock.arrow.circlepath")

                            let activeTimers = visibleTimers.filter { $0.endsAt > .now }
                            let pastTimers = visibleTimers.filter { $0.endsAt <= .now }

                            if visibleTimers.isEmpty {
                                CareEmptyState(text: String(localized: "No timers yet."))
                            } else {
                                if !activeTimers.isEmpty {
                                    TimelineView(.periodic(from: .now, by: 60)) { context in
                                        LazyVStack(spacing: 12) {
                                            ForEach(activeTimers) { timer in
                                                DrugTimerCard(timer: timer, now: context.date)
                                            }
                                        }
                                    }
                                }

                                if !pastTimers.isEmpty {
                                    LazyVStack(spacing: 12) {
                                        ForEach(pastTimers) { timer in
                                            DrugTimerCard(timer: timer, now: .now)
                                        }
                                    }
                                }
                            }
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
            .toolbarBackground(.hidden, for: .navigationBar)
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
            .onReceive(NotificationCenter.default.publisher(for: .chillMateRefreshTimers)) { _ in
                Task { @MainActor in
                    for timer in timers where !timer.liveActivityID.isEmpty {
                        await DrugTimerLiveActivityController.update(timer)
                    }
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

    private func startTimer() {
        guard let route = selectedAdministrationRoute else {
            return
        }

        let timer = DrugDoseTimerRecord(
            substanceName: selectedSubstance.rawValue,
            startedAt: startedAt,
            durationHours: adjustedDefaultDuration,
            administrationRoute: route,
            personName: timerScope == .others ? selectedTrackedPerson.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            doseNote: doseNote.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        modelContext.insert(timer)
        try? modelContext.save()
        DrugTimerLiveActivityController.start(for: timer)
        try? modelContext.save()

        Task {
            if (try? await NotificationService.shared.requestAuthorization()) == true {
                NotificationService.shared.scheduleSessionCheckIns(
                    id: timer.id,
                    startsAt: timer.startedAt,
                    endsAt: timer.endsAt,
                    destination: .timers
                )
            }
        }

        selectedSubstance = .cannabis
        selectedAdministrationRoute = nil
        startedAt = .now
        doseNote = ""
    }

    private func addTrackedPerson() {
        let name = newTrackedPerson.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return
        }

        var people = trackedPeople
        if !people.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            people.append(name)
            saveTrackedPeople(people)
        }
        selectedTrackedPerson = name
        newTrackedPerson = ""
    }

    private func removeTrackedPerson(_ name: String) {
        let people = trackedPeople.filter { $0 != name }
        saveTrackedPeople(people)
        if selectedTrackedPerson == name {
            selectedTrackedPerson = people.first ?? ""
        }
    }

    private func saveTrackedPeople(_ people: [String]) {
        trackedPeopleData = (try? JSONEncoder().encode(people)) ?? Data("[]".utf8)
    }
}

private enum TimerScope: String, CaseIterable, Identifiable {
    case myself = "Myself"
    case others = "Others"

    var id: String { rawValue }
}

private struct TimerPeopleManager: View {
    let people: [String]
    @Binding var selectedPerson: String
    @Binding var newPerson: String
    let addPerson: () -> Void
    let removePerson: (String) -> Void

    private var canAdd: Bool {
        !newPerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("People you support", systemImage: "person.2.badge.gearshape.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            HStack(spacing: 10) {
                TextField("Add a name", text: $newPerson)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.chillText)
                    .padding(12)
                    .glassSurface(radius: 16, tint: .black.opacity(0.04), interactive: true)

                Button(action: addPerson) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(ChillPlainButtonStyle())
                .foregroundStyle(canAdd ? Color.chillSecondaryBlue : Color.chillTertiary)
                .disabled(!canAdd)
            }

            if people.isEmpty {
                Text("Add someone before starting an \"Others\" check-in.")
                    .font(.caption)
                    .foregroundStyle(Color.chillSecondary)
            } else {
                Picker("Person", selection: $selectedPerson) {
                    Text("Choose person").tag("")
                    ForEach(people, id: \.self) { person in
                        Text(person).tag(person)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.chillSecondaryBlue)

                FlowLayout(spacing: 8) {
                    ForEach(people, id: \.self) { person in
                        Button {
                            selectedPerson = person
                        } label: {
                            HStack(spacing: 6) {
                                Text(person)
                                Image(systemName: selectedPerson == person ? "checkmark.circle.fill" : "circle")
                                Image(systemName: "xmark.circle.fill")
                                    .onTapGesture {
                                        removePerson(person)
                                    }
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.chillText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .glassSurface(radius: 14, tint: (selectedPerson == person ? Color.chillSecondaryBlue : Color.black).opacity(0.10), interactive: true)
                        }
                        .buttonStyle(ChillPlainButtonStyle())
                    }
                }
            }
        }
        .padding(14)
        .glassSurface(radius: 22, tint: Color.chillSecondaryBlue.opacity(0.08), interactive: true)
    }
}

private struct AdministrationRoutePicker: View {
    @Binding var selectedRoute: AdministrationRoute?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Label("Route context", systemImage: "checklist")
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
                Text("Required")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondaryBlue)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(AdministrationRoute.allCases) { route in
                    let isSelected = selectedRoute == route
                    Button {
                        selectedRoute = route
                    } label: {
                        Label(route.displayName, systemImage: route.symbolName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isSelected ? Color.chillSecondaryBlue : Color.chillText)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ChillPlainButtonStyle())
                    .glassSurface(
                        radius: 18,
                        tint: isSelected ? Color.chillSecondaryBlue.opacity(0.30) : Color.black.opacity(0.04),
                        interactive: true
                    )
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.chillSecondaryBlue, lineWidth: 1.5)
                        }
                    }
                }
            }
        }
    }
}

private struct StaticEffectWindowSummary: View {
    let substance: Substance
    let adjustedDuration: Double
    let profileCaption: String

    private var normalizedPosition: Double {
        let range = substance.effectWindow
        let span = max(0.1, range.upperBound - range.lowerBound)
        return min(1, max(0, (adjustedDuration - range.lowerBound) / span))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Private check-in window: \(adjustedDuration.formatted(.number.precision(.fractionLength(1)))) h")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.chillSecondaryBlue.opacity(0.16))
                    Capsule()
                        .fill(Color.chillSecondaryBlue.opacity(0.82))
                        .frame(width: max(10, proxy.size.width * normalizedPosition))
                }
            }
            .frame(height: 10)

            Text("This is a reminder window for checking wellbeing, water, rest, consent, and support. It does not estimate impairment or recommend timing, amounts, or use.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(profileCaption)
                .font(.caption)
                .foregroundStyle(Color.chillSecondary)
        }
        .padding(12)
        .glassSurface(radius: 18, tint: Color.chillSecondaryBlue.opacity(0.08))
    }
}

private struct DrugTimerCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var timer: DrugDoseTimerRecord
    let now: Date

    private var isActive: Bool {
        timer.endsAt > now
    }

    private var progress: Double {
        let total = max(60, timer.endsAt.timeIntervalSince(timer.startedAt))
        let elapsed = max(0, now.timeIntervalSince(timer.startedAt))
        return min(1, elapsed / total)
    }

    private var redoseDecision: RedoseDecision {
        RedoseDecision(rawValue: timer.redoseDecision) ?? .undecided
    }

    private var shouldShowRedoseNudge: Bool {
        timer.redoseNudgeIsActive(at: now) && redoseDecision == .undecided
    }

    private var remainingText: String {
        let interval = max(0, timer.endsAt.timeIntervalSince(now))
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours) h \(minutes) min left"
        }
        return "\(minutes) min left"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "timer")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isActive ? Color.chillSecondaryBlue : Color.chillSecondary)
                    .frame(width: 42, height: 42)
                    .glassSurface(radius: 21, tint: (isActive ? Color.chillSecondaryBlue : Color.black).opacity(0.10))

                VStack(alignment: .leading, spacing: 5) {
                    Text(timer.substanceName)
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                    Text(isActive ? remainingText : String(localized: "Check-in ended"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isActive ? Color.chillSecondaryBlue : Color.chillSecondary)
                    Text("Until \(timer.endsAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                    if !timer.doseNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(timer.doseNote)
                            .font(.footnote)
                            .foregroundStyle(Color.chillSecondary)
                            .lineLimit(2)
                    }

                    if redoseDecision != .undecided {
                        Text(redoseDecision.displayTitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(redoseDecision == .avoided ? Color.chillMint : .orange)
                    }
                }

                Spacer()

                Button(role: .destructive) {
                    Task {
                        await DrugTimerLiveActivityController.end(timer)
                    }
                    RecentlyDeletedStore.record(
                        kind: "Timer",
                        title: "\(timer.substanceName) timer",
                        detail: timer.startedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                    modelContext.delete(timer)
                    try? modelContext.save()
                } label: {
                    Image(systemName: "trash.fill")
                }
                .buttonStyle(ChillPlainButtonStyle())
                .foregroundStyle(Color.chillSecondary)
            }

            if isActive {
                ProgressView(value: progress)
                    .tint(progress >= 0.4 ? .orange : Color.chillSecondaryBlue)
            }

            if shouldShowRedoseNudge {
                RedoseNudgeCard(
                    progress: progress,
                    previousDoseText: "\(timer.substanceName) at \(timer.startedAt.formatted(date: .omitted, time: .shortened))",
                    avoid: { saveRedoseDecision(.avoided) },
                    redose: { saveRedoseDecision(.redosed) }
                )
            }
        }
        .padding(16)
        .glassSurface(radius: 24, tint: .black.opacity(0.04))
        .task(id: Int(now.timeIntervalSinceReferenceDate / 60)) {
            guard isActive else {
                return
            }
            await DrugTimerLiveActivityController.update(timer, now: now)
        }
    }

    private func saveRedoseDecision(_ decision: RedoseDecision) {
        timer.redoseDecision = decision.rawValue
        timer.redoseDecisionAt = .now
        try? modelContext.save()
        Task {
            await DrugTimerLiveActivityController.update(timer, now: now)
        }
    }
}

private struct RedoseNudgeCard: View {
    let progress: Double
    let previousDoseText: String
    let avoid: () -> Void
    let redose: () -> Void
    @State private var isConfirmingRedose = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Pause before continuing", systemImage: "hand.raised.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text("If you feel pulled to continue, pause first. Check your body, water, food, sleep, consent, and whether someone trusted should know.")
                .font(.caption)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Earlier log: \(previousDoseText)")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillText)

            Text("Check-in progress: \(Int((progress * 100).rounded()))%")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)

            if isConfirmingRedose {
                ProgressView("Pause for 5 seconds")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondary)
            }

            HStack(spacing: 10) {
                Button(action: avoid) {
                    Label("I am stopping now", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: true))

                Button(action: delayedRedose) {
                    Text("Log that I continued")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: false))
                .disabled(isConfirmingRedose)
            }
        }
        .padding(14)
        .glassSurface(radius: 20, tint: .orange.opacity(0.10), interactive: true)
    }

    private func delayedRedose() {
        guard !isConfirmingRedose else { return }
        isConfirmingRedose = true
        Task {
            try? await Task.sleep(for: .seconds(5))
            await MainActor.run {
                isConfirmingRedose = false
                redose()
            }
        }
    }
}

struct CombinationRiskCheckerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RiskCheckRecord.createdAt, order: .reverse) private var riskChecks: [RiskCheckRecord]
    @Query(sort: \UserProfile.createdAt, order: .forward) private var profiles: [UserProfile]

    @State private var selectedSubstances: Set<Substance> = []
    @State private var medicationText = ""
    @State private var medicationDosage = ""
    @State private var medicationTakenAt = Date.now
    @State private var medicationEffectHours = 8.0
    @State private var timing: CombinationTiming = .sameSession
    @State private var isShowingDiscardWarning = false

    private var assessment: CombinationAssessment {
        CombinationAssessment(
            substances: Array(selectedSubstances),
            medicationText: medicationText,
            timing: timing
        )
    }

    private var hasUnsavedChanges: Bool {
        !selectedSubstances.isEmpty ||
        !medicationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !medicationDosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !Calendar.current.isDate(medicationTakenAt, equalTo: .now, toGranularity: .minute) ||
        medicationEffectHours != 8 ||
        timing != .sameSession
    }

    private var medicationSuggestions: [MedicationSuggestion] {
        MedicationSuggestionDatabase.suggestions(
            for: medicationText,
            savedMedications: profiles.first?.medications ?? []
        )
    }

    private var medicationSummaryForSaving: String {
        let name = medicationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "" }

        var parts = [name]
        let dose = medicationDosage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !dose.isEmpty { parts.append("amount \(dose)") }
        parts.append("last taken \(medicationTakenAt.formatted(date: .abbreviated, time: .shortened))")
        parts.append("works \(medicationEffectHours.formatted(.number.precision(.fractionLength(0...1)))) h")
        return parts.joined(separator: " • ")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Risk checker"),
                            subtitle: String(localized: "Select medication, substances, and timing to see common safety signals. It never marks a combination as safe."),
                            symbol: "exclamationmark.shield.fill",
                            tint: .orange
                        )

                        Text("This is not medical advice. It does not recommend substances, amounts, or combinations.")
                            .font(.callout.bold())
                            .foregroundStyle(Color.chillText)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassSurface(radius: 20, tint: .orange.opacity(0.08))

                        ClinicalReviewNoticeCard()

                        VStack(alignment: .leading, spacing: 14) {
                            CareSectionTitle(title: String(localized: "Current meds"), symbol: "pills.circle.fill")

                            TextField("Medication name, optional", text: $medicationText, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color.chillText)
                                .padding(14)
                                .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                            if !medicationSuggestions.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(medicationSuggestions) { suggestion in
                                        Button {
                                            medicationText = suggestion.name
                                            if let dosage = suggestion.dosage, !dosage.isEmpty {
                                                medicationDosage = dosage
                                            }
                                            if let effectiveHours = suggestion.effectiveHours {
                                                medicationEffectHours = effectiveHours
                                            }
                                        } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(suggestion.name)
                                                    .font(.caption.weight(.bold))
                                                if !suggestion.detail.isEmpty {
                                                    Text(suggestion.detail)
                                                        .font(.caption2.weight(.semibold))
                                                }
                                            }
                                            .foregroundStyle(Color.chillText)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .glassSurface(radius: 14, tint: Color.chillSecondaryBlue.opacity(0.08), interactive: true)
                                        }
                                        .buttonStyle(ChillPlainButtonStyle())
                                    }
                                }
                            }

                            TextField("Medication amount from your prescription, optional", text: $medicationDosage)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color.chillText)
                                .padding(14)
                                .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                            DatePicker("Last taken", selection: $medicationTakenAt, displayedComponents: [.date, .hourAndMinute])
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.chillText)
                                .tint(.orange)

                            Stepper(value: $medicationEffectHours, in: 0.5...72, step: 0.5) {
                                HStack {
                                    Text("Medication duration")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.chillText)
                                    Spacer()
                                    Text("\(medicationEffectHours.formatted(.number.precision(.fractionLength(0...1)))) h")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.chillSecondary)
                                }
                            }
                            .tint(.orange)

                            Text("Checks update automatically while you type. Common medication groups are matched locally on-device, but a clinician or pharmacist is the right place for medical decisions.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.chillSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Picker("Timing", selection: $timing) {
                                ForEach(CombinationTiming.allCases) { timing in
                                    Text(timing.localizedDisplayName).tag(timing)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: .orange.opacity(0.10), interactive: true)

                        VStack(alignment: .leading, spacing: 14) {
                            CareSectionTitle(title: String(localized: "Substances"), symbol: "square.grid.2x2.fill")

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10)], spacing: 10) {
                                ForEach(Substance.allCases.filter { $0 != .unknown && $0 != .other }) { substance in
                                    Button {
                                        toggle(substance)
                                    } label: {
                                        Label(substance.localizedDisplayName, systemImage: substance.symbolName)
                                            .font(.caption.weight(.bold))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                    }
                                    .buttonStyle(ChillPlainButtonStyle())
                                    .foregroundStyle(selectedSubstances.contains(substance) ? .white : Color.chillText)
                                    .background {
                                        Capsule()
                                            .fill(selectedSubstances.contains(substance) ? substance.tint : .white.opacity(0.45))
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)

                        RiskAssessmentPanel(assessment: assessment)

                        GlassActionButton(prominent: true, action: saveRiskCheck) {
                            Label("Save risk check", systemImage: "checkmark.shield.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(selectedSubstances.isEmpty && medicationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity((selectedSubstances.isEmpty && medicationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.55 : 1)

                        VStack(alignment: .leading, spacing: 12) {
                            CareSectionTitle(title: String(localized: "Current and past checks"), symbol: "clock.arrow.circlepath")

                            if riskChecks.isEmpty {
                                CareEmptyState(text: String(localized: "No saved risk checks yet."))
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(riskChecks) { record in
                                        RiskCheckRecordCard(record: record)
                                    }
                                }
                            }
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
            .toolbarBackground(.hidden, for: .navigationBar)
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
        if hasUnsavedChanges {
            isShowingDiscardWarning = true
        } else {
            dismiss()
        }
    }

    private func toggle(_ substance: Substance) {
        if selectedSubstances.contains(substance) {
            selectedSubstances.remove(substance)
        } else {
            selectedSubstances.insert(substance)
        }
    }

    private func saveRiskCheck() {
        let record = RiskCheckRecord(
            medicationText: medicationSummaryForSaving,
            timing: timing,
            substanceNames: selectedSubstances.map(\.rawValue).sorted(),
            serotoninLevel: assessment.serotoninRisk.label,
            dehydrationLevel: assessment.dehydrationRisk.label,
            stimulantLevel: assessment.stimulantOverloadRisk.label,
            warnings: assessment.interactionWarnings
        )
        modelContext.insert(record)
        try? modelContext.save()
        selectedSubstances = []
        medicationText = ""
        medicationDosage = ""
        medicationTakenAt = .now
        medicationEffectHours = 8
        timing = .sameSession
    }
}

private struct RiskCheckRecordCard: View {
    @Environment(\.modelContext) private var modelContext
    let record: RiskCheckRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                    Text(record.substanceNames.isEmpty ? String(localized: "Medication only") : record.substanceNames.joined(separator: ", "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button(role: .destructive) {
                    RecentlyDeletedStore.record(
                        kind: "Risk check",
                        title: record.substanceNames.isEmpty ? "Medication risk check" : record.substanceNames.joined(separator: ", "),
                        detail: record.createdAt.formatted(date: .abbreviated, time: .shortened)
                    )
                    modelContext.delete(record)
                    try? modelContext.save()
                } label: {
                    Image(systemName: "trash.fill")
                }
                .buttonStyle(ChillPlainButtonStyle())
                .foregroundStyle(Color.chillSecondary)
            }

            HStack(spacing: 8) {
                RiskPill(title: String(localized: "Serotonin"), value: record.serotoninLevel)
                RiskPill(title: String(localized: "Hydration"), value: record.dehydrationLevel)
                RiskPill(title: String(localized: "Stimulant"), value: record.stimulantLevel)
            }

            ForEach(record.warnings.prefix(3), id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassSurface(radius: 24, tint: .orange.opacity(0.08))
    }
}

private struct RiskPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
            Text(value)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(Color.chillText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct RiskAssessmentPanel: View {
    let assessment: CombinationAssessment

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CareSectionTitle(title: String(localized: "Assessment"), symbol: "waveform.path.ecg")

            if assessment.substances.isEmpty && assessment.medicationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                CareEmptyState(text: String(localized: "Select at least one substance or add medication to see a risk check."))
            } else {
                VStack(spacing: 10) {
                    RiskLevelRow(title: String(localized: "Serotonin syndrome"), level: assessment.serotoninRisk, detail: assessment.serotoninDetail)
                    RiskLevelRow(title: String(localized: "Dehydration"), level: assessment.dehydrationRisk, detail: assessment.dehydrationDetail)
                    RiskLevelRow(title: String(localized: "Stimulant overload"), level: assessment.stimulantOverloadRisk, detail: assessment.stimulantDetail)
                }

                if !assessment.matchedMedicationSummary.isEmpty {
                    Label("Matched medication groups: \(assessment.matchedMedicationSummary)", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassSurface(radius: 18, tint: Color.chillSecondaryBlue.opacity(0.07))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Interaction warnings")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)

                    ForEach(assessment.interactionWarnings, id: \.self) { warning in
                        RiskWarningLine(warning: warning)
                    }

                    Text("If someone is unconscious, very confused, overheating, having chest pain, breathing oddly, or cannot be woken: call 112.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .glassSurface(radius: 20, tint: .orange.opacity(0.08))
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .orange.opacity(0.10), interactive: true)
    }
}

private struct RiskLevelRow: View {
    let title: String
    let level: RiskLevel
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(level.label)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 72)
                .padding(.vertical, 8)
                .background(Capsule().fill(level.tint))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassSurface(radius: 20, tint: level.tint.opacity(0.08))
    }
}

enum CombinationTiming: String, CaseIterable, Identifiable {
    case sameSession = "Same session"
    case withinSixHours = "6 h"
    case withinDay = "24 h"

    var id: String { rawValue }
}

enum RiskLevel {
    case lower
    case caution
    case high

    var label: String {
        switch self {
        case .lower:
            String(localized: "No known")
        case .caution:
            String(localized: "Caution")
        case .high:
            String(localized: "High")
        }
    }

    var tint: Color {
        switch self {
        case .lower:
            Color.chillMint
        case .caution:
            .orange
        case .high:
            .red
        }
    }
}

private enum EvidenceTier: String {
    case known = "Known interaction"
    case likely = "Likely risk"
    case limited = "Limited evidence"
    case unknown = "Unknown"

    var tint: Color {
        switch self {
        case .known:
            .red
        case .likely:
            .orange
        case .limited:
            Color.chillSecondaryBlue
        case .unknown:
            Color.chillSecondary
        }
    }
}

private struct RiskWarningLine: View {
    let warning: String

    private var tier: EvidenceTier {
        let lower = warning.lowercased()
        if lower.contains("do not combine") || lower.contains("avoid") || lower.contains("dangerous") {
            return .known
        }
        if lower.contains("can") || lower.contains("increase") || lower.contains("raise") {
            return .likely
        }
        if lower.contains("unknown") || lower.contains("no known") {
            return .unknown
        }
        return .limited
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tier.localizedDisplayName)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(tier.tint))

            Label(warning, systemImage: "exclamationmark.circle.fill")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension RiskLevel {
    var severity: Int {
        switch self {
        case .lower:
            0
        case .caution:
            1
        case .high:
            2
        }
    }

    static func highest(_ levels: RiskLevel...) -> RiskLevel {
        levels.max { $0.severity < $1.severity } ?? .lower
    }
}

private struct CombinationAssessment {
    let substances: [Substance]
    let medicationText: String
    let timing: CombinationTiming

    private var substanceSet: Set<Substance> {
        Set(substances)
    }

    var medicationMatches: [MedicationRiskMatch] {
        MedicationRiskDatabase.matches(in: medicationText)
    }

    var matchedMedicationSummary: String {
        medicationMatches
            .map { "\($0.category.label) (\($0.matchedTerm))" }
            .joined(separator: ", ")
    }

    private var serotonergicSubstances: [Substance] {
        substances.filter { [.mdma, .threeMMC, .cocaine, .psychedelics].contains($0) }
    }

    private var stimulants: [Substance] {
        substances.filter { [.mdma, .threeMMC, .cocaine].contains($0) }
    }

    private var hasGHBLike: Bool {
        substanceSet.contains(.ghb) || substanceSet.contains(.gbl)
    }

    private var hasErectileMedication: Bool {
        substanceSet.contains(.viagra) || substanceSet.contains(.kamagra)
    }

    private func hasMedicationCategory(_ category: MedicationRiskCategory) -> Bool {
        medicationMatches.contains { $0.category == category }
    }

    var serotoninRisk: RiskLevel {
        if hasMedicationCategory(.maoi) && !serotonergicSubstances.isEmpty {
            return .high
        }

        if hasMedicationCategory(.serotonergic) && serotonergicSubstances.count >= 2 {
            return .high
        }

        if hasMedicationCategory(.serotonergic) && !serotonergicSubstances.isEmpty {
            return .caution
        }

        return serotonergicSubstances.count >= 2 ? .high : (!serotonergicSubstances.isEmpty ? .caution : .lower)
    }

    var dehydrationRisk: RiskLevel {
        let stimulantLevel: RiskLevel = stimulants.isEmpty ? .lower : (timing == .withinDay ? .caution : .high)
        let alcoholLevel: RiskLevel = substanceSet.contains(.alcohol) ? .caution : .lower
        let combinationLevel: RiskLevel = substanceSet.contains(.alcohol) && !stimulants.isEmpty ? .high : .lower
        return RiskLevel.highest(stimulantLevel, alcoholLevel, combinationLevel)
    }

    var stimulantOverloadRisk: RiskLevel {
        let stimulantMedicationCount = hasMedicationCategory(.stimulantMedication) ? 1 : 0
        let totalStimulants = stimulants.count + stimulantMedicationCount

        if totalStimulants >= 2 {
            return .high
        }

        if totalStimulants == 1 {
            return timing == .sameSession ? .caution : .lower
        }

        return .lower
    }

    var serotoninDetail: String {
        switch serotoninRisk {
        case .high:
            String(localized: "You've selected a medication or substance mix that can affect serotonin, a brain chemical involved in mood and body function. Signs to watch for: confusion, fever, agitation, shaking, sweating, or diarrhea. Get help if these appear.")
        case .caution:
            String(localized: "One of your selections can affect serotonin levels. Risk can increase with repeated use, heat, dehydration, or other medication.")
        case .lower:
            String(localized: "No known serotonin-related combination is selected.")
        }
    }

    var dehydrationDetail: String {
        switch dehydrationRisk {
        case .high:
            String(localized: "Stimulants, alcohol, heat, dancing, and long sessions can push dehydration and overheating risk up.")
        case .caution:
            String(localized: "Hydration and cooling matter, especially if sleep, food, or breaks have been limited.")
        case .lower:
            String(localized: "No strong dehydration pattern is selected, but check water, food, temperature, and rest.")
        }
    }

    var stimulantDetail: String {
        switch stimulantOverloadRisk {
        case .high:
            String(localized: "More than one stimulant pattern is selected, including possible prescribed stimulant medication. Heart rate, anxiety, jaw tension, overheating, and pressure to continue can stack.")
        case .caution:
            String(localized: "A stimulant is selected in the current timing window. Pause, rest, and give your body time.")
        case .lower:
            String(localized: "No obvious stimulant stacking is selected.")
        }
    }

    var interactionWarnings: [String] {
        var warnings: [String] = []

        if hasMedicationCategory(.nitrateLike) && (hasErectileMedication || substanceSet.contains(.poppers)) {
            warnings.append("Nitrates, nicorandil, or riociguat with Viagra, Kamagra, or poppers can cause a severe blood pressure drop. Do not combine.")
        }

        if hasMedicationCategory(.alphaBlocker) && hasErectileMedication {
            warnings.append("Alpha blockers with Viagra or Kamagra can increase dizziness or fainting risk. Check with a clinician before combining.")
        }

        if hasGHBLike {
            if substanceSet.contains(.alcohol) || substanceSet.contains(.ketamine) || hasMedicationCategory(.sedative) || hasMedicationCategory(.opioid) {
                warnings.append("GHB/GBL with alcohol, ketamine, sedatives, or opioids can cause unconsciousness or breathing problems.")
            } else {
                warnings.append("GHB/GBL effects can be hard to predict and can become serious quickly.")
            }
        }

        if substanceSet.contains(.poppers) {
            if substanceSet.contains(.viagra) || substanceSet.contains(.kamagra) {
                warnings.append("Poppers with Viagra or Kamagra can drop blood pressure sharply. Avoid this combination.")
            } else {
                warnings.append("Poppers can drop blood pressure sharply, especially with Viagra, Kamagra, or similar medication.")
            }
        }

        if (hasMedicationCategory(.sedative) || hasMedicationCategory(.opioid)) &&
            (substanceSet.contains(.alcohol) || substanceSet.contains(.ketamine) || substanceSet.contains(.cannabis) || hasGHBLike) {
            warnings.append("Sedatives or opioids with alcohol, ketamine, cannabis, or GHB/GBL can make breathing, memory, and consent clarity worse.")
        }

        if stimulants.count >= 2 {
            warnings.append("Multiple stimulants can stack heart strain, anxiety, and overheating.")
        }

        if hasMedicationCategory(.stimulantMedication) && !stimulants.isEmpty {
            warnings.append("Prescribed stimulant medication with MDMA, 3MMC, or cocaine can increase stimulant overload risk.")
        }

        if hasMedicationCategory(.maoi) && !serotonergicSubstances.isEmpty {
            warnings.append("Certain antidepressants (MAOIs) with MDMA, 3-MMC, cocaine, or psychedelics can be dangerous. Avoid this and get professional advice.")
        } else if hasMedicationCategory(.serotonergic) && !serotonergicSubstances.isEmpty {
            warnings.append("Some antidepressants or mood medication can interact with MDMA, 3-MMC, cocaine, or psychedelics.")
        }

        if hasMedicationCategory(.ritonavirBooster) && (hasErectileMedication || substanceSet.contains(.mdma) || substanceSet.contains(.threeMMC)) {
            warnings.append("Ritonavir or cobicistat can raise levels of some substances and erectile dysfunction medication. Ask a clinician or pharmacist.")
        }

        if substanceSet.contains(.alcohol) && substanceSet.contains(.cocaine) {
            warnings.append("Alcohol and cocaine together can increase strain on the heart and reduce judgment.")
        }

        if warnings.isEmpty {
            warnings.append("No known major preset warning matched. Unknown amount, contents, health conditions, and medication changes can still matter.")
        }

        return warnings
    }
}

private struct MedicationRiskMatch: Hashable {
    let category: MedicationRiskCategory
    let matchedTerm: String
}

private enum MedicationRiskCategory: String, CaseIterable {
    case serotonergic
    case maoi
    case sedative
    case opioid
    case nitrateLike
    case alphaBlocker
    case stimulantMedication
    case ritonavirBooster

    var label: String {
        switch self {
        case .serotonergic:
            String(localized: "Affects serotonin")
        case .maoi:
            String(localized: "MAOI")
        case .sedative:
            String(localized: "Sedative")
        case .opioid:
            String(localized: "Opioid")
        case .nitrateLike:
            String(localized: "Nitrate-like")
        case .alphaBlocker:
            String(localized: "Alpha blocker")
        case .stimulantMedication:
            String(localized: "Stimulant medication")
        case .ritonavirBooster:
            String(localized: "Ritonavir/cobicistat")
        }
    }

    var aliases: [String] {
        switch self {
        case .serotonergic:
            [
                "ssri", "snri", "tramadol", "lithium", "linezolid", "mirtazapine", "venlafaxine",
                "fluoxetine", "sertraline", "citalopram", "escitalopram", "paroxetine", "duloxetine",
                "vortioxetine", "dextromethorphan", "sumatriptan", "triptan", "st johns wort"
            ]
        case .maoi:
            ["maoi", "phenelzine", "tranylcypromine", "moclobemide", "selegiline"]
        case .sedative:
            [
                "benzodiazepine", "benzo", "diazepam", "alprazolam", "lorazepam", "oxazepam",
                "temazepam", "zolpidem", "zopiclone", "pregabalin", "gabapentin", "baclofen", "quetiapine"
            ]
        case .opioid:
            ["opioid", "opiate", "oxycodone", "morphine", "fentanyl", "codeine", "methadone", "buprenorphine", "tramadol"]
        case .nitrateLike:
            ["nitrate", "nitroglycerin", "glyceryl trinitrate", "isosorbide", "mononitrate", "dinitrate", "nicorandil", "riociguat"]
        case .alphaBlocker:
            ["alpha blocker", "tamsulosin", "doxazosin", "alfuzosin", "prazosin", "terazosin"]
        case .stimulantMedication:
            [
                "methylphenidate", "ritalin", "concerta", "dexamfetamine", "dexamphetamine",
                "lisdexamfetamine", "vyvanse", "elvanse", "adderall", "modafinil", "bupropion"
            ]
        case .ritonavirBooster:
            ["ritonavir", "cobicistat"]
        }
    }
}

private enum MedicationRiskDatabase {
    static func matches(in text: String) -> [MedicationRiskMatch] {
        let normalizedText = normalized(text)
        guard !normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var matches: [MedicationRiskMatch] = []

        for category in MedicationRiskCategory.allCases {
            for alias in category.aliases {
                let normalizedAlias = normalized(alias)
                if contains(normalizedAlias, in: normalizedText) {
                    matches.append(MedicationRiskMatch(category: category, matchedTerm: alias))
                    break
                }
            }
        }

        return matches
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
    }

    private static func contains(_ alias: String, in text: String) -> Bool {
        let paddedText = " \(text) "
        let paddedAlias = " \(alias) "
        return paddedText.contains(paddedAlias)
    }
}

private struct MedicationSuggestion: Identifiable {
    let id: String
    let name: String
    let detail: String
    let dosage: String?
    let effectiveHours: Double?
}

private enum MedicationSuggestionDatabase {
    static func suggestions(for query: String, savedMedications: [ProfileMedication]) -> [MedicationSuggestion] {
        let normalizedQuery = normalized(query)
        guard normalizedQuery.count >= 2 else {
            return []
        }

        var suggestions: [MedicationSuggestion] = []

        for medication in savedMedications where matches(medication.name, query: normalizedQuery) {
            suggestions.append(
                MedicationSuggestion(
                    id: "saved-\(medication.id.uuidString)",
                    name: medication.name,
                    detail: medication.timingSummary,
                    dosage: medication.dosage,
                    effectiveHours: medication.effectiveHours
                )
            )
        }

        let knownNames = MedicationRiskCategory.allCases
            .flatMap(\.aliases)
            .map { $0.capitalized }
            .sorted()

        for name in knownNames where matches(name, query: normalizedQuery) {
            let id = "known-\(normalized(name))"
            guard !suggestions.contains(where: { $0.id == id || normalized($0.name) == normalized(name) }) else {
                continue
            }
            suggestions.append(
                MedicationSuggestion(
                    id: id,
                    name: name,
                    detail: String(localized: "Common interaction category"),
                    dosage: nil,
                    effectiveHours: nil
                )
            )
        }

        return Array(suggestions.prefix(6))
    }

    private static func matches(_ value: String, query: String) -> Bool {
        normalized(value).contains(query)
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct DrugInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Substance info"),
                            subtitle: String(localized: "Neutral safety information, warning signs, and source links. ChillMate does not recommend substance use, amounts, or combinations."),
                            symbol: "pills.fill",
                            tint: Color.chillPrimary
                        )

                        MedicalSafetyDisclaimerCard(compact: true)

                        ForEach(Substance.allCases.filter { $0 != .unknown && $0 != .other }) { substance in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    Image(systemName: substance.symbolName)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(substance.tint)
                                        .frame(width: 38, height: 38)
                                        .glassSurface(radius: 19, tint: substance.tint.opacity(0.14))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(substance.localizedDisplayName)
                                            .font(.headline)
                                            .foregroundStyle(Color.chillText)
                                        Text("Safety reference")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.chillSecondary)
                                    }
                                }

                                Text(substance.informationSummary)
                                    .font(.callout)
                                    .foregroundStyle(Color.chillSecondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                DrugInfoMiniSection(title: String(localized: "Main risks"), rows: substance.mainRisks, tint: substance.tint)
                                DrugInfoMiniSection(title: String(localized: "Mixing risks"), rows: substance.mixingRisks, tint: .orange)
                                DrugInfoMiniSection(title: String(localized: "Seek help now if"), rows: substance.seekHelpSigns, tint: .red)

                                if let referenceURL = substance.referenceURL {
                                    Button {
                                        openURL(referenceURL)
                                    } label: {
                                        Label(substance.referenceLabel, systemImage: "link")
                                            .font(.caption.weight(.bold))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(substance.tint)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .glassSurface(radius: 24, tint: substance.tint.opacity(0.08))
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BackChevronButton {
                        dismiss()
                    }
                }
            }
            .edgeSwipeToDismiss()
        }
    }
}

private struct DrugInfoMiniSection: View {
    let title: String
    let rows: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillText)

            ForEach(rows, id: \.self) { row in
                Label(row, systemImage: "smallcircle.filled.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassSurface(radius: 18, tint: tint.opacity(0.06))
    }
}

struct EmergencyNetherlandsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @AppStorage("trustedContactName") private var trustedContactName = ""
    @AppStorage("trustedContactPhone") private var trustedContactPhone = ""
    @AppStorage("trustedContactMessage") private var trustedContactMessage = "Please come get me, I’m not okay at this moment."
    @AppStorage("localEmergencyNumber") private var localEmergencyNumber = "112"
    @AppStorage("localHealthcareContact") private var localHealthcareContact = ""

    @State private var isFetchingLocation = false
    @State private var locationMessage: String?
    @State private var isEditingEmergencyInfo = false

    private var emergencyNumber: String {
        let trimmed = localEmergencyNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "112" : trimmed
    }

    private var healthcareContactLabel: String {
        let trimmed = localHealthcareContact.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "GP, huisarts, or GGD" : trimmed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Emergency Information"),
                            subtitle: String(localized: "Fast emergency support. Set your local emergency number and healthcare contact in the edit menu."),
                            symbol: "sos.circle.fill",
                            tint: .red
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Call \(emergencyNumber) for immediate danger, urgent medical help, fire, or a crime in progress. Say where you are and what happened.")
                                .font(.callout)
                                .foregroundStyle(Color.chillText)
                                .fixedSize(horizontal: false, vertical: true)

                            Button(role: .destructive) {
                                call(emergencyNumber)
                            } label: {
                                Label("Call \(emergencyNumber)", systemImage: "phone.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: true, tint: .red))

                            Button {
                                isEditingEmergencyInfo = true
                            } label: {
                                Label("Change emergency number", systemImage: "pencil")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .red))
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: .red.opacity(0.10), interactive: true)
                        .sheet(isPresented: $isEditingEmergencyInfo) {
                            EmergencyContactEditSheet(
                                emergencyNumber: $localEmergencyNumber,
                                healthcareContact: $localHealthcareContact
                            )
                            .presentationDetents([.medium])
                        }

                        EmergencyRedFlagCard()

                        VStack(alignment: .leading, spacing: 14) {
                            CareSectionTitle(title: String(localized: "Trusted contact"), symbol: "person.crop.circle.badge.checkmark")

                            TextField("Name", text: $trustedContactName)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color.chillText)
                                .padding(14)
                                .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                            TextField("Phone number", text: $trustedContactPhone)
                                .keyboardType(.phonePad)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color.chillText)
                                .padding(14)
                                .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                            Button {
                                call(trustedContactPhone)
                            } label: {
                                Label(trustedContactName.isEmpty ? "Call trusted contact" : "Call \(trustedContactName)", systemImage: "phone.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: true))
                            .disabled(cleanedPhone(trustedContactPhone).isEmpty)

                            TextField("Message", text: $trustedContactMessage, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color.chillText)
                                .padding(14)
                                .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                            Button {
                                sendLocationMessage()
                            } label: {
                                HStack {
                                    if isFetchingLocation {
                                        ProgressView()
                                    }
                                    Label("Send current location", systemImage: "message.fill")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: true))
                            .disabled(cleanedPhone(trustedContactPhone).isEmpty || isFetchingLocation)

                            if let locationMessage {
                                Text(locationMessage)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.chillSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: Color.chillMint.opacity(0.10), interactive: true)

                        VStack(alignment: .leading, spacing: 10) {
                            CareSectionTitle(title: String(localized: "Non-urgent sexual health"), symbol: "cross.case.fill")
                            Text("For STI testing, sexual health questions, or treatment that is not an emergency, contact \(healthcareContactLabel).")
                                .font(.callout)
                                .foregroundStyle(Color.chillSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: .black.opacity(0.04))

                        NetherlandsHarmReductionResourcesCard()
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
                ToolbarItem(placement: .topBarLeading) {
                    BackChevronButton {
                        dismiss()
                    }
                }
            }
            .edgeSwipeToDismiss()
            .endEditingOnTap()
        }
    }

    private func call(_ number: String) {
        guard let url = URL(string: "tel://\(cleanedPhone(number))") else {
            return
        }
        openURL(url)
    }

    private func cleanedPhone(_ number: String) -> String {
        number.filter { $0.isNumber || $0 == "+" }
    }

    private func sendLocationMessage() {
        guard !isFetchingLocation else {
            return
        }

        isFetchingLocation = true
        locationMessage = nil

        Task {
            do {
                let location = try await LocationLookupService.shared.currentLoggedLocation()
                await MainActor.run {
                    openMessageComposer(location: location)
                    locationMessage = "Prepared iMessage with your current location."
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

    private func openMessageComposer(location: LoggedLocation) {
        var components = URLComponents()
        components.scheme = "sms"
        components.path = cleanedPhone(trustedContactPhone)
        components.queryItems = [
            URLQueryItem(name: String(localized: "body"), value: emergencyMessage(location: location))
        ]

        guard let url = components.url else {
            return
        }

        openURL(url)
    }

    private func emergencyMessage(location: LoggedLocation) -> String {
        let trimmed = trustedContactMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseMessage = trimmed.isEmpty ? "Please come get me, I’m not okay at this moment." : trimmed
        return "\(baseMessage)\nMy location: https://maps.apple.com/?ll=\(location.latitude),\(location.longitude)"
    }
}

private struct NetherlandsHarmReductionResourcesCard: View {
    private let links: [(String, String)] = [
        ("GGD sexual health", "https://www.ggd.nl"),
        ("Drugsinfo substance information", "https://www.drugsinfo.nl"),
        ("Jellinek alcohol and drugs support", "https://www.jellinek.nl"),
        ("Government.nl emergency number 112", "https://www.government.nl/topics/emergency-number-112")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CareSectionTitle(title: String(localized: "Netherlands support links"), symbol: "mappin.and.ellipse")

            Text("Use these for non-urgent sexual health, substance information, and harm-reduction support. For immediate danger, use 112.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(links, id: \.0) { link in
                if let url = URL(string: link.1) {
                    Link(destination: url) {
                        HStack(spacing: 10) {
                            Image(systemName: "link.circle.fill")
                                .foregroundStyle(Color.chillSecondaryBlue)
                            Text(link.0)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.chillText)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.chillSecondary)
                        }
                        .padding(12)
                        .glassSurface(radius: 18, tint: Color.chillSecondaryBlue.opacity(0.06), interactive: true)
                    }
                }
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08))
    }
}

struct AftercareView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NightEntry.date, order: .reverse) private var entries: [NightEntry]

    private var trackedEntries: [NightEntry] {
        entries.filter { $0.hadSex && !$0.skippedNight }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Aftercare"),
                            subtitle: String(localized: "A softer next-day check-in for sleep, feelings, and emotional care. Start with sleep, water, food, and symptoms; add what feels useful and skip what does not."),
                            symbol: "heart.text.square.fill",
                            tint: Color.chillAccentTeal
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tiny care plan")
                                .font(.headline)
                                .foregroundStyle(Color.chillText)
                            Text("Drink water, eat something gentle, rest, and avoid judging yourself while your body settles. If something feels unsafe or too heavy, reach out to someone you trust or a professional helper.")
                                .font(.callout)
                                .foregroundStyle(Color.chillSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: Color.chillAccentTeal.opacity(0.10))

                        PrepGuideCard()

                        if trackedEntries.isEmpty {
                            CareEmptyState(text: String(localized: "No tracked Chills available for aftercare."))
                        } else {
                            ForEach(trackedEntries.prefix(12)) { entry in
                                AftercareEntryCard(entry: entry)
                            }
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
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BackChevronButton {
                        dismiss()
                    }
                }
            }
            .edgeSwipeToDismiss()
            .endEditingOnTap()
        }
    }
}

private struct AftercareEntryCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var entry: NightEntry
    @State private var isImportingSleep = false
    @State private var sleepImportMessage = ""

    private var moodBinding: Binding<AftercareMood> {
        Binding {
            AftercareMood(rawValue: entry.aftercareMood) ?? .okay
        } set: { mood in
            entry.aftercareMood = mood.rawValue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                    Text(entry.aftercareCompletedAt == nil ? String(localized: "Open check-in") : String(localized: "Completed"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(entry.aftercareCompletedAt == nil ? Color.chillAccentTeal : Color.chillMint)
                }

                Spacer()

                Text((AftercareMood(rawValue: entry.aftercareMood) ?? .okay).emoji)
                    .font(.largeTitle)
            }

            Toggle("Record sleep now", isOn: $entry.aftercareSleepRecorded)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)
                .tint(Color.chillMint)

            if entry.aftercareSleepRecorded {
                HStack {
                    Text("\(entry.aftercareSleepHours.formatted(.number.precision(.fractionLength(0...1)))) h")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                        .frame(width: 72, alignment: .leading)
                    Slider(value: $entry.aftercareSleepHours, in: 0...12, step: 0.5)
                        .tint(Color.chillMint)
                }
            }

            Button {
                importSleepFromHealth()
            } label: {
                Label(isImportingSleep ? "Reading Apple Health" : "Import sleep from Apple Health", systemImage: "heart.text.square.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChillPillButtonStyle(prominent: false))
            .disabled(isImportingSleep)

            if !sleepImportMessage.isEmpty {
                Text(sleepImportMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle("Drank water", isOn: $entry.aftercareDrankWater)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)
                .tint(Color.chillSecondaryBlue)

            Toggle("Ate something", isOn: $entry.aftercareAteFood)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)
                .tint(.orange)

            if entry.aftercareAteFood {
                TextField("What did you eat? Optional", text: $entry.aftercareFoodNote, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.chillText)
                    .padding(14)
                    .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)
            }

            Picker("Mood", selection: moodBinding) {
                ForEach(AftercareMood.allCases) { mood in
                    Text("\(mood.emoji) \(mood.localizedDisplayName)").tag(mood)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.chillAccentTeal)

            VStack(alignment: .leading, spacing: 10) {
                CareSectionTitle(title: String(localized: "Symptoms"), symbol: "heart.text.clipboard.fill")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 126), spacing: 10)], spacing: 10) {
                    ForEach(AftercareSymptom.allCases) { symptom in
                        Button {
                            toggleSymptom(symptom)
                        } label: {
                            Text(symptom.localizedDisplayName)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(ChillPlainButtonStyle())
                        .foregroundStyle(entry.aftercareSymptoms.contains(symptom) ? .white : Color.chillText)
                        .background {
                            Capsule()
                                .fill(entry.aftercareSymptoms.contains(symptom) ? Color.chillAccentTeal : Color.white.opacity(0.45))
                        }
                    }
                }

                if !entry.aftercareSymptoms.isEmpty {
                    SymptomInsightCard(symptoms: entry.aftercareSymptoms)
                }
            }

            TextField("How do you feel about last Chill?", text: $entry.aftercareFeeling, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.chillText)
                .padding(14)
                .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

            GlassActionButton(prominent: true) {
                entry.aftercareCompletedAt = .now
                if entry.aftercareSleepRecorded {
                    entry.sleptYet = true
                    entry.sleepHours = entry.aftercareSleepHours
                }
                try? modelContext.save()
            } label: {
                Label("Save aftercare", systemImage: "checkmark.heart.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillAccentTeal.opacity(0.08), interactive: true)
    }

    private func toggleSymptom(_ symptom: AftercareSymptom) {
        var symptoms = entry.aftercareSymptoms
        if symptoms.contains(symptom) {
            symptoms.removeAll { $0 == symptom }
        } else {
            symptoms.append(symptom)
        }
        entry.aftercareSymptoms = symptoms
    }

    private func importSleepFromHealth() {
        isImportingSleep = true
        sleepImportMessage = ""

        Task {
            do {
                let end = Calendar.current.date(byAdding: .hour, value: 18, to: entry.endDate) ?? entry.endDate.addingTimeInterval(18 * 60 * 60)
                let hours = try await HealthKitService.shared.sleepHours(from: entry.endDate, to: end)
                entry.aftercareSleepRecorded = true
                entry.aftercareSleepHours = hours
                entry.sleptYet = true
                entry.sleepHours = hours
                try? modelContext.save()

                if hours >= 6, (try? await NotificationService.shared.requestAuthorization()) == true {
                    NotificationService.shared.schedulePositiveSleepNotification(hours: hours)
                }

                sleepImportMessage = "Apple Health sleep: \(hours.formatted(.number.precision(.fractionLength(0...1)))) h."
            } catch {
                sleepImportMessage = error.localizedDescription
            }

            isImportingSleep = false
        }
    }
}

private struct SymptomInsightCard: View {
    let symptoms: [AftercareSymptom]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most likely causes")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            ForEach(symptoms) { symptom in
                VStack(alignment: .leading, spacing: 2) {
                    Text(symptom.localizedDisplayName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.chillMint)
                    Text(symptom.likelyCause)
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassSurface(radius: 20, tint: Color.chillAccentTeal.opacity(0.09))
    }
}

struct PageHeader: View {
    @AppStorage("lastDailyRecoveryScore") private var lastDailyRecoveryScore = 42
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    private var palette: DailyScorePalette {
        DailyScorePalette(score: lastDailyRecoveryScore)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [tint.opacity(0.22), tint.opacity(0.10)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.36), lineWidth: 1)
                    }
                    .shadow(color: tint.opacity(0.28), radius: 10, y: 4)

                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(palette.heroText)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.80)
            }

            Text(subtitle)
                .font(.callout)
                .lineSpacing(3)
                .foregroundStyle(palette.heroSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct EmergencyRedFlagCard: View {
    @State private var checkedFlags: Set<String> = []

    private let flags = [
        String(localized: "Chest pain or severe pressure"),
        String(localized: "Fainting, seizure, or cannot be woken"),
        String(localized: "Blue lips, slow breathing, or gasping"),
        String(localized: "Very confused, overheating, or rigid muscles"),
        String(localized: "Severe panic that does not settle")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CareSectionTitle(title: String(localized: "Emergency red flags"), symbol: "exclamationmark.triangle.fill")

                Spacer()

                if !checkedFlags.isEmpty {
                    Button("Renew") {
                        checkedFlags.removeAll()
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                }
            }

            Text("If any of these are happening, do not wait for the app. Call 112 in the Netherlands or your local emergency number.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(flags, id: \.self) { flag in
                Button {
                    if checkedFlags.contains(flag) {
                        checkedFlags.remove(flag)
                    } else {
                        checkedFlags.insert(flag)
                    }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: checkedFlags.contains(flag) ? "checkmark.circle.fill" : "circle")
                            .font(.headline)
                            .foregroundStyle(checkedFlags.contains(flag) ? .red : Color.chillSecondary)

                        Text(flag)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Color.chillText)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .glassSurface(radius: 18, tint: (checkedFlags.contains(flag) ? Color.red : Color.black).opacity(0.06), interactive: true)
                }
                .buttonStyle(ChillPlainButtonStyle())
            }

            Button(role: .destructive) {
                guard let url = URL(string: "tel://112") else { return }
                UIApplication.shared.open(url)
            } label: {
                Label("Call 112", systemImage: "phone.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChillPillButtonStyle(prominent: true, tint: .red))
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .red.opacity(0.08), interactive: true)
        .accessibilityElement(children: .contain)
    }
}

struct ClinicalReviewNoticeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Clinical review note", systemImage: "checkmark.seal.text.page.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("ChillMate avoids calling combinations safe. It shows risk signals and source links to help you make more informed choices.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassSurface(radius: 24, tint: Color.chillMint.opacity(0.08))
    }
}

private struct CareSectionTitle: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(LinearGradient.chillBrand)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.chillText)
        }
    }
}

private struct CareEmptyState: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(Color.chillSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassSurface(radius: 24, tint: .black.opacity(0.04))
    }
}

private struct EmergencyContactEditSheet: View {
    @Binding var emergencyNumber: String
    @Binding var healthcareContact: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.opacity(0.86).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Emergency contacts")
                        .font(.title2.bold())
                        .foregroundStyle(Color.chillText)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Emergency number", systemImage: "phone.fill")
                            .font(.headline)
                            .foregroundStyle(Color.chillText)
                        Text("Default is 112 (Netherlands / EU). Change to your local emergency number.")
                            .font(.caption)
                            .foregroundStyle(Color.chillSecondary)
                        TextField("e.g. 911 or 999", text: $emergencyNumber)
                            .keyboardType(.phonePad)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Color.chillText)
                            .padding(14)
                            .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Healthcare contact", systemImage: "cross.case.fill")
                            .font(.headline)
                            .foregroundStyle(Color.chillText)
                        Text("Shown in the non-urgent sexual health section. Examples: local STI clinic, GP, PrEP provider.")
                            .font(.caption)
                            .foregroundStyle(Color.chillSecondary)
                        TextField("e.g. local STI clinic or GP", text: $healthcareContact)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Color.chillText)
                            .padding(14)
                            .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)
                    }

                    Button("Done") { dismiss() }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(ChillPillButtonStyle(prominent: true))
                }
                .padding(20)
            }
        }
    }
}

struct PanicSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("trustedContactName") private var trustedContactName = ""
    @AppStorage("trustedContactPhone") private var trustedContactPhone = ""
    @State private var isBreathing = false
    @State private var breathStep = 0
    @State private var completedGroundingSteps: Set<Int> = []

    private let breathingSteps = ["Breathe in", "Hold gently", "Breathe out", "Rest"]
    private let groundingSteps = [
        String(localized: "Name 5 things you can see."),
        String(localized: "Touch 4 things and notice texture."),
        String(localized: "Listen for 3 sounds."),
        String(localized: "Notice 2 smells, or name 2 safe places."),
        String(localized: "Notice 1 taste, or take one slow sip of water.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Panic support"),
                            subtitle: String(localized: "A low-stimulation space for anxiety, panic, or feeling unwell. Start the breathing timer, check off grounding steps, then call help if you need another person."),
                            symbol: "lungs.fill",
                            tint: Color.chillPrimary
                        )

                        VStack(spacing: 18) {
                            ZStack {
                                Circle()
                                    .fill(Color.chillPrimary.opacity(0.18))
                                    .frame(width: isBreathing ? 174 : 118, height: isBreathing ? 174 : 118)

                                Circle()
                                    .stroke(Color.chillMint.opacity(0.70), lineWidth: 8)
                                    .frame(width: 150, height: 150)

                                VStack(spacing: 6) {
                                    Text(isBreathing ? breathingSteps[breathStep] : String(localized: "Ready"))
                                        .font(.title3.bold())
                                        .foregroundStyle(Color.chillText)
                                    Text("You’re safe right now")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.chillSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Button(isBreathing ? "Stop breathing timer" : "Start breathing timer") {
                                toggleBreathing()
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .buttonStyle(ChillPillButtonStyle(prominent: true))
                        }
                        .padding(18)
                        .glassSurface(radius: 30, tint: .white.opacity(0.18), interactive: true)

                        VStack(alignment: .leading, spacing: 12) {
                            CareSectionTitle(title: String(localized: "Fast actions"), symbol: "phone.fill")

                            Button(action: callTrustedContact) {
                                Label(trustedContactName.isEmpty ? "Call trusted contact" : "Call \(trustedContactName)", systemImage: "person.crop.circle.badge.checkmark")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: true))
                            .disabled(trustedContactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(trustedContactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)

                            Button(role: .destructive, action: callEmergencyServices) {
                                Label("Call emergency services 112", systemImage: "sos.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: true, tint: .red))
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: .white.opacity(0.18), interactive: true)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                CareSectionTitle(title: String(localized: "Grounding steps"), symbol: "hand.raised.fill")

                                Spacer()

                                Button("Renew") {
                                    completedGroundingSteps.removeAll()
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.chillPrimary)
                                .disabled(completedGroundingSteps.isEmpty)
                                .opacity(completedGroundingSteps.isEmpty ? 0.45 : 1)
                            }

                            ForEach(Array(groundingSteps.enumerated()), id: \.offset) { index, step in
                                Button {
                                    if completedGroundingSteps.contains(index) {
                                        completedGroundingSteps.remove(index)
                                    } else {
                                        completedGroundingSteps.insert(index)
                                    }
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: completedGroundingSteps.contains(index) ? "checkmark.circle.fill" : "circle")
                                            .font(.headline)
                                            .foregroundStyle(completedGroundingSteps.contains(index) ? Color.chillMint : Color.chillSecondary)

                                        Text(step)
                                            .font(.callout.weight(.semibold))
                                            .foregroundStyle(completedGroundingSteps.contains(index) ? Color.chillSecondary : Color.chillText)
                                            .fixedSize(horizontal: false, vertical: true)

                                        Spacer(minLength: 0)
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .glassSurface(radius: 18, tint: (completedGroundingSteps.contains(index) ? Color.chillMint : Color.chillPrimary).opacity(0.08), interactive: true)
                                }
                                .buttonStyle(ChillPlainButtonStyle())
                            }
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: .white.opacity(0.16), interactive: true)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("References")
                                .font(.headline)
                                .foregroundStyle(Color.chillText)
                            Link("Mind: panic attacks and grounding", destination: URL(string: "https://www.mind.org.uk/information-support/types-of-mental-health-problems/anxiety-and-panic-attacks/panic-attacks")!)
                            Link("NHS: breathing exercises for stress", destination: URL(string: "https://www.nhs.uk/mental-health/self-help/guides-tools-and-activities/breathing-exercises-for-stress/")!)
                            Link("Government.nl: emergency number 112", destination: URL(string: "https://www.government.nl/topics/emergency-number-112")!)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .glassSurface(radius: 24, tint: .black.opacity(0.04))

                        EmergencyRedFlagCard()
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BackChevronButton {
                        dismiss()
                    }
                }
            }
            .edgeSwipeToDismiss()
        }
    }

    private func toggleBreathing() {
        isBreathing.toggle()
        if isBreathing {
            Task {
                while isBreathing {
                    await MainActor.run {
                        breathStep = (breathStep + 1) % breathingSteps.count
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    try? await Task.sleep(for: .seconds(4))
                }
            }
        }
    }

    private func callTrustedContact() {
        let phone = trustedContactPhone.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "tel://\(phone)") else { return }
        UIApplication.shared.open(url)
    }

    private func callEmergencyServices() {
        guard let url = URL(string: "tel://112") else { return }
        UIApplication.shared.open(url)
    }
}

struct SafeRouteHomeView: View {
    @Query(sort: \UserProfile.createdAt, order: .forward) private var profiles: [UserProfile]
    @AppStorage("trustedContactPhone") private var trustedContactPhone = ""
    @AppStorage("trustedContactMessage") private var trustedContactMessage = "Please come get me, I’m not okay at this moment."
    @State private var destination = ""
    @State private var selectedRouteMode: RouteTransportMode = .transit
    @State private var routeSuggestions: [RouteSuggestion] = []
    @State private var selectedSuggestion: RouteSuggestion?
    @State private var routeSearchTask: Task<Void, Never>?
    @State private var currentLocation: LoggedLocation?
    @State private var message: String?
    @State private var isFetchingLocation = false

    private var savedHomeAddress: String {
        profiles.first?.homeAddress.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Safe route home"),
                            subtitle: String(localized: "Plan transport, share where you are, or open a get-me-home flow quickly. Search an address, choose transit, driving, or cycling, then open Maps or message your trusted contact."),
                            symbol: "location.fill",
                            tint: Color.chillMint
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            CareSectionTitle(title: String(localized: "Destination"), symbol: "map.fill")

                            TextField("Where do you want to go?", text: $destination)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color.chillText)
                                .padding(14)
                                .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                            if !savedHomeAddress.isEmpty {
                                Button {
                                    selectedSuggestion = nil
                                    routeSuggestions = []
                                    destination = savedHomeAddress
                                } label: {
                                    Label("Use saved home address", systemImage: "house.fill")
                                        .font(.subheadline.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(ChillPillButtonStyle(prominent: false))
                            }

                            if !routeSuggestions.isEmpty {
                                VStack(spacing: 8) {
                                    ForEach(routeSuggestions) { suggestion in
                                        Button {
                                            selectedSuggestion = suggestion
                                            destination = suggestion.title
                                            routeSuggestions = []
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: "mappin.circle.fill")
                                                    .foregroundStyle(Color.chillMint)

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(suggestion.title)
                                                        .font(.subheadline.weight(.semibold))
                                                        .foregroundStyle(Color.chillText)
                                                    if !suggestion.subtitle.isEmpty {
                                                        Text(suggestion.subtitle)
                                                            .font(.caption)
                                                            .foregroundStyle(Color.chillSecondary)
                                                            .lineLimit(2)
                                                    }
                                                }

                                                Spacer(minLength: 0)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(12)
                                            .glassSurface(radius: 18, tint: Color.chillMint.opacity(0.07), interactive: true)
                                        }
                                        .buttonStyle(ChillPlainButtonStyle())
                                    }
                                }
                            }

                            Picker("Route type", selection: $selectedRouteMode) {
                                ForEach(RouteTransportMode.allCases) { mode in
                                    Label(mode.title, systemImage: mode.symbolName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            Button(action: openDirections) {
                                Label("Start \(selectedRouteMode.title.lowercased())", systemImage: selectedRouteMode.symbolName)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: true))

                            HStack(spacing: 10) {
                                Button(action: openUber) {
                                    Label("Uber", systemImage: "car.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .chillText))

                                Button(action: openBolt) {
                                    Label("Bolt", systemImage: "bolt.car.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .chillText))
                            }
                            .font(.headline)
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: Color.chillMint.opacity(0.10), interactive: true)

                        VStack(alignment: .leading, spacing: 12) {
                            CareSectionTitle(title: String(localized: "Share location"), symbol: "location.circle.fill")

                            if let currentLocation {
                                Text(currentLocation.locationMessage)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.chillSecondary)
                            }

                            if let message {
                                Text(message)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.chillSecondary)
                            }

                            Button(action: shareLocationNow) {
                                Label(isFetchingLocation ? "Getting location" : "Send location to trusted contact", systemImage: "message.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: true))
                            .disabled(isFetchingLocation || trustedContactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.10), interactive: true)

                        Button(role: .destructive, action: getMeHomeEmergencyFlow) {
                            Label("Get me home now", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ChillPillButtonStyle(prominent: true, tint: .red))
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .endEditingOnTap()
            .onChange(of: destination) { _, newValue in
                searchDestinationSuggestions(for: newValue)
            }
        }
    }

    private func searchDestinationSuggestions(for query: String) {
        selectedSuggestion = nil
        routeSearchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            routeSuggestions = []
            return
        }

        routeSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }

            let suggestions = await RouteSearchService.suggestions(for: trimmed)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                routeSuggestions = suggestions
            }
        }
    }

    private func openDirections() {
        if let selectedSuggestion {
            if selectedRouteMode == .cycling {
                let coordinate = selectedSuggestion.mapItem.location.coordinate
                openMapsURL(destination: "\(coordinate.latitude),\(coordinate.longitude)")
                return
            }

            selectedSuggestion.mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: selectedRouteMode.mapKitDirectionsMode
            ])
            return
        }

        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDestination.isEmpty {
            guard !savedHomeAddress.isEmpty else {
                message = String(localized: "Add a home address in Profile first, or type a destination here.")
                return
            }
            destination = savedHomeAddress
            openMapsURL(destination: savedHomeAddress)
            return
        }

        openMapsURL(destination: trimmedDestination)
    }

    private func openMapsURL(destination: String) {
        let encoded = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "maps://?daddr=\(encoded)&dirflg=\(selectedRouteMode.urlDirectionFlag)") else { return }
        UIApplication.shared.open(url)
    }

    private func openUber() {
        UIApplication.shared.open(URL(string: "https://m.uber.com/ul/")!)
    }

    private func openBolt() {
        UIApplication.shared.open(URL(string: "https://bolt.eu/")!)
    }

    private func shareLocationNow() {
        isFetchingLocation = true
        message = nil

        Task {
            do {
                let location = try await LocationLookupService.shared.currentLoggedLocation()
                await MainActor.run {
                    currentLocation = location
                    isFetchingLocation = false
                    openSMS(body: "\(trustedContactMessage)\n\nMy location: https://maps.apple.com/?ll=\(location.latitude),\(location.longitude)")
                }
            } catch {
                await MainActor.run {
                    isFetchingLocation = false
                    message = error.localizedDescription
                }
            }
        }
    }

    private func getMeHomeEmergencyFlow() {
        guard !savedHomeAddress.isEmpty else {
            message = String(localized: "Add a home address in Profile first so Get me home knows where to navigate.")
            shareLocationNow()
            return
        }

        selectedSuggestion = nil
        routeSuggestions = []
        destination = savedHomeAddress
        shareLocationNow()
        openMapsURL(destination: savedHomeAddress)
    }

    private func openSMS(body: String) {
        let phone = trustedContactPhone.filter { $0.isNumber || $0 == "+" }
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "sms:\(phone)&body=\(encodedBody)") else { return }
        UIApplication.shared.open(url)
    }
}

private enum RouteTransportMode: String, CaseIterable, Identifiable {
    case transit = "Transit"
    case driving = "Driving"
    case cycling = "Cycling"

    var id: String { rawValue }

    var title: String { rawValue }

    var symbolName: String {
        switch self {
        case .transit:
            "tram.fill"
        case .driving:
            "car.fill"
        case .cycling:
            "bicycle"
        }
    }

    var mapKitDirectionsMode: String {
        switch self {
        case .transit:
            MKLaunchOptionsDirectionsModeTransit
        case .driving:
            MKLaunchOptionsDirectionsModeDriving
        case .cycling:
            MKLaunchOptionsDirectionsModeDefault
        }
    }

    var urlDirectionFlag: String {
        switch self {
        case .transit:
            "r"
        case .driving:
            "d"
        case .cycling:
            "b"
        }
    }
}

private struct RouteSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let mapItem: MKMapItem
}

private enum RouteSearchService {
    @MainActor
    static func suggestions(for query: String) async -> [RouteSuggestion] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.prefix(5).map { item in
                RouteSuggestion(
                    title: item.name ?? query,
                    subtitle: item.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true) ?? item.address?.fullAddress ?? "",
                    mapItem: item
                )
            }
        } catch {
            return []
        }
    }
}

private extension LoggedLocation {
    var locationMessage: String {
        "\(name.isEmpty ? "Current location" : name) • \(coordinateSummary)"
    }
}

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var journalEntries: [JournalEntry]

    @State private var date = Date.now
    @State private var rememberClearly = ""
    @State private var uncomfortableMoments = ""
    @State private var consentConcerns = ""
    @State private var regrets = ""
    @State private var feelsGoodAbout = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []
    @State private var isShowingMorePrompts = false
    @State private var isEditing = false
    @State private var isShowingMonthCalendar = false

    private var selectedJournalEntry: JournalEntry? {
        journalEntries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    /// Drives whether the day shows a read-only overview or the editable form.
    private var mode: JournalMode {
        if selectedJournalEntry == nil { return .new }
        return isEditing ? .editing : .viewing
    }

    var body: some View {
        let photoCount = photoData.count
        let photoPickerTitle = photoCount == 0 ? "Add photos" : "\(photoCount) photo\(photoCount == 1 ? "" : "s")"

        NavigationStack {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Journal"),
                            subtitle: String(localized: "Pick a day, write the few things you want to remember, and come back anytime to edit."),
                            symbol: "book.closed.fill",
                            tint: Color.chillPrimary
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            JournalWeekStrip(selectedDate: $date, entries: journalEntries)
                                .disabled(mode == .editing)

                            HStack(spacing: 10) {
                                Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                    .font(.headline)
                                    .foregroundStyle(Color.chillText)

                                Spacer(minLength: 0)

                                Button {
                                    isShowingMonthCalendar = true
                                } label: {
                                    Image(systemName: "calendar")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.chillPrimary)
                                        .frame(width: 34, height: 34)
                                        .background(Color.chillPrimary.opacity(0.14), in: Circle())
                                        .contentShape(Circle())
                                }
                                .buttonStyle(ChillPlainButtonStyle())
                                .disabled(mode == .editing)
                                .opacity(mode == .editing ? 0.4 : 1)
                                .accessibilityLabel("Open month calendar")

                                JournalStatusPill(mode: mode)
                            }

                            if mode == .viewing, let entry = selectedJournalEntry {
                                // ── Read-only overview of the saved day ──
                                JournalEntryOverview(entry: entry)

                                HStack(spacing: 10) {
                                    GlassActionButton(prominent: true, action: beginEditing) {
                                        Label("Edit entry", systemImage: "pencil")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                    }

                                    GlassActionButton(prominent: false, tint: .red, action: deleteJournalEntry) {
                                        Image(systemName: "trash.fill")
                                    }
                                    .accessibilityLabel("Delete entry")
                                }
                            } else {
                                // ── Editable form (new entry, or editing an existing one) ──
                                JournalPromptField(title: String(localized: "What do you remember?"), text: $rememberClearly)
                                JournalPromptField(title: String(localized: "How do you feel about it now?"), text: $feelsGoodAbout)
                                JournalPromptField(title: String(localized: "Any safety or consent concerns?"), text: $consentConcerns)

                                DisclosureGroup(isExpanded: $isShowingMorePrompts) {
                                    VStack(spacing: 10) {
                                        JournalPromptField(title: String(localized: "Any uncomfortable moments?"), text: $uncomfortableMoments)
                                        JournalPromptField(title: String(localized: "Regrets or loose ends"), text: $regrets)
                                    }
                                    .padding(.top, 8)
                                } label: {
                                    Label("Any regrets?", systemImage: "chevron.down.circle.fill")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.chillText)
                                }
                                .tint(Color.chillPrimary)
                                .padding(12)
                                .background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                                HStack(spacing: 10) {
                                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 6, matching: .images) {
                                        Label(photoPickerTitle, systemImage: "photo.on.rectangle.angled")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(ChillPillButtonStyle(prominent: false))
                                    .onChange(of: selectedPhotos) { _, items in
                                        loadPhotos(items)
                                    }
                                }

                                HStack(spacing: 10) {
                                    GlassActionButton(prominent: true, action: saveJournalEntry) {
                                        Label(mode == .editing ? "Save changes" : "Save journal", systemImage: "checkmark.circle.fill")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                    }

                                    if mode == .editing {
                                        GlassActionButton(prominent: false, action: cancelEditing) {
                                            Text("Cancel")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .endEditingOnTap()
            .onAppear(perform: loadSelectedJournalEntry)
            .onChange(of: date) { _, _ in
                isEditing = false
                loadSelectedJournalEntry()
            }
            .sheet(isPresented: $isShowingMonthCalendar) {
                JournalMonthCalendarSheet(date: $date)
            }
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) {
        Task {
            var loaded: [Data] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let optimizedData = await Task.detached(priority: .utility) {
                        ChillImageOptimizer.downsampledJPEGData(from: data, maxPixelSize: 1200, compressionQuality: 0.80)
                    }.value
                    loaded.append(optimizedData)
                }
            }
            await MainActor.run {
                photoData = loaded
            }
        }
    }

    private func saveJournalEntry() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if let entry = selectedJournalEntry {
            entry.rememberClearly = rememberClearly.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.uncomfortableMoments = uncomfortableMoments.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.consentConcerns = consentConcerns.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.regrets = regrets.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.feelsGoodAbout = feelsGoodAbout.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.photos = photoData
            try? modelContext.save()
            SpotlightService.shared.indexJournalEntry(entry)
        } else {
            let entry = JournalEntry(
                date: date,
                rememberClearly: rememberClearly.trimmingCharacters(in: .whitespacesAndNewlines),
                uncomfortableMoments: uncomfortableMoments.trimmingCharacters(in: .whitespacesAndNewlines),
                consentConcerns: consentConcerns.trimmingCharacters(in: .whitespacesAndNewlines),
                regrets: regrets.trimmingCharacters(in: .whitespacesAndNewlines),
                feelsGoodAbout: feelsGoodAbout.trimmingCharacters(in: .whitespacesAndNewlines),
                photos: photoData
            )
            modelContext.insert(entry)
            try? modelContext.save()
            SpotlightService.shared.indexJournalEntry(entry)
        }

        // Saved → drop back to the read-only overview for the day.
        withAnimation(.snappy) { isEditing = false }
    }

    private func beginEditing() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        loadSelectedJournalEntry()
        withAnimation(.snappy) { isEditing = true }
    }

    private func cancelEditing() {
        loadSelectedJournalEntry() // discard unsaved edits
        withAnimation(.snappy) { isEditing = false }
    }

    private func deleteJournalEntry() {
        guard let entry = selectedJournalEntry else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        SpotlightService.shared.removeJournalEntry(entry)
        modelContext.delete(entry)
        try? modelContext.save()
        isEditing = false
        loadSelectedJournalEntry()
    }

    private func loadSelectedJournalEntry() {
        guard let entry = selectedJournalEntry else {
            rememberClearly = ""
            uncomfortableMoments = ""
            consentConcerns = ""
            regrets = ""
            feelsGoodAbout = ""
            selectedPhotos = []
            photoData = []
            return
        }

        rememberClearly = entry.rememberClearly
        uncomfortableMoments = entry.uncomfortableMoments
        consentConcerns = entry.consentConcerns
        regrets = entry.regrets
        feelsGoodAbout = entry.feelsGoodAbout
        selectedPhotos = []
        photoData = entry.photos
    }
}

/// A quick month-view calendar so a day can be found without scrolling the strip.
private struct JournalMonthCalendarSheet: View {
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                VStack(spacing: 16) {
                    DatePicker(
                        "",
                        selection: $date,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(Color.chillPrimary)
                    .padding(8)
                    .glassSurface(radius: 24, tint: .white.opacity(0.28))

                    Spacer(minLength: 0)
                }
                .padding(20)
            }
            .navigationTitle("Pick a date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct JournalWeekStrip: View {
    @Binding var selectedDate: Date
    let entries: [JournalEntry]

    private var calendar: Calendar { .current }

    /// A rolling range of days the user can scroll horizontally through (roughly
    /// the last ten weeks up to the end of the current week). This replaces the
    /// old static single-week row and the separate date picker.
    private var days: [Date] {
        let today = calendar.startOfDay(for: Date.now)
        let startSeed = calendar.date(byAdding: .weekOfYear, value: -9, to: today) ?? today
        guard let startInterval = calendar.dateInterval(of: .weekOfYear, for: startSeed),
              let endInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        }

        var result: [Date] = []
        var day = startInterval.start
        while day < endInterval.end {
            result.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        dayCell(day).id(day)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .onAppear {
                DispatchQueue.main.async { scroll(to: selectedDate, with: proxy, animated: false) }
            }
            .onChange(of: selectedDate) { _, newValue in
                scroll(to: newValue, with: proxy, animated: true)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let hasEntry = entries.contains { calendar.isDate($0.date, inSameDayAs: day) }

        return Button {
            selectedDate = day
        } label: {
            VStack(spacing: 4) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? .white.opacity(0.80) : Color.chillSecondary)
                Text(day.formatted(.dateTime.day()))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .white : Color.chillText)
                Circle()
                    .fill(hasEntry ? (isSelected ? .white.opacity(0.72) : Color.chillMint) : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 46, height: 58)
            .background(
                isSelected ? Color.chillPrimary : Color.clear,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(ChillPlainButtonStyle())
        .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted))\(hasEntry ? ", journal entry saved" : "")")
    }

    private func scroll(to date: Date, with proxy: ScrollViewProxy, animated: Bool) {
        let target = calendar.startOfDay(for: date)
        if animated {
            withAnimation(.snappy) { proxy.scrollTo(target, anchor: .center) }
        } else {
            proxy.scrollTo(target, anchor: .center)
        }
    }
}

private enum JournalMode { case new, viewing, editing }

private struct JournalStatusPill: View {
    let mode: JournalMode

    private var content: (title: String, symbol: String, tint: Color) {
        switch mode {
        case .new: ("New", "plus.circle.fill", Color.chillSecondaryBlue)
        case .viewing: ("Saved", "checkmark.seal.fill", Color.chillMint)
        case .editing: ("Editing", "pencil.circle.fill", Color.chillPrimary)
        }
    }

    var body: some View {
        let c = content
        Label(c.title, systemImage: c.symbol)
            .font(.caption.weight(.bold))
            .foregroundStyle(c.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(c.tint.opacity(0.12), in: Capsule())
    }
}

/// Read-only summary of a saved journal day — shown instead of the input form
/// once a day has an entry, so a saved day reads as a finished overview rather
/// than a blank form that looks like it still needs input.
private struct JournalEntryOverview: View {
    let entry: JournalEntry

    private var answeredPrompts: [(prompt: String, answer: String)] {
        [
            ("What do you remember?", entry.rememberClearly),
            ("How do you feel about it now?", entry.feelsGoodAbout),
            ("Any safety or consent concerns?", entry.consentConcerns),
            ("Any uncomfortable moments?", entry.uncomfortableMoments),
            ("Regrets or loose ends", entry.regrets)
        ].filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if answeredPrompts.isEmpty && entry.photos.isEmpty {
                Text("No details saved for this day yet. Tap Edit to add some.")
                    .font(.subheadline)
                    .foregroundStyle(Color.chillSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(answeredPrompts.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.prompt)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.chillSecondary)
                        Text(item.answer)
                            .font(.subheadline)
                            .foregroundStyle(Color.chillText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !entry.photos.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(entry.photos.enumerated()), id: \.offset) { _, data in
                            if let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct JournalPromptField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillMint)

            TextField(title, text: $text, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.chillText)
                .padding(12)
                .glassSurface(radius: 16, tint: .black.opacity(0.04), interactive: true)
        }
    }
}

private struct JournalEntryCard: View {
    @Environment(\.modelContext) private var modelContext
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .foregroundStyle(Color.chillText)

                Spacer()

                Button(role: .destructive) {
                    RecentlyDeletedStore.record(
                        kind: "Journal",
                        title: String(localized: "Journal entry"),
                        detail: entry.date.formatted(date: .abbreviated, time: .omitted)
                    )
                    modelContext.delete(entry)
                    try? modelContext.save()
                } label: {
                    Image(systemName: "trash.fill")
                }
                .buttonStyle(ChillPlainButtonStyle())
                .foregroundStyle(Color.chillSecondary)
            }

            JournalLine(title: String(localized: "Clear memory"), value: entry.rememberClearly)
            JournalLine(title: String(localized: "Uncomfortable"), value: entry.uncomfortableMoments)
            JournalLine(title: String(localized: "Consent"), value: entry.consentConcerns)
            JournalLine(title: String(localized: "Regrets"), value: entry.regrets)
            JournalLine(title: String(localized: "Good"), value: entry.feelsGoodAbout)

            if !entry.photos.isEmpty {
                Text("\(entry.photos.count) picture\(entry.photos.count == 1 ? "" : "s")")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillPrimary)
            }
        }
        .padding(16)
        .glassSurface(radius: 24, tint: .black.opacity(0.04))
    }
}

private struct JournalLine: View {
    let title: String
    let value: String

    var body: some View {
        if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondary)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(Color.chillText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct EmergencyCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserProfile.createdAt, order: .forward) private var profiles: [UserProfile]
    @Query(sort: \DrugDoseTimerRecord.startedAt, order: .reverse) private var timers: [DrugDoseTimerRecord]
    @Query(sort: \NightEntry.date, order: .reverse) private var entries: [NightEntry]
    @AppStorage("trustedContactName") private var trustedContactName = ""
    @AppStorage("trustedContactPhone") private var trustedContactPhone = ""
    @AppStorage("emergencyAllergies") private var emergencyAllergies = ""
    @AppStorage("emergencyInstructions") private var emergencyInstructions = "If I seem confused, overheated, unconscious, or cannot be woken, call 112."

    private var profile: UserProfile? { profiles.first }

    private var activeSubstances: [String] {
        let now = Date.now
        let timerNames = timers
            .filter { $0.endsAt > now }
            .map {
                let route = AdministrationRoute(rawValue: $0.administrationRoute)?.displayName ?? "Saved route"
                return "\($0.substanceName) (\(route))"
            }
        if !timerNames.isEmpty {
            return Array(timerNames.prefix(5))
        }
        return Array((entries.first?.substances ?? []).prefix(5))
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(
                            title: String(localized: "Emergency card"),
                            subtitle: String(localized: "A simple card for urgent moments. Keep it readable and only include what you are comfortable showing."),
                            symbol: "staroflife.fill",
                            tint: .red
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            EmergencyCardLine(title: String(localized: "Name"), value: profile?.name ?? "Not set", symbol: "person.fill")
                            EmergencyCardLine(title: String(localized: "Medication"), value: medicationText, symbol: "pills.fill")
                            EmergencyCardLine(title: String(localized: "Current substances"), value: activeSubstances.isEmpty ? "None currently tracked" : activeSubstances.joined(separator: ", "), symbol: "timer")
                            EmergencyCardLine(title: String(localized: "Trusted contact"), value: trustedContactText, symbol: "phone.fill")

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Allergies", systemImage: "allergens.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.chillSecondary)
                                TextField("Known allergies", text: $emergencyAllergies, axis: .vertical)
                                    .lineLimit(2...4)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(Color.chillText)
                                    .padding(12)
                                    .glassSurface(radius: 16, tint: .black.opacity(0.04), interactive: true)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Emergency instructions", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.chillSecondary)
                                TextField("Emergency instructions", text: $emergencyInstructions, axis: .vertical)
                                    .lineLimit(3...6)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(Color.chillText)
                                    .padding(12)
                                    .glassSurface(radius: 16, tint: .black.opacity(0.04), interactive: true)
                            }
                        }
                        .padding(18)
                        .glassSurface(radius: 30, tint: .white.opacity(0.24), interactive: true)

                        HStack(spacing: 10) {
                            Link(destination: URL(string: "tel://112")!) {
                                Label("Call 112", systemImage: "phone.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: true, tint: .red))

                            if let url = trustedContactCallURL {
                                Link(destination: url) {
                                    Label("Trusted contact", systemImage: "person.crop.circle.badge.checkmark")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .chillSecondaryBlue))
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .endEditingOnTap()
        }
    }

    private var medicationText: String {
        guard let profile, !profile.medications.isEmpty else {
            return "No medication saved"
        }
        return profile.medications.prefix(4).map { "\($0.name) \($0.dosage)" }.joined(separator: ", ")
    }

    private var trustedContactText: String {
        let name = trustedContactName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = trustedContactPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty && phone.isEmpty { return "Not set" }
        if phone.isEmpty { return name }
        return name.isEmpty ? phone : "\(name), \(phone)"
    }

    private var trustedContactCallURL: URL? {
        let phone = trustedContactPhone.filter { $0.isNumber || $0 == "+" }
        guard !phone.isEmpty else { return nil }
        return URL(string: "tel://\(phone)")
    }
}

private struct EmergencyCardLine: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.chillText)
                .frame(width: 34, height: 34)
                .glassSurface(radius: 17, tint: .black.opacity(0.08))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondary)
                Text(value)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.chillText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct NetherlandsSupportDirectoryView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("country") private var country = "Netherlands"
    @State private var query = ""

    private var filteredResources: [SupportResource] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SupportResource.resources(for: country)
        }
        return SupportResource.resources(for: country).filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) ||
            $0.detail.localizedCaseInsensitiveContains(trimmed) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(
                            title: String(localized: "Support"),
                            subtitle: String(localized: "Search offline Netherlands support options for crisis help, sexual health, drugs, LGBTQ+ support, and practical care."),
                            symbol: "list.bullet.clipboard.fill",
                            tint: Color.chillSecondaryBlue
                        )

                        TextField("Search support", text: $query)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Color.chillText)
                            .padding(14)
                            .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                        LazyVStack(spacing: 12) {
                            ForEach(filteredResources) { resource in
                                SupportResourceCard(resource: resource)
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .endEditingOnTap()
        }
    }
}

private struct SupportResource: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let action: String
    let url: URL?
    let tags: [String]

    static let netherlands: [SupportResource] = [
        SupportResource(title: String(localized: "112 emergency"), detail: String(localized: "Immediate danger, unconsciousness, seizure, blue lips, chest pain, severe overheating, or cannot be woken."), action: String(localized: "Call 112"), url: URL(string: "tel://112"), tags: ["crisis", "emergency", "panic"]),
        SupportResource(title: String(localized: "113 Zelfmoordpreventie"), detail: String(localized: "If you might hurt yourself or cannot stay safe. Call 113 or 0800-0113 in the Netherlands."), action: String(localized: "Open 113.nl"), url: URL(string: "https://www.113.nl"), tags: ["crisis", "mental health", "suicide"]),
        SupportResource(title: String(localized: "GGD sexual health"), detail: String(localized: "STI testing, PrEP, PEP questions, vaccination, and sexual health support."), action: String(localized: "Open ggd.nl"), url: URL(string: "https://www.ggd.nl"), tags: ["sti", "pep", "prep", "ggd"]),
        SupportResource(title: String(localized: "Huisarts / GP"), detail: String(localized: "Medication interactions, sleep, mental health, substance use, referrals, and urgent medical questions."), action: String(localized: "Call your GP"), url: nil, tags: ["doctor", "huisarts", "medication"]),
        SupportResource(title: String(localized: "Drugs Infolijn"), detail: String(localized: "Dutch drug information and harm-reduction support from Trimbos."), action: String(localized: "Open drugsinfo.nl"), url: URL(string: "https://www.drugsinfo.nl"), tags: ["drugs", "harm reduction", "trimbos"]),
        SupportResource(title: String(localized: "Centrum Seksueel Geweld"), detail: String(localized: "Support after sexual assault, coercion, or a consent concern."), action: String(localized: "Open centrumseksueelgeweld.nl"), url: URL(string: "https://centrumseksueelgeweld.nl"), tags: ["consent", "assault", "help"]),
        SupportResource(title: String(localized: "Jellinek"), detail: String(localized: "Dutch addiction care and information about alcohol, drugs, and chemsex patterns."), action: String(localized: "Open jellinek.nl"), url: URL(string: "https://www.jellinek.nl"), tags: ["addiction", "chemsex", "drugs"]),
        SupportResource(title: String(localized: "Switchboard LGBT+"), detail: String(localized: "LGBTQ+ listening ear, information, and referral support."), action: String(localized: "Open switchboard.nl"), url: URL(string: "https://switchboard.nl"), tags: ["lgbtq", "queer", "support"])
    ]

    // Generic, country-neutral fallback shown when the chosen country is not the Netherlands.
    static let international: [SupportResource] = [
        SupportResource(title: String(localized: "Emergency services"), detail: String(localized: "Immediate danger, unconsciousness, or someone who cannot be woken. Call your local emergency number now."), action: String(localized: "Call 112"), url: URL(string: "tel://112"), tags: ["crisis", "emergency", "panic"]),
        SupportResource(title: String(localized: "Crisis & suicide support"), detail: String(localized: "Free, confidential support if you might hurt yourself or cannot stay safe."), action: String(localized: "Open findahelpline.com"), url: URL(string: "https://findahelpline.com"), tags: ["crisis", "mental health", "suicide"]),
        SupportResource(title: String(localized: "Sexual health & STI testing"), detail: String(localized: "Find local STI testing, PrEP, PEP, and sexual health services."), action: String(localized: "Find a clinic"), url: nil, tags: ["sti", "pep", "prep"]),
        SupportResource(title: String(localized: "Drug information & harm reduction"), detail: String(localized: "Trusted, non-judgmental drug information and harm-reduction support."), action: String(localized: "Open tripsit.me"), url: URL(string: "https://tripsit.me"), tags: ["drugs", "harm reduction"]),
        SupportResource(title: String(localized: "GP or family doctor"), detail: String(localized: "Medication interactions, sleep, mental health, substance use, referrals, and urgent medical questions."), action: String(localized: "Call your GP"), url: nil, tags: ["doctor", "medication"]),
        SupportResource(title: String(localized: "LGBTQ+ support"), detail: String(localized: "LGBTQ+ listening ear, information, and referral support."), action: String(localized: "Find LGBTQ+ support"), url: nil, tags: ["lgbtq", "queer", "support"])
    ]

    static func resources(for country: String) -> [SupportResource] {
        country == "Netherlands" ? netherlands : international
    }
}

private struct SupportResourceCard: View {
    let resource: SupportResource

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(resource.title)
                .font(.headline)
                .foregroundStyle(Color.chillText)
            Text(resource.detail)
                .font(.caption)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let url = resource.url {
                Link(destination: url) {
                    Label(resource.action, systemImage: resource.action.lowercased().contains("call") ? "phone.fill" : "arrow.up.right.square.fill")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .chillSecondaryBlue))
            } else {
                Text(resource.action)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondaryBlue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(radius: 24, tint: Color.chillSecondaryBlue.opacity(0.08), interactive: true)
    }
}

struct CravingDelayView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DrugDoseTimerRecord.startedAt, order: .reverse) private var timers: [DrugDoseTimerRecord]
    @State private var startedAt: Date?
    @State private var isShowingTimer = false

    private var latestTimer: DrugDoseTimerRecord? {
        timers.first
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(
                            title: String(localized: "Craving delay"),
                            subtitle: String(localized: "A 10 minute pause before deciding. If something already happened, use a check-in to record context without judging yourself."),
                            symbol: "pause.circle.fill",
                            tint: Color.chillPrimary
                        )

                        if let latestTimer {
                            LatestDoseReminder(timer: latestTimer)
                        }

                        DelayOrb(startedAt: startedAt)

                        HStack(spacing: 10) {
                            GlassActionButton(prominent: true) {
                                startedAt = .now
                            } label: {
                                Label(startedAt == nil ? "Start 10 min pause" : "Restart pause", systemImage: "timer")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }

                            Button {
                                isShowingTimer = true
                            } label: {
                                Label("Open check-in", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .chillSecondaryBlue))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("During the pause")
                                .font(.headline)
                                .foregroundStyle(Color.chillText)
                            Text("Breathe slowly, drink water if safe, check your body, remember what was already logged, and ask whether waiting would protect tomorrow-you.")
                                .font(.callout)
                                .foregroundStyle(Color.chillSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .glassSurface(radius: 24, tint: Color.chillPrimary.opacity(0.08))
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .fullScreenCover(isPresented: $isShowingTimer) {
                DrugTimerView()
            }
        }
    }
}

private struct LatestDoseReminder: View {
    let timer: DrugDoseTimerRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Earlier log reminder", systemImage: "clock.arrow.circlepath")
                .font(.headline)
                .foregroundStyle(Color.chillText)
            Text("\(timer.substanceName) was logged at \(timer.startedAt.formatted(date: .abbreviated, time: .shortened)). Check-in progress: \(Int(timer.effectProgress(at: .now) * 100))%.")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassSurface(radius: 24, tint: Color.chillSecondaryBlue.opacity(0.08), interactive: true)
    }
}

private struct DelayOrb: View {
    let startedAt: Date?

    var body: some View {
        Group {
            if startedAt == nil {
                orbContent(remaining: 10 * 60)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    orbContent(remaining: remainingSeconds(now: context.date))
                }
            }
        }
    }

    private func orbContent(remaining: Int) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.chillPrimary.opacity(0.55), Color.chillMint.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 156, height: 156)
                    .scaleEffect(startedAt == nil ? 0.92 : 1.0)
                Text(timeText(remaining))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            Text(remaining == 0 && startedAt != nil ? String(localized: "Pause complete. Decide slowly.") : String(localized: "Let the first urge pass before choosing."))
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassSurface(radius: 32, tint: Color.chillPrimary.opacity(0.08))
    }

    private func remainingSeconds(now: Date) -> Int {
        guard let startedAt else { return 10 * 60 }
        return max(0, Int(startedAt.addingTimeInterval(10 * 60).timeIntervalSince(now)))
    }

    private func timeText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return "\(minutes.twoDigitPadded):\(remainder.twoDigitPadded)"
    }
}

private extension Int {
    var twoDigitPadded: String {
        self < 10 ? "0\(self)" : "\(self)"
    }
}

struct SafetyAutopilotView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NightEntry.date, order: .reverse) private var entries: [NightEntry]
    @Query(sort: \DrugDoseTimerRecord.startedAt, order: .reverse) private var timers: [DrugDoseTimerRecord]
    @Query(sort: \SaferSessionPlan.plannedDate, order: .reverse) private var plans: [SaferSessionPlan]
    @Query(sort: \STDTestRecord.testDate, order: .reverse) private var stiTests: [STDTestRecord]
    @Query(sort: \UserProfile.createdAt, order: .forward) private var profiles: [UserProfile]

    @State private var showHelperSummary = false
    @State private var showCheckingInfo = false

    private var context: SafetyAutopilotContext {
        SafetyAutopilotContext(
            entries: entries,
            timers: timers,
            plans: plans,
            stiTests: stiTests,
            profile: profiles.first
        )
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Safety autopilot"),
                            subtitle: String(localized: "A calm place to see what might help next. It looks at your saved logs, timers, plans, sleep, symptoms, STI/PEP timing, and trusted contact."),
                            symbol: "sparkles.rectangle.stack.fill",
                            tint: Color.chillSecondaryBlue
                        )

                        SafetyAutopilotStatusCard(context: context)

                        VStack(alignment: .leading, spacing: 12) {
                            CareSectionTitle(title: String(localized: "Do next"), symbol: "arrow.right.circle.fill")

                            ForEach(context.actions) { action in
                                SafetyAutopilotActionCard(action: action)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            CareSectionTitle(title: String(localized: "More support"), symbol: "ellipsis.circle.fill")

                            SafetyAutopilotLinkRow(
                                title: String(localized: "Helper summary"),
                                detail: String(localized: "A simple summary to share with a GP, GGD, or helper"),
                                symbol: "doc.text.magnifyingglass",
                                tint: Color.chillMint
                            ) { showHelperSummary = true }

                            SafetyAutopilotLinkRow(
                                title: String(localized: "Checking info"),
                                detail: String(localized: "Drug-checking and where to find support"),
                                symbol: "checkmark.seal.text.page.fill",
                                tint: Color.chillIconAmber
                            ) { showCheckingInfo = true }
                        }

                        ConsentMiniCard()
                        EvidenceSourcesSection(title: String(localized: "Why these suggestions?"), sources: EvidenceLibrary.coreSafety)
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .fullScreenCover(isPresented: $showHelperSummary) {
                CareCoverHost { ProfessionalHelperBridgeView() }
            }
            .fullScreenCover(isPresented: $showCheckingInfo) {
                CareCoverHost { DrugCheckingEducationView() }
            }
        }
    }
}

private struct SafetyAutopilotLinkRow: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.chillText)
                    Text(detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .glassSurface(radius: 20, tint: tint.opacity(0.07), interactive: true)
        }
        .buttonStyle(ChillPlainButtonStyle())
    }
}

private struct SafetyAutopilotContext {
    let entries: [NightEntry]
    let timers: [DrugDoseTimerRecord]
    let plans: [SaferSessionPlan]
    let stiTests: [STDTestRecord]
    let profile: UserProfile?

    private var now: Date { .now }

    var latestEntry: NightEntry? {
        entries.first
    }

    var activeTimer: DrugDoseTimerRecord? {
        timers.first { $0.endsAt > now }
    }

    var latestPEPEntry: NightEntry? {
        entries.first { $0.suggestsPEPConcern && $0.pepDeadline > now }
    }

    var recoveryStreakDays: Int {
        ChillInsightCalculator.recoveryStreakDays(entries: entries)
    }

    var riskTrend: (recent: Int, previous: Int) {
        ChillInsightCalculator.riskyLogTrend(entries: entries)
    }

    var actions: [SafetyAutopilotAction] {
        var result: [SafetyAutopilotAction] = []

        if let pep = latestPEPEntry {
            let hours = max(0, Int(pep.pepDeadline.timeIntervalSince(now) / 3600))
            result.append(SafetyAutopilotAction(
                priority: .urgent,
                title: String(localized: "PEP window is active"),
                detail: "It has been less than 72 hours since a log that may include HIV exposure. Contact GGD, your doctor, huisartsenpost, or a hospital now. About \(hours) hours remain.",
                symbol: "cross.case.circle.fill"
            ))
        }

        if let timer = activeTimer {
            let progress = Int((timer.effectProgress(at: now) * 100).rounded())
            result.append(SafetyAutopilotAction(
                priority: timer.redoseNudgeIsActive(at: now) ? .caution : .support,
                title: timer.redoseNudgeIsActive(at: now) ? "Pause before continuing" : "Check-in is active",
                detail: "\(timer.substanceName) check-in is \(progress)% through. Check water, food, body temperature, support, and whether you still feel safe.",
                symbol: "timer.circle.fill"
            ))
        }

        if let entry = latestEntry, entry.reportedMemoryGap {
            result.append(SafetyAutopilotAction(
                priority: entry.memoryNeedsHelp || entry.memoryConsentConcern || entry.memoryInjuries ? .urgent : .caution,
                title: String(localized: "Memory gap protocol"),
                detail: String(localized: "Keep it simple: are you safe now, hurt, missing anything, worried about consent, or needing help? If yes, contact someone you trust or professional support."),
                symbol: "brain.head.profile"
            ))
        }

        if let entry = latestEntry, !entry.skippedNight {
            if entry.sleptYet && entry.sleepHours < 3 {
                result.append(SafetyAutopilotAction(
                    priority: .caution,
                    title: String(localized: "Low sleep recovery"),
                    detail: String(localized: "Less than 3 hours of sleep was logged. Keep today simple: water, food, rest, and avoid stacking stimulants."),
                    symbol: "bed.double.fill"
                ))
            }

            if !entry.aftercareDrankWater || !entry.aftercareAteFood {
                result.append(SafetyAutopilotAction(
                    priority: .support,
                    title: String(localized: "Body basics"),
                    detail: String(localized: "Aftercare is incomplete. Drink water slowly and eat something gentle if you can."),
                    symbol: "drop.fill"
                ))
            }
        }

        if plans.first(where: { $0.plannedDate > now && $0.plannedDate < now.addingTimeInterval(36 * 60 * 60) }) == nil {
            result.append(SafetyAutopilotAction(
                priority: .support,
                title: String(localized: "Plan before the next Chill"),
                detail: String(localized: "A short plan helps: ending time, transport, medication check, substance limits, condoms/lube, emergency contact, and boundaries."),
                symbol: "checkmark.shield.fill"
            ))
        }

        if riskTrend.recent >= 3 && riskTrend.recent > riskTrend.previous {
            result.append(SafetyAutopilotAction(
                priority: .caution,
                title: String(localized: "Something may have changed"),
                detail: "Risky logs increased from \(riskTrend.previous) to \(riskTrend.recent). Look at stress, loneliness, money, housing, conflict, boredom, or breakup patterns.",
                symbol: "waveform.path.ecg"
            ))
        }

        if result.isEmpty {
            result.append(SafetyAutopilotAction(
                priority: .good,
                title: String(localized: "No urgent action right now"),
                detail: String(localized: "Your recent logs do not show an urgent window right now. Keep your lock on, plan ahead, and use the pause tool if cravings show up."),
                symbol: "checkmark.seal.fill"
            ))
        }

        return Array(result.prefix(5))
    }
}

private struct SafetyAutopilotAction: Identifiable {
    let id = UUID()
    let priority: SafetyAutopilotPriority
    let title: String
    let detail: String
    let symbol: String
}

private enum SafetyAutopilotPriority {
    case urgent
    case caution
    case support
    case good

    var label: String {
        switch self {
        case .urgent: "Urgent"
        case .caution: String(localized: "Caution")
        case .support: "Support"
        case .good: "Steady"
        }
    }

    var tint: Color {
        switch self {
        case .urgent: .red
        case .caution: .orange
        case .support: Color.chillSecondaryBlue
        case .good: Color.chillMint
        }
    }
}

private struct SafetyAutopilotStatusCard: View {
    let context: SafetyAutopilotContext

    var body: some View {
        HStack(spacing: 12) {
            SafetyStatusMetric(title: String(localized: "Streak"), value: "\(context.recoveryStreakDays)d", symbol: "leaf.circle.fill", tint: Color.chillMint)
            SafetyStatusMetric(title: String(localized: "Risk trend"), value: "\(context.riskTrend.recent)/3w", symbol: "chart.line.uptrend.xyaxis", tint: context.riskTrend.recent > context.riskTrend.previous ? .orange : Color.chillSecondaryBlue)
            SafetyStatusMetric(title: String(localized: "Timer"), value: context.activeTimer == nil ? "None" : "Active", symbol: "timer", tint: context.activeTimer == nil ? Color.chillSecondary : Color.chillSecondaryBlue)
        }
        .padding(14)
        .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08))
    }
}

private struct SafetyStatusMetric: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.headline)
                .foregroundStyle(Color.chillText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.chillSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 74)
    }
}

private struct SafetyAutopilotActionCard: View {
    let action: SafetyAutopilotAction

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: action.symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(action.priority.tint)
                .frame(width: 42, height: 42)
                .glassSurface(radius: 21, tint: action.priority.tint.opacity(0.12))

            VStack(alignment: .leading, spacing: 6) {
                Text(action.priority.label.uppercased())
                    .font(.caption2.weight(.black))
                    .foregroundStyle(action.priority.tint)
                Text(action.title)
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
                Text(action.detail)
                    .font(.callout)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
        .padding(16)
        .glassSurface(radius: 26, tint: action.priority.tint.opacity(0.08), interactive: true)
    }
}

struct ConsentBoundariesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("consentBoundaryWant") private var want = ""
    @AppStorage("consentBoundaryNo") private var no = ""
    @AppStorage("consentCheckInPhrase") private var checkInPhrase = ""
    @AppStorage("consentExitPlan") private var exitPlan = ""

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Boundaries"),
                            subtitle: String(localized: "Write down what you want, what is off-limits, how someone should check in, and how you can leave. This stays on-device."),
                            symbol: "hand.raised.fill",
                            tint: Color.chillMint
                        )

                        ConsentMiniCard()

                        BoundaryPromptField(title: String(localized: "What I want tonight"), placeholder: String(localized: "Examples: slower pace, condoms, checking in, staying with friends"), text: $want)
                        BoundaryPromptField(title: String(localized: "Hard no"), placeholder: String(localized: "Examples: no filming, no injection use, no certain acts, no pressure to continue"), text: $no)
                        BoundaryPromptField(title: String(localized: "Check-in phrase"), placeholder: String(localized: "Example: ask me 'green, yellow, or red?'"), text: $checkInPhrase)
                        BoundaryPromptField(title: String(localized: "Exit plan"), placeholder: String(localized: "Example: I can call my trusted contact, order a ride, or leave with a friend"), text: $exitPlan)

                        Text("Consent can be changed or withdrawn at any time. If a memory gap or consent concern appears later, use panic support, trusted contact, GGD, CSG, or emergency help.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .glassSurface(radius: 24, tint: Color.chillMint.opacity(0.08))
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BackChevronButton { dismiss() }
                }
            }
            .edgeSwipeToDismiss()
            .endEditingOnTap()
        }
    }
}

private struct ConsentMiniCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CareSectionTitle(title: String(localized: "Consent basics"), symbol: "checkmark.shield.fill")
            ForEach([
                String(localized: "Clear is better than assumed."),
                String(localized: "Pressure, fear, blackout, or being unable to respond means stop."),
                String(localized: "A simple check-in phrase can make boundaries easier to protect.")
            ], id: \.self) { line in
                Label(line, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassSurface(radius: 26, tint: Color.chillMint.opacity(0.08))
    }
}

private struct BoundaryPromptField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.chillText)
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.chillText)
                .padding(14)
                .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)
        }
        .padding(16)
        .glassSurface(radius: 26, tint: .white.opacity(0.28), interactive: true)
    }
}

struct RecoveryModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NightEntry.date, order: .reverse) private var entries: [NightEntry]
    @AppStorage("recoveryGoal") private var recoveryGoal = ""
    @AppStorage("recoverySupportPerson") private var supportPerson = ""
    @AppStorage("recoveryCommitment") private var recoveryCommitment = ""
    @State private var isShowingCravingDelay = false

    private var streakDays: Int {
        ChillInsightCalculator.recoveryStreakDays(entries: entries)
    }

    private var topTriggers: [TrendCount] {
        ChillInsightCalculator.triggerCounts(entries: entries).prefix(4).map { $0 }
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Recovery mode"),
                            subtitle: String(localized: "A no-shame place for reducing, stopping, or simply taking a quieter stretch. A reset is information, not failure."),
                            symbol: "figure.mind.and.body",
                            tint: Color.chillPrimary
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(streakDays)")
                                .font(.system(size: 54, weight: .black, design: .rounded))
                                .foregroundStyle(Color.chillText)
                            Text("days since logged substance use")
                                .font(.headline)
                                .foregroundStyle(Color.chillSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .glassSurface(radius: 32, tint: Color.chillPrimary.opacity(0.10))

                        BoundaryPromptField(title: String(localized: "My goal"), placeholder: String(localized: "Example: no stimulant-related Chills for two weeks"), text: $recoveryGoal)
                        BoundaryPromptField(title: String(localized: "Who can I contact?"), placeholder: String(localized: "Name or plan for someone safe"), text: $supportPerson)
                        BoundaryPromptField(title: String(localized: "What helped last time?"), placeholder: String(localized: "Example: leave earlier, eat first, avoid app dates after midnight"), text: $recoveryCommitment)

                        Button {
                            isShowingCravingDelay = true
                        } label: {
                            Label("Start 10-minute craving delay", systemImage: "pause.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ChillPillButtonStyle(prominent: true))

                        TrendListCard(title: String(localized: "Common triggers"), emptyText: String(localized: "Trigger tags from logs will appear here."), counts: Array(topTriggers), tint: Color.chillPrimary)
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .fullScreenCover(isPresented: $isShowingCravingDelay) {
                CareCoverHost { CravingDelayView() }
            }
            .endEditingOnTap()
        }
    }
}

struct PrivateInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NightEntry.date, order: .reverse) private var entries: [NightEntry]
    @Query(sort: \DrugDoseTimerRecord.startedAt, order: .reverse) private var timers: [DrugDoseTimerRecord]
    @Query(sort: \JournalEntry.date, order: .reverse) private var journals: [JournalEntry]

    private var recentEntries: [NightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .distantPast
        return entries.filter { $0.date >= cutoff }
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Private insights"),
                            subtitle: String(localized: "Patterns are shown as neutral signals, never as judgment. Everything here is calculated locally from your logs."),
                            symbol: "chart.xyaxis.line",
                            tint: Color.chillSecondaryBlue
                        )

                        InsightMetricGrid(entries: recentEntries, timers: timers, journals: journals)
                        TrendListCard(title: String(localized: "What led to it?"), emptyText: String(localized: "Add trigger tags in logs to build this map."), counts: ChillInsightCalculator.triggerCounts(entries: recentEntries), tint: Color.chillSecondaryBlue)
                        TrendListCard(title: String(localized: "What changed?"), emptyText: String(localized: "When risky logs increase, reasons you tag will appear here."), counts: ChillInsightCalculator.changeReasonCounts(entries: recentEntries), tint: .orange)
                        TrendListCard(title: String(localized: "Substances"), emptyText: String(localized: "No substances logged in the selected window."), counts: ChillInsightCalculator.substanceCounts(entries: recentEntries), tint: Color.chillPrimary)
                        PersonalBaselineCard(entries: recentEntries, timers: timers)
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
        }
    }
}

private struct InsightMetricGrid: View {
    let entries: [NightEntry]
    let timers: [DrugDoseTimerRecord]
    let journals: [JournalEntry]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            InsightMetric(title: String(localized: "Chills"), value: "\(entries.filter { !$0.skippedNight }.count)", symbol: "moon.stars.fill", tint: Color.chillSecondaryBlue)
            InsightMetric(title: String(localized: "Risky logs"), value: "\(ChillInsightCalculator.riskyLogTrend(entries: entries).recent)", symbol: "exclamationmark.triangle.fill", tint: .orange)
            InsightMetric(title: String(localized: "Continued"), value: "\(timers.filter { $0.redoseDecision == RedoseDecision.redosed.rawValue }.count)", symbol: "arrow.clockwise.circle.fill", tint: .red)
            InsightMetric(title: String(localized: "Journal"), value: "\(journals.count)", symbol: "book.closed.fill", tint: Color.chillMint)
        }
    }
}

private struct InsightMetric: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title.bold())
                .foregroundStyle(Color.chillText)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        .padding(14)
        .glassSurface(radius: 24, tint: tint.opacity(0.08))
    }
}

private struct PersonalBaselineCard: View {
    let entries: [NightEntry]
    let timers: [DrugDoseTimerRecord]

    private var averageSleep: Double {
        let values = entries.filter(\.sleptYet).map(\.sleepHours)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private var lateTimers: Int {
        timers.filter { Calendar.current.component(.hour, from: $0.startedAt) >= 2 && Calendar.current.component(.hour, from: $0.startedAt) <= 6 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CareSectionTitle(title: String(localized: "Your baseline"), symbol: "person.text.rectangle.fill")
            InsightLine(title: String(localized: "Average logged sleep"), value: averageSleep == 0 ? "Not enough data" : "\(averageSleep.formatted(.number.precision(.fractionLength(1)))) h")
            InsightLine(title: String(localized: "Late timer starts"), value: "\(lateTimers)")
            InsightLine(title: String(localized: "Memory gaps"), value: "\(entries.filter(\.reportedMemoryGap).count)")
            Text("Baseline means “usual for you,” not “good” or “bad.” The app uses this to show when something changes.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08))
    }
}

private struct InsightLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.chillSecondary)
        }
    }
}

private struct TrendListCard: View {
    let title: String
    let emptyText: String
    let counts: [TrendCount]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CareSectionTitle(title: title, symbol: "chart.bar.fill")

            if counts.isEmpty {
                CareEmptyState(text: emptyText)
            } else {
                ForEach(counts.prefix(6)) { item in
                    HStack(spacing: 10) {
                        Text(item.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.chillText)
                        Spacer()
                        Text("\(item.count)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(tint)
                    }
                    .padding(12)
                    .glassSurface(radius: 18, tint: tint.opacity(0.06))
                }
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: tint.opacity(0.08))
    }
}

struct ProfessionalHelperBridgeView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserProfile.createdAt, order: .forward) private var profiles: [UserProfile]
    @Query(sort: \NightEntry.date, order: .reverse) private var entries: [NightEntry]
    @Query(sort: \DrugDoseTimerRecord.startedAt, order: .reverse) private var timers: [DrugDoseTimerRecord]
    @Query(sort: \STDTestRecord.testDate, order: .reverse) private var stiTests: [STDTestRecord]
    @Query(sort: \RiskCheckRecord.createdAt, order: .reverse) private var riskChecks: [RiskCheckRecord]

    private var summary: String {
        HelperSummaryBuilder.summary(
            profile: profiles.first,
            entries: entries,
            timers: timers,
            stiTests: stiTests,
            riskChecks: riskChecks
        )
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Helper summary"),
                            subtitle: String(localized: "Prepare private talking points for a GP, GGD, therapist, addiction-care worker, or trusted professional. You decide whether to share it."),
                            symbol: "doc.text.magnifyingglass",
                            tint: Color.chillMint
                        )

                        ClinicalReviewNoticeCard()

                        Text(summary)
                            .font(.callout.monospaced())
                            .foregroundStyle(Color.chillText)
                            .textSelection(.enabled)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassSurface(radius: 26, tint: .white.opacity(0.32))

                        ShareLink(item: summary) {
                            Label("Share private summary", systemImage: "square.and.arrow.up.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ChillPillButtonStyle(prominent: true))

                        EvidenceSourcesSection(title: String(localized: "Helpful professional routes"), sources: EvidenceLibrary.netherlandsSupport)
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
        }
    }
}

struct DrugCheckingEducationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Checking info"),
                            subtitle: String(localized: "Neutral support information for the Netherlands. Test results and online information reduce uncertainty, but they cannot make use risk-free."),
                            symbol: "checkmark.seal.text.page.fill",
                            tint: Color.chillSecondaryBlue
                        )

                        MedicalSafetyDisclaimerCard(compact: true)

                        DrugCheckingPrincipleCard(
                            title: String(localized: "Assume strength can vary"),
                            detail: String(localized: "Strength and contents can differ between batches. If you feel pressure to continue, pause and consider support before doing anything else."),
                            symbol: "waveform.path.ecg"
                        )
                        DrugCheckingPrincipleCard(
                            title: String(localized: "Do not mix to compensate"),
                            detail: String(localized: "Mixing stimulants, depressants, poppers with erection medication, or unknown substances can change risk faster than expected."),
                            symbol: "exclamationmark.triangle.fill"
                        )
                        DrugCheckingPrincipleCard(
                            title: String(localized: "Use the app as a pause point"),
                            detail: String(localized: "Check-ins, craving delay, risk checker, and the plan page are meant to slow decisions down, not approve a substance, amount, or combination."),
                            symbol: "pause.circle.fill"
                        )

                        EvidenceSourcesSection(title: String(localized: "Dutch information sources"), sources: EvidenceLibrary.drugChecking)
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
        }
    }
}

private struct DrugCheckingPrincipleCard: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.chillSecondaryBlue)
                .frame(width: 42, height: 42)
                .glassSurface(radius: 21, tint: Color.chillSecondaryBlue.opacity(0.12))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassSurface(radius: 26, tint: Color.chillSecondaryBlue.opacity(0.08))
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        PageHeader(
                            title: String(localized: "Privacy Policy"),
                            subtitle: String(localized: "Plain-language privacy summary."),
                            symbol: "hand.raised.square.fill",
                            tint: Color.chillIconTeal
                        )

                        LegalInfoCard(
                            title: String(localized: "What ChillMate can save"),
                            symbol: "tray.full.fill",
                            rows: [
                                String(localized: "Your profile, photo, medication notes, trusted contact, home address, settings, and preferences."),
                                String(localized: "Private logs, sleep notes, STI test records, plans, journal entries, risk checks, check-ins, and emergency-card details."),
                                String(localized: "Optional information you choose to add from Apple Health, Contacts, Photos, or Location Services.")
                            ]
                        )

                        LegalInfoCard(
                            title: String(localized: "How it is used"),
                            symbol: "lock.shield.fill",
                            rows: [
                                String(localized: "To show your private overview, reminders, aftercare prompts, STI follow-ups, emergency shortcuts, and wellbeing reflections."),
                                String(localized: "To sync with Apple Health only for categories you approve in iOS settings."),
                                String(localized: "To create encrypted backups only when backup features are enabled.")
                            ]
                        )

                        LegalInfoCard(
                            title: String(localized: "What ChillMate does not do"),
                            symbol: "eye.slash.fill",
                            rows: [
                                String(localized: "No ads, no selling personal information, and no sharing health or sexual-health details for marketing."),
                                String(localized: "No medical diagnosis, treatment decisions, dosage advice, or confirmation that a substance, amount, or combination is safe."),
                                String(localized: "Messages to contacts are created only when you choose to send them.")
                            ]
                        )

                        LegalInfoCard(
                            title: String(localized: "Control and deletion"),
                            symbol: "trash.fill",
                            rows: [
                                String(localized: "You can delete logs, plans, STI tests, timers, risk checks, journal entries, and account data inside the app."),
                                String(localized: "iOS permission controls remain available in Settings for Health, Location, Notifications, Contacts, and Photos."),
                                String(localized: "If you need urgent help, do not wait for the app. Call local emergency services.")
                            ]
                        )
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
        }
    }
}

struct TermsOfUseView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        PageHeader(
                            title: String(localized: "Terms"),
                            subtitle: String(localized: "Use ChillMate as a private wellbeing and reflection tool."),
                            symbol: "doc.text.fill",
                            tint: Color.chillIconPurple
                        )

                        MedicalSafetyDisclaimerCard()

                        LegalInfoCard(
                            title: String(localized: "Age and app use"),
                            symbol: "18.circle.fill",
                            rows: [
                                String(localized: "ChillMate is intended for adults only."),
                                String(localized: "ChillMate is for adults only. You are responsible for the information you save and who you share it with."),
                                String(localized: "You are responsible for deciding what information you save and who you share it with.")
                            ]
                        )

                        LegalInfoCard(
                            title: String(localized: "Safety boundaries"),
                            symbol: "exclamationmark.triangle.fill",
                            rows: [
                                String(localized: "ChillMate does not encourage substance use, sex, or mixing substances."),
                                String(localized: "ChillMate does not provide dosing, medical, legal, or emergency-services advice."),
                                String(localized: "Emergency guidance is intentionally simple: if there is immediate danger, call local emergency services.")
                            ]
                        )

                        LegalInfoCard(
                            title: String(localized: "Professional support"),
                            symbol: "person.text.rectangle.fill",
                            rows: [
                                String(localized: "Use Support for Dutch sexual-health, crisis, addiction-care, and practical support resources."),
                                String(localized: "For STI, PrEP, PEP, medication, mental-health, or substance concerns, contact a GP, GGD, pharmacist, clinician, counselor, or other qualified professional."),
                                String(localized: "The app can help organize notes for a conversation, but it cannot replace that conversation.")
                            ]
                        )

                        LegalInfoCard(
                            title: String(localized: "Information & sources"),
                            symbol: "checkmark.seal.fill",
                            rows: [
                                String(localized: "All wellbeing and harm-reduction information in ChillMate is compiled from verified, official public-health sources."),
                                String(localized: "It is reviewed and updated from time to time as those sources change or new information becomes available."),
                                String(localized: "ChillMate and its maker are not liable in any way for any decision, action, or outcome based on the app. Always confirm anything important with a qualified professional or official service.")
                            ]
                        )
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
        }
    }
}

private struct LegalInfoCard: View {
    let title: String
    let symbol: String
    let rows: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(Color.chillText)

            ForEach(rows, id: \.self) { row in
                Label(row, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassSurface(radius: 26, tint: .white.opacity(0.26), interactive: true)
    }
}

struct PrivacyReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("requiresFaceID") private var requiresFaceID = false
    @AppStorage("requiresPIN") private var requiresPIN = false
    @AppStorage("localEncryptionEnabled") private var localEncryptionEnabled = true
    @AppStorage("healthKitAutoSync") private var healthKitAutoSync = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("discreetNotifications") private var discreetNotifications = false
    @AppStorage("iCloudBackupEnabled") private var iCloudBackupEnabled = false

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        PageHeader(
                            title: String(localized: "Privacy"),
                            subtitle: String(localized: "A simple view of what ChillMate keeps on this iPhone and which protections are turned on."),
                            symbol: "lock.shield.fill",
                            tint: Color.chillPrimary
                        )

                        PrivacyReceiptRow(title: String(localized: "Saved on this iPhone"), detail: String(localized: "Profile, logs, timers, STI tests, plans, risk checks, journal entries, trusted contact, and preferences."), symbol: "iphone", isEnabled: true)
                        PrivacyReceiptRow(title: String(localized: "Encrypted files"), detail: "Strong iPhone file protection is \(localEncryptionEnabled ? "on" : "available but off in settings").", symbol: "lock.doc.fill", isEnabled: localEncryptionEnabled)
                        PrivacyReceiptRow(title: String(localized: "App lock"), detail: "Face ID: \(requiresFaceID ? "on" : "off"). PIN: \(requiresPIN ? "on" : "off").", symbol: "faceid", isEnabled: requiresFaceID || requiresPIN)
                        PrivacyReceiptRow(title: String(localized: "Apple Health"), detail: healthKitAutoSync ? "ChillMate can read and write only the Health categories you allowed." : "Apple Health sync is off.", symbol: "heart.text.square.fill", isEnabled: healthKitAutoSync)
                        PrivacyReceiptRow(title: String(localized: "Notifications"), detail: notificationsEnabled ? "Notifications are on. Discreet lock-screen wording is \(discreetNotifications ? "on" : "off")." : "Notifications are off.", symbol: "bell.badge.fill", isEnabled: notificationsEnabled)
                        PrivacyReceiptRow(title: String(localized: "iCloud backup"), detail: iCloudBackupEnabled ? "Encrypted backup files can be saved to iCloud Drive." : "iCloud backup is off. Local encrypted recovery stays on this iPhone.", symbol: "icloud.fill", isEnabled: iCloudBackupEnabled)

                        Text("More privacy tools")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.chillSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 14)

                        VStack(spacing: 8) {
                            PrivacyNavRow(title: String(localized: "Security check"), symbol: "checkmark.shield.fill", tint: Color.chillMint) {
                                SecurityHealthCheckView()
                            }
                            PrivacyNavRow(title: String(localized: "Privacy timeline"), symbol: "clock.badge.checkmark.fill", tint: Color.chillIconTeal) {
                                PrivacyTimelineView()
                            }
                            PrivacyNavRow(title: String(localized: "Recently deleted"), symbol: "trash.circle.fill", tint: Color.chillIconOrange) {
                                RecentlyDeletedView()
                            }
                            PrivacyNavRow(title: String(localized: "Privacy Policy"), symbol: "hand.raised.square.fill", tint: Color.chillIconTeal) {
                                PrivacyPolicyView()
                            }
                            PrivacyNavRow(title: String(localized: "Terms of Use"), symbol: "doc.text.fill", tint: Color.chillIconPurple) {
                                TermsOfUseView()
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
        }
    }
}

private struct PrivacyNavRow<Destination: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        // Sub-pages are plain content (no own NavigationStack), so they push
        // onto the shared More-hub stack and get the native back button and
        // interactive swipe-back for free.
        NavigationLink {
            destination()
        } label: {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
            }
            .padding(16)
            .contentShape(Rectangle())
            .glassSurface(radius: 22, tint: tint.opacity(0.12), interactive: true)
        }
        .buttonStyle(ChillPlainButtonStyle())
    }
}

private struct PrivacyReceiptRow: View {
    let title: String
    let detail: String
    let symbol: String
    let isEnabled: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isEnabled ? Color.chillPrimary : Color.chillSecondary)
                .frame(width: 34, height: 34)
                .glassSurface(radius: 17, tint: (isEnabled ? Color.chillPrimary : Color.black).opacity(0.10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.chillText)
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassSurface(radius: 22, tint: .white.opacity(0.28))
    }
}

private struct EvidenceSource: Identifiable {
    let id = UUID()
    let title: String
    let note: String
    let url: URL
}

private enum EvidenceLibrary {
    static let coreSafety = [
        EvidenceSource(title: String(localized: "Soa Aids Nederland"), note: String(localized: "PEP/PrEP and sexual-health guidance."), url: URL(string: "https://www.soaaids.nl")!),
        EvidenceSource(title: String(localized: "GGD"), note: String(localized: "Dutch sexual-health services, STI testing, and local support."), url: URL(string: "https://www.ggd.nl")!),
        EvidenceSource(title: String(localized: "Drugsinfo"), note: String(localized: "Substance information from Trimbos."), url: URL(string: "https://www.drugsinfo.nl")!)
    ]

    static let netherlandsSupport = [
        EvidenceSource(title: String(localized: "GGD"), note: String(localized: "Sexual health, STI, PrEP, and PEP routes."), url: URL(string: "https://www.ggd.nl")!),
        EvidenceSource(title: String(localized: "113 Zelfmoordpreventie"), note: String(localized: "Crisis support in the Netherlands."), url: URL(string: "https://www.113.nl")!),
        EvidenceSource(title: String(localized: "Centrum Seksueel Geweld"), note: String(localized: "Support after sexual assault or consent concerns."), url: URL(string: "https://centrumseksueelgeweld.nl")!),
        EvidenceSource(title: String(localized: "Drugs Infolijn"), note: String(localized: "Questions about drugs and harm reduction."), url: URL(string: "https://www.drugsinfo.nl/drugs/contact-met-de-drugs-infolijn/")!)
    ]

    static let drugChecking = [
        EvidenceSource(title: String(localized: "Drugsinfo"), note: String(localized: "General substance information from Trimbos."), url: URL(string: "https://www.drugsinfo.nl")!),
        EvidenceSource(title: String(localized: "Trimbos drugs knowledge"), note: String(localized: "Monitoring, prevention, and harm-reduction information."), url: URL(string: "https://www.trimbos.nl/kennis/drugs/")!),
        EvidenceSource(title: String(localized: "Rijksoverheid drugs prevention"), note: String(localized: "Dutch government prevention information and official links."), url: URL(string: "https://www.rijksoverheid.nl/onderwerpen/drugs/drugsgebruik-voorkomen")!)
    ]

    static let privacy = [
        EvidenceSource(title: String(localized: "Apple HealthKit HIG"), note: String(localized: "HealthKit requires user permission for health information."), url: URL(string: "https://developer.apple.com/design/human-interface-guidelines/healthkit/")!),
        EvidenceSource(title: String(localized: "Apple HealthKit privacy"), note: String(localized: "Apple guidance for protecting health-related data."), url: URL(string: "https://developer.apple.com/documentation/healthkit/protecting_user_privacy")!),
        EvidenceSource(title: String(localized: "Configure HealthKit access"), note: String(localized: "HealthKit entitlements and usage descriptions."), url: URL(string: "https://developer.apple.com/documentation/xcode/configuring-healthkit-access")!)
    ]
}

private struct EvidenceSourcesSection: View {
    let title: String
    let sources: [EvidenceSource]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CareSectionTitle(title: title, symbol: "link.circle.fill")

            ForEach(sources) { source in
                Link(destination: source.url) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.chillSecondaryBlue)
                            .frame(width: 34, height: 34)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.chillText)
                            Text(source.note)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.chillSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .glassSurface(radius: 18, tint: Color.chillSecondaryBlue.opacity(0.06), interactive: true)
                }
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08))
    }
}

private struct TrendCount: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
}

private enum ChillInsightCalculator {
    static func recoveryStreakDays(entries: [NightEntry], now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let latestUse = entries
            .filter({ !$0.substances.isEmpty })
            .map(\.date)
            .max()
        else {
            return 0
        }

        return max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: latestUse), to: calendar.startOfDay(for: now)).day ?? 0)
    }

    static func riskyLogTrend(entries: [NightEntry], now: Date = .now, calendar: Calendar = .current) -> (recent: Int, previous: Int) {
        let recentCutoff = calendar.date(byAdding: .day, value: -21, to: now) ?? now
        let previousCutoff = calendar.date(byAdding: .day, value: -42, to: now) ?? now
        var recent = 0
        var previous = 0

        for entry in entries where !entry.skippedNight && entry.hadSex && !entry.substances.isEmpty {
            if entry.date >= recentCutoff {
                recent += 1
            } else if entry.date >= previousCutoff {
                previous += 1
            }
        }

        return (recent, previous)
    }

    static func triggerCounts(entries: [NightEntry]) -> [TrendCount] {
        sortedCounts(entries.flatMap { $0.triggerTags.map(\.rawValue) })
    }

    static func changeReasonCounts(entries: [NightEntry]) -> [TrendCount] {
        sortedCounts(entries.flatMap { $0.changeReasons.map(\.rawValue) })
    }

    static func substanceCounts(entries: [NightEntry]) -> [TrendCount] {
        sortedCounts(entries.flatMap(\.substances))
    }

    private static func sortedCounts(_ values: [String]) -> [TrendCount] {
        Dictionary(grouping: values, by: { $0 })
            .map { TrendCount(label: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.label < $1.label
                }
                return $0.count > $1.count
            }
    }
}

struct UnifiedTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NightEntry.date, order: .reverse) private var entries: [NightEntry]
    @Query(sort: \JournalEntry.date, order: .reverse) private var journalEntries: [JournalEntry]
    @Query(sort: \DrugDoseTimerRecord.startedAt, order: .reverse) private var timers: [DrugDoseTimerRecord]
    @Query(sort: \SaferSessionPlan.plannedDate, order: .reverse) private var plans: [SaferSessionPlan]
    @Query(sort: \STDTestRecord.testDate, order: .reverse) private var tests: [STDTestRecord]

    private var events: [UnifiedTimelineEvent] {
        var result: [UnifiedTimelineEvent] = []
        result += entries.map {
            UnifiedTimelineEvent(
                date: $0.date,
                title: $0.skippedNight ? "Skipped Chill check" : "Chill log",
                detail: $0.skippedNight ? "Marked as skipped" : "\($0.partnerSummary), \($0.substances.isEmpty ? "no substances" : $0.substances.joined(separator: ", "))",
                symbol: $0.skippedNight ? "moon.zzz.fill" : "heart.text.square.fill",
                tint: $0.skippedNight ? Color.chillIconPurple : Color.chillIconPink
            )
        }
        result += journalEntries.map {
            UnifiedTimelineEvent(date: $0.date, title: String(localized: "Journal"), detail: $0.rememberClearly.isEmpty ? "Saved reflection" : $0.rememberClearly, symbol: "book.closed.fill", tint: Color.chillIconPurple)
        }
        result += timers.map {
            let route = AdministrationRoute(rawValue: $0.administrationRoute)?.displayName ?? "Saved route"
            return UnifiedTimelineEvent(date: $0.startedAt, title: "\($0.substanceName) check-in", detail: "\(route), \($0.durationHours.formatted(.number.precision(.fractionLength(0...1)))) h reminder", symbol: "timer", tint: Color.chillIconAmber)
        }
        result += plans.map {
            UnifiedTimelineEvent(date: $0.plannedDate, title: String(localized: "Before-Chill plan"), detail: $0.transportPlan.isEmpty ? "Ends \($0.endingDate.formatted(date: .omitted, time: .shortened))" : $0.transportPlan, symbol: "checkmark.shield.fill", tint: Color.chillMint)
        }
        result += tests.map {
            UnifiedTimelineEvent(date: $0.testDate, title: String(localized: "STI test"), detail: $0.hasPositiveResult ? "Positive result saved" : "Results \($0.resultsDueDate.formatted(date: .abbreviated, time: .omitted))", symbol: "cross.case.fill", tint: Color.chillIconTeal)
        }
        return result.sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(title: String(localized: "Full timeline"), subtitle: String(localized: "One private timeline with logs, journal notes, plans, timers, and STI tests."), symbol: "timeline.selection", tint: Color.chillSecondaryBlue)
                        if events.isEmpty {
                            Text("Nothing has been saved yet.")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Color.chillSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .glassSurface(radius: 24, tint: .white.opacity(0.24))
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(Array(events.prefix(80))) { event in
                                    UnifiedTimelineEventRow(event: event)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

private struct UnifiedTimelineEvent: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
}

private struct UnifiedTimelineEventRow: View {
    let event: UnifiedTimelineEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(event.tint)
                .frame(width: 36, height: 36)
                .glassSurface(radius: 18, tint: event.tint.opacity(0.12))
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(.headline).foregroundStyle(Color.chillText)
                Text(event.detail).font(.caption.weight(.semibold)).foregroundStyle(Color.chillSecondary).lineLimit(2)
                Text(event.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2.weight(.bold)).foregroundStyle(Color.chillTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassSurface(radius: 22, tint: event.tint.opacity(0.08))
    }
}

struct PrivacyTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lastICloudBackupTimestamp") private var lastICloudBackupTimestamp = 0.0
    @AppStorage("lastICloudRestoreTimestamp") private var lastICloudRestoreTimestamp = 0.0
    @AppStorage("lastOnDeviceRecoverySnapshotTimestamp") private var lastOnDeviceRecoverySnapshotTimestamp = 0.0
    @AppStorage("lastOnDeviceRecoveryRestoreTimestamp") private var lastOnDeviceRecoveryRestoreTimestamp = 0.0
    @AppStorage("lastAppUseTimestamp") private var lastAppUseTimestamp = 0.0
    @AppStorage("lastOnDeviceRecoveryStatus") private var lastOnDeviceRecoveryStatus = ""
    @AppStorage("lastICloudBackupStatus") private var lastICloudBackupStatus = ""
    @AppStorage("requiresFaceID") private var requiresFaceID = false
    @AppStorage("requiresPIN") private var requiresPIN = false
    @AppStorage("iCloudBackupEnabled") private var iCloudBackupEnabled = false
    @AppStorage("discreetNotifications") private var discreetNotifications = false

    private var rows: [PrivacyTimelineRowModel] {
        [
            PrivacyTimelineRowModel(title: String(localized: "iCloud backup"), detail: iCloudBackupEnabled ? statusText(lastICloudBackupStatus, fallback: String(localized: "Enabled")) : String(localized: "Off"), date: date(from: lastICloudBackupTimestamp), symbol: "icloud.and.arrow.up.fill", tint: Color.chillSecondaryBlue),
            PrivacyTimelineRowModel(title: String(localized: "iCloud restore"), detail: String(localized: "Latest restore attempt"), date: date(from: lastICloudRestoreTimestamp), symbol: "icloud.and.arrow.down.fill", tint: Color.chillIconTeal),
            PrivacyTimelineRowModel(title: String(localized: "iPhone recovery backup"), detail: statusText(lastOnDeviceRecoveryStatus, fallback: "Automatic encrypted snapshot"), date: date(from: lastOnDeviceRecoverySnapshotTimestamp), symbol: "externaldrive.fill.badge.checkmark", tint: Color.chillMint),
            PrivacyTimelineRowModel(title: String(localized: "Recovery restore"), detail: String(localized: "Recovered after reinstall when available"), date: date(from: lastOnDeviceRecoveryRestoreTimestamp), symbol: "arrow.counterclockwise.circle.fill", tint: Color.chillIconPurple),
            PrivacyTimelineRowModel(title: String(localized: "App lock"), detail: requiresFaceID || requiresPIN ? "Face ID or PIN is on" : "No extra app lock is on", date: nil, symbol: "lock.shield.fill", tint: Color.chillMint),
            PrivacyTimelineRowModel(title: String(localized: "Notifications"), detail: discreetNotifications ? "Discreet text is on" : "Detailed text may show", date: nil, symbol: "bell.badge.fill", tint: Color.chillIconAmber),
            PrivacyTimelineRowModel(title: String(localized: "Last opened"), detail: String(localized: "Latest app activity saved locally"), date: date(from: lastAppUseTimestamp), symbol: "iphone", tint: Color.chillSecondaryBlue)
        ]
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(title: String(localized: "Privacy timeline"), subtitle: String(localized: "A simple history of backups, restores, lock choices, and app privacy settings."), symbol: "clock.badge.checkmark.fill", tint: Color.chillIconTeal)
                        VStack(spacing: 10) {
                            ForEach(rows) { row in PrivacyTimelineRow(row: row) }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func date(from timestamp: Double) -> Date? { timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil }
    private func statusText(_ status: String, fallback: String) -> String { status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : status }
}

private struct PrivacyTimelineRowModel: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let date: Date?
    let symbol: String
    let tint: Color
}

private struct PrivacyTimelineRow: View {
    let row: PrivacyTimelineRowModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: row.symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(row.tint)
                .frame(width: 36, height: 36)
                .glassSurface(radius: 18, tint: row.tint.opacity(0.12))
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title).font(.headline).foregroundStyle(Color.chillText)
                Text(row.detail).font(.caption.weight(.semibold)).foregroundStyle(Color.chillSecondary).fixedSize(horizontal: false, vertical: true)
                if let date = row.date {
                    Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption2.weight(.bold)).foregroundStyle(Color.chillTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassSurface(radius: 22, tint: row.tint.opacity(0.08))
    }
}

struct SecurityHealthCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("requiresFaceID") private var requiresFaceID = false
    @AppStorage("requiresPIN") private var requiresPIN = false
    @AppStorage("localEncryptionEnabled") private var localEncryptionEnabled = true
    @AppStorage("iCloudBackupEnabled") private var iCloudBackupEnabled = false
    @AppStorage("discreetNotifications") private var discreetNotifications = false
    @AppStorage("healthKitAutoSync") private var healthKitAutoSync = false

    private var checks: [SecurityCheckItem] {
        [
            SecurityCheckItem(title: String(localized: "Local encryption"), detail: String(localized: "Device files use iOS data protection."), isOn: localEncryptionEnabled, symbol: "lock.fill", tint: Color.chillMint),
            SecurityCheckItem(title: String(localized: "App lock"), detail: String(localized: "Face ID or PIN before opening."), isOn: requiresFaceID || requiresPIN, symbol: "faceid", tint: Color.chillSecondaryBlue),
            SecurityCheckItem(title: String(localized: "Encrypted backup"), detail: String(localized: "iCloud backup is optional and encrypted before upload."), isOn: iCloudBackupEnabled, symbol: "icloud.fill", tint: Color.chillIconTeal),
            SecurityCheckItem(title: String(localized: "Discreet notifications"), detail: String(localized: "Lock-screen text stays vague."), isOn: discreetNotifications, symbol: "bell.slash.fill", tint: Color.chillIconPurple),
            SecurityCheckItem(title: String(localized: "Apple Health Sync"), detail: String(localized: "Health reads and writes only when you allow it."), isOn: healthKitAutoSync, symbol: "heart.fill", tint: Color.chillIconPink)
        ]
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(title: String(localized: "Security check"), subtitle: "\(checks.filter(\.isOn).count) of \(checks.count) protections are on. Turn on the ones that match how private you want ChillMate to be.", symbol: "checkmark.shield.fill", tint: Color.chillMint)
                        VStack(spacing: 10) { ForEach(checks) { SecurityCheckRow(item: $0) } }
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

private struct SecurityCheckItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let isOn: Bool
    let symbol: String
    let tint: Color
}

private struct SecurityCheckRow: View {
    let item: SecurityCheckItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(item.isOn ? item.tint : Color.chillTertiary)
                .frame(width: 36, height: 36)
                .glassSurface(radius: 18, tint: item.tint.opacity(0.10))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline).foregroundStyle(Color.chillText)
                Text(item.detail).font(.caption.weight(.semibold)).foregroundStyle(Color.chillSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassSurface(radius: 22, tint: item.tint.opacity(item.isOn ? 0.09 : 0.04))
    }
}

struct RecentlyDeletedView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items = RecentlyDeletedStore.items()

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(title: String(localized: "Recently deleted"), subtitle: String(localized: "This list helps you remember what was removed. To restore actual data, use an encrypted backup."), symbol: "trash.circle.fill", tint: Color.chillIconOrange)
                        if items.isEmpty {
                            Text("No deleted items have been recorded.")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Color.chillSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .glassSurface(radius: 24, tint: .white.opacity(0.24))
                        } else {
                            VStack(spacing: 10) { ForEach(items) { RecentlyDeletedRow(item: $0) } }
                            GlassActionButton(prominent: false) {
                                RecentlyDeletedStore.clear()
                                items = []
                            } label: {
                                Label("Clear this list", systemImage: "trash")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

private struct RecentlyDeletedRow: View {
    let item: RecentlyDeletedItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "trash.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.chillIconOrange)
                .frame(width: 36, height: 36)
                .glassSurface(radius: 18, tint: Color.chillIconOrange.opacity(0.12))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline).foregroundStyle(Color.chillText)
                Text(item.detail).font(.caption.weight(.semibold)).foregroundStyle(Color.chillSecondary).fixedSize(horizontal: false, vertical: true)
                Text("\(item.kind) • \(item.deletedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption2.weight(.bold)).foregroundStyle(Color.chillTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassSurface(radius: 22, tint: Color.chillIconOrange.opacity(0.08))
    }
}

struct WeeklyReflectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NightEntry.date, order: .reverse) private var entries: [NightEntry]
    @Query(sort: \JournalEntry.date, order: .reverse) private var journalEntries: [JournalEntry]

    private var recentEntries: [NightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        return entries.filter { $0.date >= cutoff }
    }

    private var recentJournals: [JournalEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        return journalEntries.filter { $0.date >= cutoff }
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(title: String(localized: "Weekly reflection"), subtitle: String(localized: "A quick look at the last 7 days, made for noticing patterns without judging yourself."), symbol: "calendar.badge.clock", tint: Color.chillIconPurple)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            WeeklyReflectionMetric(title: String(localized: "Chills"), value: "\(recentEntries.filter { !$0.skippedNight }.count)", symbol: "heart.text.square.fill", tint: Color.chillIconPink)
                            WeeklyReflectionMetric(title: String(localized: "Substance logs"), value: "\(recentEntries.filter { !$0.substances.isEmpty }.count)", symbol: "pills.fill", tint: Color.chillSecondaryBlue)
                            WeeklyReflectionMetric(title: String(localized: "Journals"), value: "\(recentJournals.count)", symbol: "book.closed.fill", tint: Color.chillIconPurple)
                            WeeklyReflectionMetric(title: String(localized: "Memory gaps"), value: "\(recentEntries.filter(\.reportedMemoryGap).count)", symbol: "questionmark.circle.fill", tint: Color.chillIconOrange)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            CareSectionTitle(title: String(localized: "Gentle prompts"), symbol: "sparkles")
                            WeeklyPrompt(text: String(localized: "What felt easier this week than expected?"))
                            WeeklyPrompt(text: String(localized: "Was there a moment where you needed support sooner?"))
                            WeeklyPrompt(text: String(localized: "What is one small boundary that would help next time?"))
                        }
                        .padding(14)
                        .glassSurface(radius: 24, tint: Color.chillIconPurple.opacity(0.08))
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

private struct WeeklyReflectionMetric: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .glassSurface(radius: 16, tint: tint.opacity(0.12))
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title3.weight(.bold)).foregroundStyle(Color.chillText).monospacedDigit()
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(Color.chillSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .glassSurface(radius: 20, tint: tint.opacity(0.08))
    }
}

private struct WeeklyPrompt: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillIconPurple)
                .padding(.top, 2)
            Text(text)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.chillText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.20), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct RecentlyDeletedItem: Codable, Identifiable {
    var id = UUID()
    var kind: String
    var title: String
    var detail: String
    var deletedAt: Date
}

enum RecentlyDeletedStore {
    private static let key = "recentlyDeletedItems"

    static func items() -> [RecentlyDeletedItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([RecentlyDeletedItem].self, from: data) else {
            return []
        }
        return items.sorted { $0.deletedAt > $1.deletedAt }
    }

    static func record(kind: String, title: String, detail: String, deletedAt: Date = .now) {
        var current = items()
        current.insert(RecentlyDeletedItem(kind: kind, title: title, detail: detail, deletedAt: deletedAt), at: 0)
        current = Array(current.prefix(40))
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

private enum HelperSummaryBuilder {
    static func summary(
        profile: UserProfile?,
        entries: [NightEntry],
        timers: [DrugDoseTimerRecord],
        stiTests: [STDTestRecord],
        riskChecks: [RiskCheckRecord],
        now: Date = .now
    ) -> String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? .distantPast
        let recentEntries = entries.filter { $0.date >= cutoff }
        let recentTimers = timers.filter { $0.startedAt >= cutoff }
        let risky = recentEntries.filter { !$0.skippedNight && $0.hadSex && !$0.substances.isEmpty }
        let memoryGaps = recentEntries.filter(\.reportedMemoryGap)
        let positiveTests = stiTests.filter(\.hasPositiveResult)
        let substances = ChillInsightCalculator.substanceCounts(entries: recentEntries).prefix(6).map { "\($0.label) (\($0.count))" }.joined(separator: ", ")
        let triggers = ChillInsightCalculator.triggerCounts(entries: recentEntries).prefix(6).map { "\($0.label) (\($0.count))" }.joined(separator: ", ")
        let medication = profile?.medications.map { "\($0.name) \($0.timingSummary)" }.joined(separator: "; ") ?? "Not set"

        return """
        ChillMate private helper summary
        Generated: \(now.formatted(date: .abbreviated, time: .shortened))

        Profile
        Name: \(profile?.name.isEmpty == false ? profile!.name : String(localized: "Not set"))
        Age: \(profile?.calculatedAge.description ?? "Not set")
        Sex: \(profile?.sex ?? "Not set")
        PrEP: \(profile?.isOnPrEP == true ? "Yes, \(profile?.prepSchedule ?? "")" : "No / not set")
        Medication: \(medication.isEmpty ? "Not set" : medication)

        Past 90 days
        Chills logged: \(recentEntries.filter { !$0.skippedNight }.count)
        Logs with sex + substances: \(risky.count)
        Check-in records: \(recentTimers.count)
        Continued-after-pause records: \(recentTimers.filter { $0.redoseDecision == RedoseDecision.redosed.rawValue }.count)
        Memory gaps reported: \(memoryGaps.count)
        STI tests saved: \(stiTests.count)
        Positive STI tests: \(positiveTests.count)

        Patterns
        Substances: \(substances.isEmpty ? "Not enough data" : substances)
        Triggers: \(triggers.isEmpty ? "Not enough data" : triggers)

        Talking points
        - I want help understanding my patterns without judgment.
        - I want to discuss sleep, substances, sex, consent, medication interactions, PrEP/PEP/STI care, or recovery goals.
        - I understand this export is self-reported app data and not a diagnosis.
        """
    }
}
