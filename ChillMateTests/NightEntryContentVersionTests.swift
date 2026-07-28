import Foundation
import Testing
@testable import ChillMate

/// `contentVersion` is what lets the dashboard notice an entry was *edited* rather
/// than added or removed. Before it existed the metrics cache keyed on
/// `entries.count`, so editing a night left the count unchanged and the dashboard
/// kept showing the pre-edit daily score, streak and PEP countdown — and pushed
/// those stale figures to the widget and the watch.
struct NightEntryContentVersionTests {

    private func entry(substances: [String] = []) -> NightEntry {
        NightEntry(date: .now, hadSex: false, skippedNight: false, substances: substances)
    }

    @Test("Editing substances bumps the content version")
    func substancesBumpVersion() {
        let entry = entry()
        let before = entry.contentVersion
        entry.substances = ["MDMA"]
        #expect(entry.contentVersion > before)
    }

    @Test("Every content setter bumps the version")
    func allSettersBump() {
        let checks: [(String, (NightEntry) -> Void)] = [
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

        for (name, mutate) in checks {
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
        // The setter cannot cheaply tell "same value" from "changed", and treating
        // a no-op write as a change only costs one extra recompute. Missing a real
        // change is what actually breaks the dashboard.
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
        _ = subject.sleepSummary
        _ = subject.saferSexSummary
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
