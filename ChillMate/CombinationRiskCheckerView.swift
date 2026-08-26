import Foundation
import SwiftData
import SwiftUI
import TipKit

struct CombinationRiskCheckerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(ChillMateQueries.recentRiskChecks) private var riskChecks: [RiskCheckRecord]
    @Query(ChillMateQueries.profile) private var profiles: [UserProfile]

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
        Group {
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

                        combinationRiskCheckerViewContinued
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: chillPinnedTrailingPlacement) {
                    Button(action: saveRiskCheck) {
                        Text("Save").font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(Color.chillPrimary)
                }
            }
            .endEditingOnTap()
        }
    }

    /// Second half of `CombinationRiskCheckerView`'s body, which ran to 122 lines.
    ///
    /// Split purely for readability: these are the same views in the same
    /// order, still direct children of the same container.
    @ViewBuilder
    private var combinationRiskCheckerViewContinued: some View {
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

            combinationRiskCheckerViewContinuedTail
    }

    /// Second half of `CombinationRiskCheckerView`'s body, which ran to 171 lines.
    ///
    /// Split purely for readability: these are the same views in the same
    /// order, still direct children of the same container.
    @ViewBuilder
    private var combinationRiskCheckerViewContinuedTail: some View {
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
            respiratoryLevel: assessment.respiratoryRisk.label,
            cardiacLevel: assessment.cardiacRisk.label,
            bloodPressureLevel: assessment.bloodPressureRisk.label,
            warnings: assessment.interactionWarnings
        )
        modelContext.insert(record)
        modelContext.saveChanges()
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
                    modelContext.saveChanges()
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

            TipView(SiriCombinationTip())

            if assessment.substances.isEmpty && assessment.medicationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                CareEmptyState(text: String(localized: "Select at least one substance or add medication to see a risk check."))
            } else {
                VStack(spacing: 10) {
                    RiskLevelRow(title: String(localized: "Serotonin syndrome"), level: assessment.serotoninRisk, detail: assessment.serotoninDetail)
                    RiskLevelRow(title: String(localized: "Dehydration"), level: assessment.dehydrationRisk, detail: assessment.dehydrationDetail)
                    RiskLevelRow(title: String(localized: "Stimulant overload"), level: assessment.stimulantOverloadRisk, detail: assessment.stimulantDetail)
                    RiskLevelRow(title: String(localized: "Breathing"), level: assessment.respiratoryRisk, detail: assessment.respiratoryDetail)
                    RiskLevelRow(title: String(localized: "Heart strain"), level: assessment.cardiacRisk, detail: assessment.cardiacDetail)
                    RiskLevelRow(title: String(localized: "Blood pressure"), level: assessment.bloodPressureRisk, detail: assessment.bloodPressureDetail)
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

                    ForEach(assessment.interactionFindings) { finding in
                        RiskWarningLine(finding: finding)
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

/// One row of the assessment's warning list, carrying the severity its source
/// rated it at.
///
/// The screen draws on two sources that cannot see each other's inputs: the preset
/// chain in `CombinationAssessment`, which is the only place medication
/// interactions live, and `SubstanceInteractionChecker`, whose curated table rates
/// substance pairs. Carrying an explicit level on both is what lets the merge
/// compare them.
///
/// It also replaces the badge this screen used to show, which was picked by
/// searching the warning text for English words such as "avoid" or "dangerous".
/// That guess collapsed to the mildest badge for every non-English user, and it
/// stamped the "nothing matched" line with a risk badge because that sentence
/// happens to contain the word "can".
struct InteractionFinding: Identifiable, Hashable {
    let text: String
    /// Nil only on the "nothing matched" line, which is informational and gets no
    /// severity badge.
    let level: SubstanceInteraction.Level?

    var id: String { text }
}

private struct RiskWarningLine: View {
    let finding: InteractionFinding

    /// Capsule colour for the severity badge.
    ///
    /// Deliberately not `SubstanceInteraction.Level.color`: that palette is tuned
    /// for coloured text on a tinted card, and its yellow leaves white capsule text
    /// hard to read. These are the three tints this screen already draws white
    /// labels on, in the risk rows directly above.
    private func badgeTint(for level: SubstanceInteraction.Level) -> Color {
        switch level {
        case .caution:
            Color.chillSecondaryBlue
        case .serious:
            .orange
        case .critical:
            .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let level = finding.level {
                Text(level.label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(badgeTint(for: level)))
            }

            Label(finding.text, systemImage: "exclamationmark.circle.fill")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A hazard both warning sources can describe, used to keep the merged list from
/// saying the same thing twice in two different voices.
///
/// Only the preset lines a curated table entry can genuinely stand in for are
/// classified. Anything unclassified on either side is always kept, so a table row
/// added later can never silently swallow a preset warning.
private enum HazardTopic: Hashable {
    /// GHB or GBL stacked with another depressant.
    case ghbDepressantStack
    /// Poppers with Viagra or Kamagra.
    case poppersWithErectileMedication
    /// Two or more of MDMA, 3-MMC and cocaine.
    case stimulantStack
    /// Alcohol with cocaine.
    case alcoholWithCocaine

    /// Classifies a curated table entry, or returns nil when no preset line covers
    /// the same ground.
    init?(_ substances: Set<Substance>) {
        let stimulants: Set<Substance> = [.mdma, .threeMMC, .cocaine]

        if substances.contains(.ghb) || substances.contains(.gbl),
           substances.contains(.alcohol) || substances.contains(.ketamine) {
            self = .ghbDepressantStack
        } else if substances.contains(.poppers),
                  substances.contains(.viagra) || substances.contains(.kamagra) {
            self = .poppersWithErectileMedication
        } else if substances == [.cocaine, .alcohol] {
            self = .alcoholWithCocaine
        } else if substances.count >= 2, substances.isSubset(of: stimulants) {
            self = .stimulantStack
        } else {
            return nil
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

/// Internal rather than private so the tests can assert on what the risk checker
/// screen actually produces for a selection. The interaction table used to be
/// verified in isolation, which let a green suite coexist with a screen that never
/// consulted it.
struct CombinationAssessment {
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

    /// Substances that slow breathing. Medication the user typed is folded in
    /// through `hasMedicationCategory`, so a prescribed sedative or opioid counts
    /// as another depressant on the pile.
    private var depressants: [Substance] {
        substances.filter { [.ghb, .gbl, .alcohol, .ketamine].contains($0) }
    }

    private var depressantMedicationCount: Int {
        (hasMedicationCategory(.sedative) ? 1 : 0) + (hasMedicationCategory(.opioid) ? 1 : 0)
    }

    /// Breathing slowing or stopping. This is the hazard behind most fatal
    /// outcomes involving the substances ChillMate tracks, and nothing on this
    /// screen used to name it.
    var respiratoryRisk: RiskLevel {
        let total = depressants.count + depressantMedicationCount

        // GHB and GBL have a narrow margin on their own; anything else sedating
        // on top of them is the pattern that stops people breathing.
        if hasGHBLike && total >= 2 {
            return .high
        }

        if total >= 2 {
            return .high
        }

        if total == 1 {
            return hasGHBLike || timing == .sameSession ? .caution : .lower
        }

        return .lower
    }

    /// Strain on the heart: stimulants driving rate and pressure up, and
    /// vasodilators swinging pressure the other way.
    var cardiacRisk: RiskLevel {
        let stimulantCount = stimulants.count + (hasMedicationCategory(.stimulantMedication) ? 1 : 0)
        let hasPoppers = substanceSet.contains(.poppers)

        if stimulantCount >= 1 && hasPoppers {
            return .high
        }

        if stimulantCount >= 2 {
            return .high
        }

        if stimulantCount == 1 && hasErectileMedication {
            return .caution
        }

        if stimulantCount == 1 {
            return timing == .sameSession ? .caution : .lower
        }

        return hasPoppers ? .caution : .lower
    }

    /// A sudden drop in blood pressure. The poppers and erection-medication pair
    /// is the well-known one, but nitrates and alpha blockers reach it too.
    var bloodPressureRisk: RiskLevel {
        let hasPoppers = substanceSet.contains(.poppers)

        if hasPoppers && (hasErectileMedication || hasMedicationCategory(.nitrateLike)) {
            return .high
        }

        if hasErectileMedication && (hasMedicationCategory(.nitrateLike) || hasMedicationCategory(.alphaBlocker)) {
            return .high
        }

        if hasPoppers && substanceSet.contains(.alcohol) {
            return .caution
        }

        if hasPoppers || hasErectileMedication {
            return .caution
        }

        return .lower
    }

    var respiratoryDetail: String {
        switch respiratoryRisk {
        case .high:
            String(localized: "More than one thing that slows breathing is selected. Signs to watch for: snoring or gurgling, slow or shallow breaths, blue lips, or someone who cannot be woken. Put them on their side and call emergency services. Do not leave them to sleep it off.")
        case .caution:
            String(localized: "One thing that slows breathing is selected. Keep the dose low, leave long gaps, and stay with someone who knows what you took.")
        case .lower:
            String(localized: "Nothing selected is a known breathing depressant, though amount and other medication still matter.")
        }
    }

    var cardiacDetail: String {
        switch cardiacRisk {
        case .high:
            String(localized: "This mix puts real strain on the heart, either by stacking stimulants or by swinging blood pressure up and down. Chest pain, a heart rate that will not settle, or breathlessness at rest all mean stop and get help.")
        case .caution:
            String(localized: "Something selected raises heart rate or moves blood pressure. Sit down if your heart races, and give yourself long breaks.")
        case .lower:
            String(localized: "No obvious pattern of heart strain is selected.")
        }
    }

    var bloodPressureDetail: String {
        switch bloodPressureRisk {
        case .high:
            String(localized: "This combination can drop blood pressure suddenly and severely. That means fainting, and at worst a stroke or cardiac arrest. Do not combine these. If someone collapses, lie them flat, raise their legs, and call emergency services.")
        case .caution:
            String(localized: "Something selected widens blood vessels and lowers blood pressure. Sit or lie down before using it, and stand up slowly afterwards.")
        case .lower:
            String(localized: "No obvious blood pressure drop is selected.")
        }
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

    /// Every interaction warning this screen shows, in the order it shows them.
    ///
    /// Two sources feed it. The preset chain in `presetFindings(supersededBy:)` is
    /// the only one that can see the medication the user typed, so it leads and
    /// stays intact. The curated `SubstanceInteractionChecker` table rates
    /// substance pairs and knows nothing about medication, so its rows follow in
    /// their own most severe first order.
    ///
    /// Until 4.2.1 the table was never consulted here at all. A pairing the table
    /// rates serious, alcohol with ketamine being the plainest example, matched no
    /// preset branch and so fell through to the "nothing matched" line below, which
    /// told the user there was nothing worth knowing about a depressant stack.
    var interactionFindings: [InteractionFinding] {
        let rated = SubstanceInteractionChecker.warnings(for: substanceSet)

        // Highest rating the table gave each hazard the preset chain also
        // describes. A preset line only steps aside for a table row that covers its
        // hazard at least as severely, so merging can add detail but can never
        // soften a warning the user would otherwise have seen.
        var ratedTopics: [HazardTopic: SubstanceInteraction.Level] = [:]
        for interaction in rated {
            guard let topic = HazardTopic(interaction.substances) else { continue }
            ratedTopics[topic] = max(ratedTopics[topic] ?? interaction.level, interaction.level)
        }

        // Belt and braces against the same sentence arriving from both sources:
        // the topic rules above should already prevent it, but a duplicate row here
        // would also collide in SwiftUI, which identifies these rows by their text.
        var seenText: Set<String> = []
        let merged = (presetFindings(supersededBy: ratedTopics)
            + rated.map { InteractionFinding(text: $0.warning, level: $0.level) })
            .filter { seenText.insert($0.text).inserted }

        guard merged.isEmpty else { return merged }

        return [
            InteractionFinding(
                text: String(localized: "No known major preset warning matched. Unknown amount, contents, health conditions, and medication changes can still matter."),
                level: nil
            )
        ]
    }

    /// Flat warning text in display order. `RiskCheckRecord` stores plain strings,
    /// so a saved check keeps exactly the wording the user was shown.
    var interactionWarnings: [String] {
        interactionFindings.map(\.text)
    }

    /// The hand-written preset chain, unchanged in content and order, minus any
    /// line the curated table already covers at an equal or higher rating.
    ///
    /// Severities are stated here rather than guessed from the wording, so the
    /// merge has something to compare. They match the badge colours these lines
    /// already carried, with the one deliberate exception noted at the GHB branch.
    private func presetFindings(supersededBy ratedTopics: [HazardTopic: SubstanceInteraction.Level]) -> [InteractionFinding] {
        var findings: [InteractionFinding] = []

        func add(_ text: String, _ level: SubstanceInteraction.Level, superseding topic: HazardTopic? = nil) {
            if let topic, let rated = ratedTopics[topic], rated >= level { return }
            findings.append(InteractionFinding(text: text, level: level))
        }

        if hasMedicationCategory(.nitrateLike) && (hasErectileMedication || substanceSet.contains(.poppers)) {
            add(String(localized: "Nitrates, nicorandil, or riociguat with Viagra, Kamagra, or poppers can cause a severe blood pressure drop. Do not combine."), .critical)
        }

        if hasMedicationCategory(.alphaBlocker) && hasErectileMedication {
            add(String(localized: "Alpha blockers with Viagra or Kamagra can increase dizziness or fainting risk. Check with a clinician before combining."), .serious)
        }

        if hasGHBLike {
            if substanceSet.contains(.alcohol) || substanceSet.contains(.ketamine) || hasMedicationCategory(.sedative) || hasMedicationCategory(.opioid) {
                // Rated critical rather than the middle badge this line used to
                // show. It describes the depressant stacking mechanism that has
                // killed people, and the table rates the same pairing critical.
                //
                // It can only stand aside for the table when the other depressant is
                // a substance. Sedative and opioid medication is invisible to the
                // table, so whenever one of those matched, this is the only line
                // that speaks for it.
                let sedatingMedication = hasMedicationCategory(.sedative) || hasMedicationCategory(.opioid)
                add(
                    String(localized: "GHB/GBL with alcohol, ketamine, sedatives, or opioids can cause unconsciousness or breathing problems."),
                    .critical,
                    superseding: sedatingMedication ? nil : .ghbDepressantStack
                )
            } else {
                add(String(localized: "GHB/GBL effects can be hard to predict and can become serious quickly."), .serious)
            }
        }

        if substanceSet.contains(.poppers) {
            if substanceSet.contains(.viagra) || substanceSet.contains(.kamagra) {
                add(
                    String(localized: "Poppers with Viagra or Kamagra can drop blood pressure sharply. Avoid this combination."),
                    .critical,
                    superseding: .poppersWithErectileMedication
                )
            } else {
                add(String(localized: "Poppers can drop blood pressure sharply, especially with Viagra, Kamagra, or similar medication."), .serious)
            }
        }

        if (hasMedicationCategory(.sedative) || hasMedicationCategory(.opioid)) &&
            (substanceSet.contains(.alcohol) || substanceSet.contains(.ketamine) || substanceSet.contains(.cannabis) || hasGHBLike) {
            add(String(localized: "Sedatives or opioids with alcohol, ketamine, cannabis, or GHB/GBL can make breathing, memory, and consent clarity worse."), .serious)
        }

        if stimulants.count >= 2 {
            // Every pairing that can trigger this line has its own table row, and
            // those name the specific two substances, so this generic summary always
            // gives way when the table speaks.
            add(
                String(localized: "Multiple stimulants can stack heart strain, anxiety, and overheating."),
                .serious,
                superseding: .stimulantStack
            )
        }

        if hasMedicationCategory(.stimulantMedication) && !stimulants.isEmpty {
            add(String(localized: "Prescribed stimulant medication with MDMA, 3MMC, or cocaine can increase stimulant overload risk."), .serious)
        }

        if hasMedicationCategory(.maoi) && !serotonergicSubstances.isEmpty {
            add(String(localized: "Certain antidepressants (MAOIs) with MDMA, 3-MMC, cocaine, or psychedelics can be dangerous. Avoid this and get professional advice."), .critical)
        } else if hasMedicationCategory(.serotonergic) && !serotonergicSubstances.isEmpty {
            add(String(localized: "Some antidepressants or mood medication can interact with MDMA, 3-MMC, cocaine, or psychedelics."), .serious)
        }

        if hasMedicationCategory(.ritonavirBooster) && (hasErectileMedication || substanceSet.contains(.mdma) || substanceSet.contains(.threeMMC)) {
            add(String(localized: "Ritonavir or cobicistat can raise levels of some substances and erectile dysfunction medication. Ask a clinician or pharmacist."), .serious)
        }

        if substanceSet.contains(.alcohol) && substanceSet.contains(.cocaine) {
            // The table entry for this pair names cocaethylene and why it matters,
            // so it supersedes this line rather than repeating it.
            add(
                String(localized: "Alcohol and cocaine together can increase strain on the heart and reduce judgment."),
                .serious,
                superseding: .alcoholWithCocaine
            )
        }

        return findings
    }
}
