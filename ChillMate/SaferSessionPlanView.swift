import Foundation
import SwiftData
import SwiftUI

struct SaferSessionPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(ChillMateQueries.recentPlansByCreation) private var plans: [SaferSessionPlan]

    @AppStorage(DefaultsKey.trustedContactName) private var trustedContactName = ""
    @AppStorage(DefaultsKey.trustedContactPhone) private var trustedContactPhone = ""

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
        Group {
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: savePlan) {
                        Text("Save").font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(Color.chillPrimary)
                    .disabled(!canSavePlan)
                    .opacity(canSavePlan ? 1 : 0.5)
                }
            }
            .onChange(of: plannedDate) { _, newDate in
                if endingDate <= newDate {
                    endingDate = Calendar.current.date(byAdding: .hour, value: 4, to: newDate) ?? newDate.addingTimeInterval(4 * 60 * 60)
                }
            }
            .endEditingOnTap()
        }
    }

    private var contactSubtitle: String {
        if trustedContactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "Add a trusted contact in Emergency Information.")
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
        modelContext.saveChanges()

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

/// Shared with AftercareView, so it is internal rather than file-private.
struct PrepGuideCard: View {
    private let steps = [
        String(localized: "Use this only for around-sex PrEP when PrEP is not taken daily."),
        String(localized: "Follow the exact timing and amount from your prescriber or sexual-health service."),
        String(localized: "Set reminders from your own prescription instructions."),
        String(localized: "If anything feels unclear, contact your prescriber, a sexual-health service, or pharmacist before relying on the plan.")
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
                modelContext.saveChanges()
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
