import Foundation
import SwiftData
import Testing
@testable import ChillMate

/// `hasSubstances` answers the question `substances.isEmpty == false` answers,
/// without sorting, deduping and mapping a relationship to get there.
///
/// Seventeen call sites were changed to use it, several of them inside filters
/// that run over every logged night, so the two have to agree in every shape a
/// row can take: typed records, a row old enough to still be carrying only a
/// blob, injections counted separately from everything else, and empty.
/// Disagreement here would not crash — it would quietly change which nights the
/// insights, the helper summary and the weekly reflection count.
@MainActor
struct SubstancePresenceTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            NightEntry.self,
            LoggedSubstanceRecord.self,
            PartnerDetailRecord.self,
            TriggerTagRecord.self
        ])
        return ModelContext(try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        ))
    }

    private func entry(
        substances: [String] = [],
        injections: [String] = []
    ) -> NightEntry {
        NightEntry(
            date: .now,
            hadSex: false,
            partnerDetails: [],
            skippedNight: false,
            substances: substances,
            injectionSubstances: injections,
            triggerTags: []
        )
    }

    @Test("The cheap check agrees with the list for every shape a row takes", arguments: [
        ([], []),
        (["Alcohol"], []),
        (["Alcohol", "Cannabis"], []),
        ([], ["3-MMC"]),
        (["Alcohol"], ["3-MMC"]),
    ])
    func agreesWithTheList(substances: [String], injections: [String]) throws {
        let context = try makeContext()
        let subject = entry(substances: substances, injections: injections)
        context.insert(subject)
        try context.save()

        #expect(subject.hasSubstances == !subject.substances.isEmpty,
                "hasSubstances disagreed for \(substances) / \(injections)")
        #expect(subject.hasInjectionSubstances == !subject.injectionSubstances.isEmpty,
                "hasInjectionSubstances disagreed for \(substances) / \(injections)")
    }

    @Test("A row carrying only a legacy blob still answers yes")
    func legacyBlobRowAnswers() throws {
        let context = try makeContext()
        let subject = entry(substances: ["Alcohol"], injections: ["3-MMC"])
        context.insert(subject)
        try context.save()

        // Drop the typed records and keep the blobs, which is exactly the shape
        // of a row written before TypedRecordsMigration ran.
        for record in subject.substanceRecords ?? [] {
            context.delete(record)
        }
        subject.substanceRecords = []
        try context.save()

        #expect(subject.substances == ["Alcohol"], "the blob fallback stopped working")
        #expect(subject.hasSubstances, "hasSubstances missed a legacy row the list can still read")
        #expect(subject.hasInjectionSubstances, "hasInjectionSubstances missed a legacy injection row")
    }

    @Test("Injections alone do not count as substances, and the reverse")
    func injectionsAreCountedSeparately() throws {
        let context = try makeContext()
        let injectionOnly = entry(substances: [], injections: ["3-MMC"])
        context.insert(injectionOnly)
        try context.save()

        #expect(injectionOnly.hasInjectionSubstances)
        #expect(injectionOnly.hasSubstances == !injectionOnly.substances.isEmpty)

        let swallowedOnly = entry(substances: ["Alcohol"], injections: [])
        context.insert(swallowedOnly)
        try context.save()

        #expect(swallowedOnly.hasSubstances)
        #expect(swallowedOnly.hasInjectionSubstances == !swallowedOnly.injectionSubstances.isEmpty)
    }
}
