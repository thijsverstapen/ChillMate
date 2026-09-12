import Foundation

// The risk engine, moved out of `CombinationRiskCheckerView.swift` where it had
// grown to more than half the file.
//
// Nothing here draws anything. It is the part of the risk checker that decides
// what a selection means — which findings it produces, at what severity, and in
// what order — and keeping it beside a 400-line SwiftUI body made it easy to
// mistake a display decision for a safety one. The tests reach for these types,
// not for the view.

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
public struct InteractionFinding: Identifiable, Hashable {
    /// Stable, language-independent identity.
    ///
    /// This used to be the finding's own localized text, which made a row's
    /// SwiftUI identity change whenever the app language did: every row was
    /// destroyed and rebuilt on a language switch, and two languages could not be
    /// compared without comparing prose. Table rows borrow
    /// `SubstanceInteraction.id` (the sorted substance names); preset lines carry
    /// the branch that produced them.
    public let id: String
    public let text: String
    /// Nil only on the "nothing matched" line, which is informational and gets no
    /// severity badge.
    public let level: SubstanceInteraction.Level?
}

/// The branches of the preset chain, as identifiers rather than sentences.
///
/// Gives each hand-written line an identity that survives translation, so
/// `InteractionFinding` never has to fall back to keying on its own text.
public enum PresetLineID: String {
    case nitratesWithErectileMedication
    case alphaBlockersWithErectileMedication
    case ghbWithDepressants
    case ghbAlone
    case poppersWithErectileMedication
    case poppersAlone
    case sedativesWithDepressants
    case multipleStimulants
    case prescribedStimulants
    case maoiWithSerotonergics
    case antidepressantsWithSerotonergics
    case ritonavirBooster
    case alcoholWithCocaine
    /// Shown when neither the preset chain nor the table matched anything.
    case nothingMatched
    /// Shown when medication was typed but matched nothing in the database, so
    /// the user knows it was not weighed rather than assuming it was safe.
    case medicationNotRecognised
    /// Three or more things that slow breathing, stacked in one session.
    case depressantLoad
}

/// Internal rather than private so the tests can assert on what the risk checker
/// screen actually produces for a selection. The interaction table used to be
/// verified in isolation, which let a green suite coexist with a screen that never
/// consulted it.
public struct CombinationAssessment {
    public let substances: [Substance]
    public let medicationText: String
    public let timing: CombinationTiming

    // Spelled out because a struct's memberwise initializer is internal, and this
    // one is built by the risk checker screen and by the tests, both of which are
    // outside the module now.
    public init(substances: [Substance], medicationText: String, timing: CombinationTiming) {
        self.substances = substances
        self.medicationText = medicationText
        self.timing = timing
    }

    private var substanceSet: Set<Substance> {
        Set(substances)
    }

    public var medicationMatches: [MedicationRiskMatch] {
        MedicationRiskDatabase.matches(in: medicationText)
    }

    public var matchedMedicationSummary: String {
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

    public var serotoninRisk: RiskLevel {
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

    public var dehydrationRisk: RiskLevel {
        let stimulantLevel: RiskLevel = stimulants.isEmpty ? .lower : (timing == .withinDay ? .caution : .high)
        let alcoholLevel: RiskLevel = substanceSet.contains(.alcohol) ? .caution : .lower
        let combinationLevel: RiskLevel = substanceSet.contains(.alcohol) && !stimulants.isEmpty ? .high : .lower
        return RiskLevel.highest(stimulantLevel, alcoholLevel, combinationLevel)
    }

    public var stimulantOverloadRisk: RiskLevel {
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
    public var respiratoryRisk: RiskLevel {
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
    public var cardiacRisk: RiskLevel {
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
    public var bloodPressureRisk: RiskLevel {
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

    public var respiratoryDetail: String {
        switch respiratoryRisk {
        case .high:
            String(localized: "More than one thing that slows breathing is selected. Signs to watch for: snoring or gurgling, slow or shallow breaths, blue lips, or someone who cannot be woken. Put them on their side and call emergency services. Do not leave them to sleep it off.", bundle: .main)
        case .caution:
            String(localized: "One thing that slows breathing is selected. Keep the dose low, leave long gaps, and stay with someone who knows what you took.", bundle: .main)
        case .lower:
            String(localized: "Nothing selected is a known breathing depressant, though amount and other medication still matter.", bundle: .main)
        }
    }

    public var cardiacDetail: String {
        switch cardiacRisk {
        case .high:
            String(localized: "This mix puts real strain on the heart, either by stacking stimulants or by swinging blood pressure up and down. Chest pain, a heart rate that will not settle, or breathlessness at rest all mean stop and get help.", bundle: .main)
        case .caution:
            String(localized: "Something selected raises heart rate or moves blood pressure. Sit down if your heart races, and give yourself long breaks.", bundle: .main)
        case .lower:
            String(localized: "No obvious pattern of heart strain is selected.", bundle: .main)
        }
    }

    public var bloodPressureDetail: String {
        switch bloodPressureRisk {
        case .high:
            String(localized: "This combination can drop blood pressure suddenly and severely. That means fainting, and at worst a stroke or cardiac arrest. Do not combine these. If someone collapses, lie them flat, raise their legs, and call emergency services.", bundle: .main)
        case .caution:
            String(localized: "Something selected widens blood vessels and lowers blood pressure. Sit or lie down before using it, and stand up slowly afterwards.", bundle: .main)
        case .lower:
            String(localized: "No obvious blood pressure drop is selected.", bundle: .main)
        }
    }

    public var serotoninDetail: String {
        switch serotoninRisk {
        case .high:
            String(localized: "You've selected a medication or substance mix that can affect serotonin, a brain chemical involved in mood and body function. Signs to watch for: confusion, fever, agitation, shaking, sweating, or diarrhea. Get help if these appear.", bundle: .main)
        case .caution:
            String(localized: "One of your selections can affect serotonin levels. Risk can increase with repeated use, heat, dehydration, or other medication.", bundle: .main)
        case .lower:
            String(localized: "No known serotonin-related combination is selected.", bundle: .main)
        }
    }

    public var dehydrationDetail: String {
        switch dehydrationRisk {
        case .high:
            String(localized: "Stimulants, alcohol, heat, dancing, and long sessions can push dehydration and overheating risk up.", bundle: .main)
        case .caution:
            String(localized: "Hydration and cooling matter, especially if sleep, food, or breaks have been limited.", bundle: .main)
        case .lower:
            String(localized: "No strong dehydration pattern is selected, but check water, food, temperature, and rest.", bundle: .main)
        }
    }

    public var stimulantDetail: String {
        switch stimulantOverloadRisk {
        case .high:
            String(localized: "More than one stimulant pattern is selected, including possible prescribed stimulant medication. Heart rate, anxiety, jaw tension, overheating, and pressure to continue can stack.", bundle: .main)
        case .caution:
            String(localized: "A stimulant is selected in the current timing window. Pause, rest, and give your body time.", bundle: .main)
        case .lower:
            String(localized: "No obvious stimulant stacking is selected.", bundle: .main)
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
    public var interactionFindings: [InteractionFinding] {
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
        var merged = (presetFindings(supersededBy: ratedTopics)
            + rated.map { InteractionFinding(id: "table.\($0.id)", text: $0.warning, level: $0.level) })
            .filter { seenText.insert($0.text).inserted }

        // Typing a medication we cannot place is not the same as typing nothing,
        // and until now both produced the same silence. Someone who misspells
        // "diazepam" gets the warnings their substances earned and no sign at all
        // that the sedative they told us about was never weighed. Say so, and say
        // it whether or not anything else matched.
        if !medicationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           medicationMatches.isEmpty {
            merged.append(
                InteractionFinding(
                    id: PresetLineID.medicationNotRecognised.rawValue,
                    text: String(localized: "The medication you entered was not recognised, so this check does not account for it. Check the spelling, or ask a pharmacist.", bundle: .main),
                    level: nil
                )
            )
        }

        guard merged.isEmpty else { return merged }

        return [
            InteractionFinding(
                id: PresetLineID.nothingMatched.rawValue,
                text: String(localized: "No known major preset warning matched. Unknown amount, contents, health conditions, and medication changes can still matter.", bundle: .main),
                level: nil
            )
        ]
    }

    /// Flat warning text in display order. `RiskCheckRecord` stores plain strings,
    /// so a saved check keeps exactly the wording the user was shown.
    public var interactionWarnings: [String] {
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

        // The table rates pairs, and a real night rarely stops at two. Alcohol with
        // GHB with ketamine produced three separate pair warnings and nothing
        // anywhere saying the depressant load compounds, which is the mechanism
        // behind most fatal outcomes involving these substances. `respiratoryRisk`
        // has counted the load since 4.2.1; until now nothing said it out loud.
        //
        // Stated first because it describes the whole selection rather than one
        // pairing, and it is never superseded: no table row can cover it, because
        // no table row looks at more than two things at once.
        let depressantLoad = depressants.count + depressantMedicationCount
        if depressantLoad >= 3 {
            findings.append(
                InteractionFinding(
                    id: PresetLineID.depressantLoad.rawValue,
                    text: String(localized: "Three or more things here slow breathing. Stacked in one session they multiply rather than add, and this is the pattern behind most overdoses involving these substances. Do not use alone, and stagger or drop one.", bundle: .main),
                    level: .critical
                )
            )
        }

        func add(_ id: PresetLineID, _ text: String, _ level: SubstanceInteraction.Level, superseding topic: HazardTopic? = nil) {
            if let topic, let rated = ratedTopics[topic], rated >= level { return }
            findings.append(InteractionFinding(id: id.rawValue, text: text, level: level))
        }

        if hasMedicationCategory(.nitrateLike) && (hasErectileMedication || substanceSet.contains(.poppers)) {
            add(.nitratesWithErectileMedication, String(localized: "Nitrates, nicorandil, or riociguat with Viagra, Kamagra, or poppers can cause a severe blood pressure drop. Do not combine.", bundle: .main), .critical)
        }

        if hasMedicationCategory(.alphaBlocker) && hasErectileMedication {
            add(.alphaBlockersWithErectileMedication, String(localized: "Alpha blockers with Viagra or Kamagra can increase dizziness or fainting risk. Check with a clinician before combining.", bundle: .main), .serious)
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
                    .ghbWithDepressants,
                    String(localized: "GHB/GBL with alcohol, ketamine, sedatives, or opioids can cause unconsciousness or breathing problems.", bundle: .main),
                    .critical,
                    superseding: sedatingMedication ? nil : .ghbDepressantStack
                )
            } else {
                add(.ghbAlone, String(localized: "GHB/GBL effects can be hard to predict and can become serious quickly.", bundle: .main), .serious)
            }
        }

        if substanceSet.contains(.poppers) {
            if substanceSet.contains(.viagra) || substanceSet.contains(.kamagra) {
                add(
                    .poppersWithErectileMedication,
                    String(localized: "Poppers with Viagra or Kamagra can drop blood pressure sharply. Avoid this combination.", bundle: .main),
                    .critical,
                    superseding: .poppersWithErectileMedication
                )
            } else {
                add(.poppersAlone, String(localized: "Poppers can drop blood pressure sharply, especially with Viagra, Kamagra, or similar medication.", bundle: .main), .serious)
            }
        }

        if (hasMedicationCategory(.sedative) || hasMedicationCategory(.opioid)) &&
            (substanceSet.contains(.alcohol) || substanceSet.contains(.ketamine) || substanceSet.contains(.cannabis) || hasGHBLike) {
            add(.sedativesWithDepressants, String(localized: "Sedatives or opioids with alcohol, ketamine, cannabis, or GHB/GBL can make breathing, memory, and consent clarity worse.", bundle: .main), .serious)
        }

        if stimulants.count >= 2 {
            // Every pairing that can trigger this line has its own table row, and
            // those name the specific two substances, so this generic summary always
            // gives way when the table speaks.
            add(
                .multipleStimulants,
                String(localized: "Multiple stimulants can stack heart strain, anxiety, and overheating.", bundle: .main),
                .serious,
                superseding: .stimulantStack
            )
        }

        if hasMedicationCategory(.stimulantMedication) && !stimulants.isEmpty {
            add(.prescribedStimulants, String(localized: "Prescribed stimulant medication with MDMA, 3MMC, or cocaine can increase stimulant overload risk.", bundle: .main), .serious)
        }

        if hasMedicationCategory(.maoi) && !serotonergicSubstances.isEmpty {
            add(.maoiWithSerotonergics, String(localized: "Certain antidepressants (MAOIs) with MDMA, 3-MMC, cocaine, or psychedelics can be dangerous. Avoid this and get professional advice.", bundle: .main), .critical)
        } else if hasMedicationCategory(.serotonergic) && !serotonergicSubstances.isEmpty {
            add(.antidepressantsWithSerotonergics, String(localized: "Some antidepressants or mood medication can interact with MDMA, 3-MMC, cocaine, or psychedelics.", bundle: .main), .serious)
        }

        if hasMedicationCategory(.ritonavirBooster) && (hasErectileMedication || substanceSet.contains(.mdma) || substanceSet.contains(.threeMMC)) {
            add(.ritonavirBooster, String(localized: "Ritonavir or cobicistat can raise levels of some substances and erectile dysfunction medication. Ask a clinician or pharmacist.", bundle: .main), .serious)
        }

        if substanceSet.contains(.alcohol) && substanceSet.contains(.cocaine) {
            // The table entry for this pair names cocaethylene and why it matters,
            // so it supersedes this line rather than repeating it.
            add(
                .alcoholWithCocaine,
                String(localized: "Alcohol and cocaine together can increase strain on the heart and reduce judgment.", bundle: .main),
                .serious,
                superseding: .alcoholWithCocaine
            )
        }

        return findings
    }
}

/// A hazard both warning sources can describe, used to keep the merged list from
/// saying the same thing twice in two different voices.
///
/// Only the preset lines a curated table entry can genuinely stand in for are
/// classified. Anything unclassified on either side is always kept, so a table row
/// added later can never silently swallow a preset warning.
public enum HazardTopic: Hashable {
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
    public init?(_ substances: Set<Substance>) {
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

extension RiskLevel {
    public var severity: Int {
        switch self {
        case .lower:
            0
        case .caution:
            1
        case .high:
            2
        }
    }

    public static func highest(_ levels: RiskLevel...) -> RiskLevel {
        levels.max { $0.severity < $1.severity } ?? .lower
    }
}
