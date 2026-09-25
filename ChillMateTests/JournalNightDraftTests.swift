import Foundation
import Testing
@testable import ChillMate

/// The guards around what a language model hands back.
///
/// The model itself is not exercised here: it is unavailable in the simulator,
/// and a test that only runs on some machines is a test that stops running. What
/// is tested is everything between the model and the user — the range check, the
/// contradiction fix, and the rule that an empty draft is offered to nobody.
/// Those are what stand between a hallucinated number and a harm-reduction log.
@Suite("Journal night draft")
struct JournalNightDraftTests {

    @Test("A sleep figure no night could hold is dropped", arguments: [-1.0, 16.5, 24.0, 100.0])
    func implausibleSleepIsDropped(hours: Double) {
        let draft = JournalNightDraft(sleepHours: hours, slept: nil, memoryGap: nil).validated()
        #expect(draft.sleepHours == nil, "\(hours) survived the range check")
    }

    @Test("A plausible figure is kept", arguments: [0.0, 0.5, 6.0, 9.5, 16.0])
    func plausibleSleepSurvives(hours: Double) {
        let draft = JournalNightDraft(sleepHours: hours, slept: nil, memoryGap: nil).validated()
        #expect(draft.sleepHours == hours)
    }

    /// Hours slept while "has not slept" is a contradiction the model can produce
    /// from one sentence. The hours are the more specific claim, so the flag
    /// follows them rather than the pair reaching the user disagreeing.
    @Test("Hours and 'has not slept' cannot both be offered")
    func contradictionIsResolved() {
        let draft = JournalNightDraft(sleepHours: 7, slept: false, memoryGap: nil).validated()
        #expect(draft.sleepHours == 7)
        #expect(draft.slept == true)
    }

    /// A dropped figure must not drag the flag with it: the contradiction fix
    /// only applies while there are hours to believe.
    @Test("Dropping the hours leaves the flag alone")
    func droppedHoursDoNotFlipTheFlag() {
        let draft = JournalNightDraft(sleepHours: 99, slept: false, memoryGap: nil).validated()
        #expect(draft.sleepHours == nil)
        #expect(draft.slept == false)
    }

    @Test("An empty draft has nothing to offer")
    func emptyDraftOffersNothing() {
        #expect(JournalNightDraft(sleepHours: nil, slept: nil, memoryGap: nil).hasAnything == false)
    }

    @Test("Any one field is enough to offer")
    func anySingleFieldIsEnough() {
        #expect(JournalNightDraft(sleepHours: 6, slept: nil, memoryGap: nil).hasAnything)
        #expect(JournalNightDraft(sleepHours: nil, slept: true, memoryGap: nil).hasAnything)
        #expect(JournalNightDraft(sleepHours: nil, slept: nil, memoryGap: true).hasAnything)
    }

    /// Text too short to describe a night is not sent to the model at all, so a
    /// two-word entry cannot produce a draft to confirm.
    @Test("Short text produces no draft", arguments: ["", "ok", "good night out"])
    func shortTextIsNotDrafted(text: String) async {
        #expect(await OnDeviceAffirmationService.draftNight(from: text) == nil)
    }

    /// Substances are not in the draft's shape at all. Spelled as a test because
    /// the reason is a product rule, not an oversight: a model reading prose can
    /// name a substance nobody wrote, and that name would reach the risk checker,
    /// the insights and a summary somebody hands a clinician.
    @Test("The draft has no place to put a substance")
    func draftCarriesNoSubstances() {
        let mirror = Mirror(reflecting: JournalNightDraft(sleepHours: 6, slept: true, memoryGap: false))
        let names = mirror.children.compactMap(\.label).sorted()
        #expect(names == ["memoryGap", "sleepHours", "slept"],
                "the draft grew a field: \(names)")
    }
}
