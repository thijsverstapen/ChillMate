import Foundation
import SwiftData
import SwiftUI

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
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: saveRiskCheck) {
                        Text("Save").font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(Color.chillPrimary)
                }
            }
            .endEditingOnTap()
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
