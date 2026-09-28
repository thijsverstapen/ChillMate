import Foundation
import Testing
import ChillMateCore
@testable import ChillMate

/// Names that are stored in English and have to be shown in the reader's language.
///
/// Both of these shipped English into every language: a timer named its
/// substance by the raw value on the Lock Screen, the watch and the timer card,
/// and Recently deleted showed each item's kind exactly as it was stored.
@Suite("Stored names, shown translated")
struct LocalizedNamesTests {

    /// The raw values are what every item already on somebody's phone was saved
    /// under. Changing one would leave those items without a kind.
    @Test("Recently deleted still reads the kinds the store always wrote")
    func storedKindsUnchanged() {
        #expect(RecentlyDeletedKind.allCases.map(\.rawValue) == ["Chill log", "Risk check", "Timer", "STI test", "Plan"])
    }

    @Test("A kind stored in English is shown in the reader's language", arguments: RecentlyDeletedKind.allCases)
    func storedKindIsTranslated(kind: RecentlyDeletedKind) {
        let item = RecentlyDeletedItem(kind: kind.rawValue, title: "", detail: "", deletedAt: .now)
        #expect(item.localizedKind == kind.localizedName)
    }

    /// Nothing is lost for a kind this build does not know: it is shown as stored.
    @Test("An unknown kind is shown as it was stored")
    func unknownKindShownAsStored() {
        let item = RecentlyDeletedItem(kind: "Something newer", title: "", detail: "", deletedAt: .now)
        #expect(item.localizedKind == "Something newer")
    }

    @Test("A timer names its substance in the reader's language", arguments: [Substance.ketamine, .cocaine, .alcohol, .methamphetamine])
    func timerNameIsTranslated(substance: Substance) {
        let timer = DrugDoseTimerRecord(substanceName: substance.rawValue, startedAt: .now, durationHours: 2)
        #expect(timer.localizedSubstanceName == substance.localizedDisplayName)
    }

    /// Lookups still need the raw value, so it has to stay as it was stored.
    @Test("The stored raw value is left alone")
    func rawValueKept() {
        let timer = DrugDoseTimerRecord(substanceName: Substance.ketamine.rawValue, startedAt: .now, durationHours: 2)
        #expect(timer.substanceName == Substance.ketamine.rawValue)
        #expect(Substance(rawValue: timer.substanceName) == .ketamine)
    }

    @Test("A name that is not a known substance is shown as stored")
    func unknownSubstanceShownAsStored() {
        let timer = DrugDoseTimerRecord(substanceName: "Something else", startedAt: .now, durationHours: 2)
        #expect(timer.localizedSubstanceName == "Something else")
    }
}
