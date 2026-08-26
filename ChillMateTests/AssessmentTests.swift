import Testing
@testable import ChillMate

/// The three assessments added in 4.3.0. The existing three (serotonin,
/// dehydration, stimulant overload) had no direct coverage either; these are the
/// hazards most likely to matter, so they get it.
struct AssessmentTests {
    private func check(
        _ substances: Set<Substance>,
        medication: String = "",
        timing: CombinationTiming = .sameSession
    ) -> CombinationAssessment {
        CombinationAssessment(
            substances: Array(substances),
            medicationText: medication,
            timing: timing
        )
    }

    // MARK: Breathing

    @Test("Stacked depressants read as high respiratory risk")
    func stackedDepressantsAreHigh() {
        #expect(check([.ghb, .alcohol]).respiratoryRisk == .high)
        #expect(check([.alcohol, .ketamine]).respiratoryRisk == .high)
        #expect(check([.gbl, .ketamine]).respiratoryRisk == .high)
    }

    @Test("A prescribed sedative counts as another depressant")
    func sedativeMedicationCounts() {
        // One substance alone would only be .caution; the medication is what
        // makes it a stack, and that is the whole point of folding it in.
        #expect(check([.alcohol], medication: "diazepam").respiratoryRisk == .high)
    }

    @Test("GHB alone still warns, because its margin is narrow")
    func ghbAloneWarns() {
        #expect(check([.ghb]).respiratoryRisk == .caution)
    }

    @Test("Nothing sedating reads as lower")
    func noDepressantIsLower() {
        #expect(check([.cocaine, .mdma]).respiratoryRisk == .lower)
    }

    // MARK: Heart

    @Test("A stimulant with poppers is high cardiac risk")
    func stimulantWithPoppersIsHigh() {
        #expect(check([.mdma, .poppers]).cardiacRisk == .high)
        #expect(check([.cocaine, .poppers]).cardiacRisk == .high)
    }

    @Test("Two stimulants are high cardiac risk")
    func stackedStimulantsAreHigh() {
        #expect(check([.cocaine, .mdma]).cardiacRisk == .high)
    }

    @Test("No stimulant and no vasodilator reads as lower")
    func calmSelectionIsLower() {
        #expect(check([.cannabis]).cardiacRisk == .lower)
    }

    // MARK: Blood pressure

    @Test("Poppers with erection medication is the critical pair", .tags(.safety))
    func poppersWithErectileMedicationIsHigh() {
        #expect(check([.poppers, .viagra]).bloodPressureRisk == .high)
        #expect(check([.poppers, .kamagra]).bloodPressureRisk == .high)
    }

    @Test("Nitrates reach the same hazard through medication", .tags(.safety))
    func nitratesAreCaught() {
        #expect(check([.poppers], medication: "isosorbide mononitrate").bloodPressureRisk == .high)
    }

    @Test("Poppers alone still warns")
    func poppersAloneWarns() {
        #expect(check([.poppers]).bloodPressureRisk == .caution)
    }

    @Test("Nothing that drops pressure reads as lower")
    func noVasodilatorIsLower() {
        #expect(check([.mdma]).bloodPressureRisk == .lower)
    }
}
