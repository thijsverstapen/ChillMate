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
    @State private var substanceSearch = ""
    @State private var isShowingDiscardWarning = false

    /// The grid's contents: everything selectable that answers to the search, plus
    /// anything already selected so a filter cannot hide a choice you have made.
    private var matchingSubstances: [Substance] {
        let selectable = Substance.allCases.filter { $0 != .unknown && $0 != .other }
        guard !substanceSearch.trimmingCharacters(in: .whitespaces).isEmpty else { return selectable }
        return selectable.filter { $0.matches(substanceSearch) || selectedSubstances.contains($0) }
    }

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

                // Fourteen chips is enough to scan past what you are looking for,
                // and two of them arrived in 5.0.0. The field matches street names
                // as well as display names, because "ket" and "G" are what people
                // type — see `Substance.aliases`.
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.chillSecondary)
                        .accessibilityHidden(true)

                    TextField("Search substances", text: $substanceSearch)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(Color.chillText)

                    if !substanceSearch.isEmpty {
                        Button {
                            substanceSearch = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.chillSecondary)
                        }
                        .buttonStyle(ChillPlainButtonStyle())
                        .accessibilityLabel(String(localized: "Clear search"))
                        .accessibilityInputLabels([String(localized: "Clear")])
                    }
                }
                .padding(12)
                .glassSurface(radius: 16, tint: .black.opacity(0.04), interactive: true)

                if matchingSubstances.isEmpty {
                    Text("Nothing matches that. It may still be worth checking the two you do know.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10)], spacing: 10) {
                    ForEach(matchingSubstances) { substance in
                        Button {
                            toggle(substance)
                        } label: {
                            Label(substance.localizedDisplayName, systemImage: substance.symbolName)
                                .font(.caption.weight(.bold))
                                .chillLineLimit(1, scale: 0.75)
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

            SelectedSubstanceTimingCard(substances: selectedSubstances)

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

    /// The night entry this check belongs to, if one has been logged for today.
    ///
    /// Matched on the calendar day, which is the same rule the rest of the app
    /// uses to decide whether tonight is already logged. A check run before the
    /// night is logged finds nothing and stays unlinked — the history screen picks
    /// those up by date instead.
    private func tonightsEntryID() -> UUID? {
        var descriptor = FetchDescriptor<NightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 40
        let recent = (try? modelContext.fetch(descriptor)) ?? []
        return recent.first { Calendar.current.isDate($0.date, inSameDayAs: .now) }?.id
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
            warnings: assessment.interactionWarnings,
            nightEntryID: tonightsEntryID()
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

    /// The worst rating anything in this assessment carries.
    ///
    /// Used only to fire a haptic when it changes. Severity was carried entirely
    /// by the colour of a capsule, which is no use in a dark room, at arm's
    /// length, to anyone colour-blind, or to someone who is not looking at the
    /// screen because they are looking at their friend. A distinct knock when the
    /// answer turns critical reaches all four.
    private var highestLevel: SubstanceInteraction.Level? {
        assessment.interactionFindings.compactMap(\.level).max()
    }

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
        .sensoryFeedback(trigger: highestLevel) { _, level in
            switch level {
            case .critical: .warning
            case .serious: .impact(weight: .medium)
            default: nil
            }
        }
    }
}

private struct RiskLevelRow: View {
    let title: String
    let level: RiskLevel
    let detail: String

    /// The badge was pinned to 72 points wide. "High-risk combination" does not
    /// fit 72 points at the accessibility text sizes, and a fixed frame does not
    /// grow, so the rating — the most important word in the row — was the first
    /// thing to be clipped for the people who most need to read it.
    ///
    /// Width is now a floor rather than a ceiling, and past the accessibility
    /// threshold the row stops being a row: the badge sits above the text instead
    /// of squeezing it into a sliver of the screen.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var badge: some View {
        Label(level.label, systemImage: level.symbol)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minWidth: 72)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Capsule().fill(level.tint))
    }

    private var text: some View {
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

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    badge
                    text
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    badge
                    text
                }
            }
        }
        // One element, stating the rating before the thing it rates. Read as three
        // separate fragments, a swipe landed on a bare "Significant risk" with no
        // way back to which risk it belonged to.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title): \(level.label). \(detail)"))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassSurface(radius: 20, tint: level.tint.opacity(0.08))
    }
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
        // The badge and the sentence were two elements, so VoiceOver read the
        // severity as a stray phrase before an unrelated warning, and swiping
        // through a long list lost track of which rating belonged to which line.
        // Combining them states the rating and the warning as one thing, which is
        // also the only way the severity reaches anyone who cannot see the colour
        // of the capsule.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        guard let level = finding.level else { return finding.text }
        return "\(level.label): \(finding.text)"
    }
}




/// When each selected substance comes up, peaks and finishes.
///
/// The figures were already in `SubstanceReference`, but only on the drug
/// information page — a screen you go to when you are curious, not the one you
/// open when you are deciding something. This is the screen where the decision
/// gets made, so the timing belongs here too.
///
/// It leads on the onset window because that is where the harm is. The common
/// sequence behind an overdose is not misreading a dose, it is taking a second
/// one before the first has arrived — which is why the onset row is the one with
/// the sentence attached and the others are bare numbers.
struct SelectedSubstanceTimingCard: View {
    let substances: Set<Substance>

    /// One entry per substance per route, so a substance whose routes behave
    /// differently shows both rather than one standing in for the other.
    private var timed: [(substance: Substance, timing: SubstanceReference.Timing)] {
        substances
            .sorted { $0.rawValue < $1.rawValue }
            .flatMap { substance in
                (substance.reference?.timings ?? []).map { (substance, $0) }
            }
    }

    var body: some View {
        if !timed.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                CareSectionTitle(title: String(localized: "Timing"), symbol: "clock.badge.exclamationmark.fill")

                Text("Most overdoses are a second dose taken before the first arrived. Give it the onset time before you decide anything.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillText)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(timed.enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(
                            entry.timing.route.map { "\(entry.substance.localizedDisplayName) — \($0.label)" }
                                ?? entry.substance.localizedDisplayName,
                            systemImage: entry.substance.symbolName
                        )
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.chillText)

                        HStack(alignment: .top, spacing: 10) {
                            TimingFigure(label: String(localized: "Comes up"), value: entry.timing.onsetText, isLead: true)
                            TimingFigure(label: String(localized: "Peaks"), value: entry.timing.peakText, isLead: false)
                            TimingFigure(label: String(localized: "Lasts"), value: entry.timing.totalText, isLead: false)
                        }

                        // Planning a night around "lasts" alone is how a Saturday
                        // costs a Tuesday. The after-effects window is the figure
                        // that makes the rest of the week legible.
                        if let after = entry.timing.afterEffectsText {
                            Text("After effects reported for another \(after) once it is over.")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.chillSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let redose = entry.substance.reference?.redoseGuidance {
                            Text(redose)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.chillSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(entry.substance.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityElement(children: .combine)
                }

                Text("Figures are commonly reported ranges, not a promise. Anything taken on a full stomach, snorted rather than swallowed, or of unknown strength will not follow them.")
                    .font(.caption2)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08))
        }
    }
}

private struct TimingFigure: View {
    let label: String
    let value: String
    /// The onset column, which is the one that matters and is drawn to say so.
    let isLead: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
            Text(value)
                .font(isLead ? .subheadline.weight(.heavy) : .caption.weight(.bold))
                .foregroundStyle(isLead ? Color.chillText : Color.chillText.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}
