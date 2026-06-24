import Foundation
import Testing
@testable import ChillMate

struct NightEntryLogicTests {

    @Test("No-condom sex flags a PEP concern, with a 72-hour deadline", .tags(.safety))
    func pepConcernWindow() {
        let entry = NightEntry(date: .now, hadSex: true, usedCondom: false, skippedNight: false, substances: [])
        #expect(entry.suggestsPEPConcern)
        #expect(entry.isTrackedEvent)
        #expect(abs(entry.pepDeadline.timeIntervalSince(entry.startDate) - 72 * 60 * 60) < 1e-6)
    }

    @Test("A skipped night is never a tracked event or a PEP concern", .tags(.safety))
    func skippedNightIsInert() {
        let entry = NightEntry(date: .now, hadSex: true, usedCondom: false, skippedNight: true, substances: [])
        #expect(entry.isTrackedEvent == false)
        #expect(entry.suggestsPEPConcern == false)
    }

    @Test("Protected, non-penetrative sex does not raise a PEP concern", .tags(.safety))
    func protectedSexNoConcern() {
        let entry = NightEntry(date: .now, hadSex: true, usedCondom: true,
                               wasPenetrated: false, skippedNight: false, substances: [])
        #expect(entry.suggestsPEPConcern == false)
    }
}

struct DrugTimerTests {

    @Test("Effect progress runs 0 to 1 across the dose window, clamped at the ends")
    func effectProgressBounds() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let timer = DrugDoseTimerRecord(substanceName: Substance.mdma.rawValue, startedAt: start, durationHours: 2)
        #expect(abs(timer.effectProgress(at: start) - 0) < 1e-9)
        #expect(abs(timer.effectProgress(at: start.addingTimeInterval(3600)) - 0.5) < 1e-9)
        #expect(abs(timer.effectProgress(at: timer.endsAt) - 1) < 1e-9)
        #expect(abs(timer.effectProgress(at: start.addingTimeInterval(10 * 3600)) - 1) < 1e-9)
    }

    @Test("Redose nudge is active in the back half of the window but not after it ends")
    func redoseNudgeWindow() {
        let start = Date(timeIntervalSince1970: 2_000_000)
        let timer = DrugDoseTimerRecord(substanceName: Substance.mdma.rawValue, startedAt: start, durationHours: 2)
        #expect(timer.redoseNudgeIsActive(at: start) == false)                                  // progress 0
        #expect(timer.redoseNudgeIsActive(at: start.addingTimeInterval(3600)))                   // progress 0.5
        #expect(timer.redoseNudgeIsActive(at: timer.endsAt.addingTimeInterval(60)) == false)     // already ended
    }
}

struct SaferSessionPlanTests {

    @Test("Completed count tallies only the checklist booleans that are true")
    func completedCountTally() {
        #expect(SaferSessionPlan().completedCount == 0)
        let plan = SaferSessionPlan(sleepChecked: true, hydrationChecked: true, transportPlanned: true)
        #expect(plan.completedCount == 3)
    }
}

struct STDTestRecordTests {

    @Test("A positive in any site marks the record positive; results are due after 7 days", .tags(.safety))
    func positiveDetectionAndDueDate() {
        let test = STDTestRecord(testDate: Date(timeIntervalSince1970: 0), genitalResult: .positive)
        #expect(test.hasPositiveResult)
        #expect(abs(test.resultsDueDate.timeIntervalSince(test.testDate) - 7 * 24 * 60 * 60) < 1e-6)
    }

    @Test("All-negative results are not flagged positive")
    func negativeNotFlagged() {
        let test = STDTestRecord(testDate: .now, oralResult: .negative, genitalResult: .negative, analResult: .negative)
        #expect(test.hasPositiveResult == false)
    }
}

struct SleepMoodTests {

    // Pairwise (zipped), not a Cartesian product, so hours line up with their emoji.
    @Test("Sleep emoji reflects the hours slept",
          arguments: zip([7.0, 5.0, 3.0, 1.0], ["😊", "🙂", "🙁", "😢"]))
    func sleepEmojiThresholds(hours: Double, emoji: String) {
        #expect(SleepMood(hours: hours).emoji == emoji)
    }
}
