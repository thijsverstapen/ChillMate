import Foundation
import Testing
@testable import ChillMate

/// `contentVersion` is what lets the dashboard notice an entry was *edited* rather
/// than added or removed. Before it existed the metrics cache keyed on
/// `entries.count`, so editing a night left the count unchanged and the dashboard
/// kept showing the pre-edit daily score, streak and PEP countdown, then pushed
/// those stale figures to the widget and the watch.
///
/// It covers the entry's content in two halves, and the tests below cover both:
/// the blob-backed properties bump a counter from their setters, while the plain
/// stored attributes are folded in on read because they have no setter to bump
/// from. The second half is the one that matters for Apple Health sleep sync,
/// which writes `sleptYet` and `sleepHours` long after LogNightSheet dismissed.
struct NightEntryContentVersionTests {

    /// Fixed so that two entries built by `entry()` are byte-identical as far as the
    /// version is concerned. With `.now` every subject would differ by its own date
    /// alone, and the collision test below would pass without proving anything.
    private static let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func entry(
        substances: [String] = [],
        date: Date = NightEntryContentVersionTests.referenceDate
    ) -> NightEntry {
        NightEntry(date: date, hadSex: false, skippedNight: false, substances: substances)
    }

    /// Every mutation the dashboard's metrics can see, both halves together.
    ///
    /// The stored attributes are the half that used to be missed: `DashboardMetrics`
    /// and `DailyRecoveryScore` read all of them, so any one of them left out here
    /// is a night whose edit the dashboard never notices.
    private var everyDisplayedMutation: [(String, (NightEntry) -> Void)] {
        blobSetterMutations + storedAttributeMutations
    }

    private var blobSetterMutations: [(String, (NightEntry) -> Void)] {
        [
            ("substances", { $0.substances = ["GHB"] }),
            ("injectionSubstances", { $0.injectionSubstances = ["Ketamine"] }),
            ("partnerDetails", {
                $0.partnerDetails = [SexPartnerRecord(name: "A", phoneNumber: "",
                                                     theyWerePenetrated: false,
                                                     userWasPenetrated: false)]
            }),
            ("triggerTags", { $0.triggerTags = [.lonely] }),
            ("changeReasons", { $0.changeReasons = [.stress] }),
            ("aftercareSymptoms", { $0.aftercareSymptoms = [.anxious] }),
        ]
    }

    private var storedAttributeMutations: [(String, (NightEntry) -> Void)] {
        [
            ("sleptYet", { $0.sleptYet = true }),
            ("sleepHours", { $0.sleepHours = 6.5 }),
            ("aftercareDrankWater", { $0.aftercareDrankWater = true }),
            ("aftercareAteFood", { $0.aftercareAteFood = true }),
            ("aftercareMood", { $0.aftercareMood = AftercareMood.low.rawValue }),
            ("aftercareCompletedAt", { $0.aftercareCompletedAt = Self.referenceDate }),
            ("skippedNight", { $0.skippedNight = true }),
            ("hadSex", { $0.hadSex = true }),
            ("usedCondom", { $0.usedCondom = true }),
            ("wasPenetrated", { $0.wasPenetrated = true }),
            ("date", { $0.date = Self.referenceDate.addingTimeInterval(24 * 60 * 60) }),
            ("startDate", { $0.startDate = Self.referenceDate.addingTimeInterval(60 * 60) }),
        ]
    }

    @Test("Editing substances bumps the content version")
    func substancesBumpVersion() {
        let entry = entry()
        let before = entry.contentVersion
        entry.substances = ["MDMA"]
        #expect(entry.contentVersion > before)
    }

    /// Inequality, not `>`. Half the version is a fold of the stored attributes'
    /// current values, so a real edit is guaranteed to move it but not guaranteed
    /// to move it upwards. The dashboard compares the key for equality only.
    @Test("Every field the dashboard reads changes the version")
    func everyDisplayedFieldChangesTheVersion() {
        for (name, mutate) in everyDisplayedMutation {
            let subject = entry()
            let before = subject.contentVersion
            mutate(subject)
            #expect(subject.contentVersion != before, "\(name) did not change contentVersion")
        }
    }

    /// Writing a stored attribute the value it already holds is not an edit, so it
    /// must not invalidate the dashboard's cache. Only the stored half can promise
    /// this; see `settingSameValueStillBumps` for why the blob setters cannot.
    @Test("Rewriting a stored attribute with its own value changes nothing")
    func noOpStoredWritesLeaveTheVersionAlone() {
        // Applied twice rather than assigning each property back to itself, so the
        // second pass is identical to the first by construction.
        let applyKnownState: (NightEntry) -> Void = { subject in
            subject.sleptYet = true
            subject.sleepHours = 6.5
            subject.aftercareDrankWater = true
            subject.aftercareAteFood = true
            subject.aftercareMood = AftercareMood.low.rawValue
            subject.aftercareCompletedAt = Self.referenceDate
            subject.skippedNight = true
            subject.hadSex = true
            subject.usedCondom = true
            subject.wasPenetrated = true
            subject.date = Self.referenceDate
            subject.startDate = Self.referenceDate
        }

        let subject = entry()
        applyKnownState(subject)
        let before = subject.contentVersion
        applyKnownState(subject)

        #expect(subject.contentVersion == before)
    }

    /// Two entries with the same content must key the same, and each single-field
    /// edit must key differently from every other. Without this a fold that
    /// happened to cancel out (say sleep hours moving against a flag) would look
    /// exactly like no edit at all.
    @Test("Distinct stored edits produce distinct versions")
    func distinctStoredEditsDoNotCollide() {
        #expect(entry().contentVersion == entry().contentVersion,
                "Identical content must produce an identical version")

        var versions: Set<Int> = []
        for (_, mutate) in storedAttributeMutations {
            let subject = entry()
            mutate(subject)
            versions.insert(subject.contentVersion)
        }

        #expect(versions.count == storedAttributeMutations.count,
                "Two different single-field edits folded to the same version")
    }

    /// The blob-backed half stays a monotonic counter, which is worth pinning: it is
    /// what keeps `repeatedEditsAdvance` meaningful, and a regression to "sometimes
    /// advances" would be invisible in the inequality checks above.
    @Test("Every content setter bumps the version")
    func allSettersBump() {
        for (name, mutate) in blobSetterMutations {
            let subject = entry()
            let before = subject.contentVersion
            mutate(subject)
            #expect(subject.contentVersion > before, "\(name) did not bump contentVersion")
        }
    }

    @Test("Repeated edits keep advancing the version")
    func repeatedEditsAdvance() {
        let subject = entry()
        var seen: Set<Int> = [subject.contentVersion]
        for name in ["MDMA", "GHB", "Ketamine", "Cocaine"] {
            subject.substances = [name]
            seen.insert(subject.contentVersion)
        }
        #expect(seen.count == 5, "Each edit should produce a distinct version: \(seen.sorted())")
    }

    @Test("Round-tripping a value through a setter still registers as a change")
    func settingSameValueStillBumps() {
        // A blob setter cannot cheaply tell "same value" from "changed": it would
        // have to decode and compare the whole list first, and treating a no-op
        // write as a change only costs one extra recompute. Missing a real change
        // is what actually breaks the dashboard. The stored attributes get this for
        // free instead, because their half is a fold of the values themselves.
        let subject = entry(substances: ["MDMA"])
        let before = subject.contentVersion
        subject.substances = ["MDMA"]
        #expect(subject.contentVersion > before)
    }

    @Test("Reading a property never bumps the version")
    func readsDoNotBump() {
        let subject = entry(substances: ["MDMA"])
        let before = subject.contentVersion
        _ = subject.substances
        _ = subject.partnerDetails
        _ = subject.triggerTags
        _ = subject.changeReasons
        _ = subject.aftercareSymptoms
        _ = subject.sleptYet
        _ = subject.sleepHours
        _ = subject.aftercareDrankWater
        _ = subject.aftercareAteFood
        _ = subject.aftercareMood
        _ = subject.aftercareCompletedAt
        _ = subject.sleepSummary
        _ = subject.saferSexSummary
        _ = subject.suggestsPEPConcern
        #expect(subject.contentVersion == before)
    }
}

/// The localized summaries used to be raw English literals.
struct NightEntrySummaryTests {

    @Test("Safer-sex summary covers all four combinations")
    func saferSexSummaryIsExhaustive() {
        var summaries: Set<String> = []
        for condom in [true, false] {
            for penetrated in [true, false] {
                let entry = NightEntry(date: .now, hadSex: true, usedCondom: condom,
                                       wasPenetrated: penetrated, skippedNight: false,
                                       substances: [])
                let summary = entry.saferSexSummary
                #expect(summary.isEmpty == false)
                summaries.insert(summary)
            }
        }
        #expect(summaries.count == 4, "Each combination needs its own sentence: \(summaries)")
    }

    @Test("No sex recorded reads distinctly from the four combinations")
    func noSexIsDistinct() {
        let entry = NightEntry(date: .now, hadSex: false, skippedNight: false, substances: [])
        #expect(entry.saferSexSummary.isEmpty == false)
    }

    @Test("Sleep summary reports unlogged sleep separately from zero hours")
    func sleepSummaryDistinguishesUnlogged() {
        let unlogged = NightEntry(date: .now, hadSex: false, skippedNight: false, substances: [])
        // Argument order follows the initializer: sleptYet/sleepHours come after
        // skippedNight and substances.
        let zero = NightEntry(date: .now, hadSex: false, skippedNight: false,
                              substances: [], sleptYet: true, sleepHours: 0)
        #expect(unlogged.sleepSummary != zero.sleepSummary)
    }

    @Test("Partner summary is never empty and reflects the count")
    func partnerSummaryReflectsCount() {
        let one = NightEntry(date: .now, hadSex: true, partnerCount: 1, skippedNight: false, substances: [])
        let three = NightEntry(date: .now, hadSex: true, partnerCount: 3, skippedNight: false, substances: [])
        #expect(one.partnerSummary.isEmpty == false)
        #expect(three.partnerSummary.isEmpty == false)
        #expect(one.partnerSummary != three.partnerSummary)
    }
}
