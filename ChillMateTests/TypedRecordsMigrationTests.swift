import Foundation
import SwiftData
import Testing
@testable import ChillMate

/// Verifies the JSON-blob → typed-relationship migration for NightEntry:
/// dual-write invariants, blob fallback for legacy rows, one-time
/// materialization, ordering, and cascade cleanup.
@MainActor
struct TypedRecordsMigrationTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            NightEntry.self,
            LoggedSubstanceRecord.self,
            PartnerDetailRecord.self,
            TriggerTagRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @Test("Init creates typed records and mirrors them into the legacy blobs")
    func initCreatesTypedRecords() throws {
        let context = try makeContext()
        let entry = NightEntry(
            date: .now,
            hadSex: true,
            partnerDetails: [SexPartnerRecord(name: "Alex", phoneNumber: "+31612345678", theyWerePenetrated: false, userWasPenetrated: true)],
            skippedNight: false,
            substances: ["GHB", "Cannabis"],
            injectionSubstances: ["3-MMC"],
            triggerTags: [.party, .horny]
        )
        context.insert(entry)
        try context.save()

        #expect(entry.substanceRecords?.count == 3)
        #expect(entry.partnerRecords?.count == 1)
        #expect(entry.triggerRecords?.count == 2)

        // Dual-write: the legacy blobs decode to the same values.
        #expect((try? JSONDecoder().decode([String].self, from: entry.substancesData)) == ["GHB", "Cannabis"])
        #expect((try? JSONDecoder().decode([String].self, from: entry.injectionSubstancesData)) == ["3-MMC"])
    }

    @Test("Legacy blob-only rows read via fallback and materialize idempotently")
    func legacyRowsMigrate() throws {
        let context = try makeContext()
        let entry = NightEntry(date: .now, hadSex: false, skippedNight: false, substances: [])
        context.insert(entry)

        // Simulate a row written by an older build: blobs only, no typed records,
        // and the pre-migration version stamp (0).
        entry.substancesData = try JSONEncoder().encode(["Ketamine"])
        entry.triggerTagsData = try JSONEncoder().encode([ChillTrigger.stress.rawValue])
        entry.partnerDetailsData = try JSONEncoder().encode([
            SexPartnerRecord(name: "Sam", phoneNumber: "0611111111", theyWerePenetrated: true, userWasPenetrated: false)
        ])
        entry.typedRecordsVersion = 0
        try context.save()

        // Before materialization the getters fall back to the blobs.
        #expect(entry.substances == ["Ketamine"])
        #expect(entry.triggerTags == [.stress])
        #expect(entry.partnerDetails.first?.name == "Sam")
        #expect((entry.substanceRecords ?? []).isEmpty)

        entry.materializeTypedRecordsIfNeeded()
        try context.save()

        #expect(entry.substanceRecords?.count == 1)
        #expect(entry.triggerRecords?.count == 1)
        #expect(entry.partnerRecords?.count == 1)
        #expect(entry.substances == ["Ketamine"])
        #expect(entry.typedRecordsVersion == 1)

        // Idempotent: a second pass must not duplicate.
        entry.materializeTypedRecordsIfNeeded()
        #expect(entry.substanceRecords?.count == 1)
    }

    @Test("A synced row from a current build is never re-materialized while its children are in flight")
    func syncRaceGuard() throws {
        let context = try makeContext()
        let entry = NightEntry(date: .now, hadSex: false, skippedNight: false, substances: ["GHB"])
        context.insert(entry)
        try context.save()
        #expect(entry.typedRecordsVersion == 1)

        // Simulate CloudKit delivering the parent (blobs + version stamp) before
        // its child records: relationships empty, but the row is stamped.
        entry.substanceRecords = []
        try context.save()

        entry.materializeTypedRecordsIfNeeded()
        // The version guard must prevent re-creating children from the blob …
        #expect((entry.substanceRecords ?? []).isEmpty)
        // … while the blob fallback keeps reads correct until the children arrive.
        #expect(entry.substances == ["GHB"])
    }

    @Test("Duplicate child records from a concurrent-upgrade union are deduped by the getters")
    func duplicateChildrenAreDeduped() throws {
        let context = try makeContext()
        let partner = SexPartnerRecord(name: "Alex", phoneNumber: "0612345678", theyWerePenetrated: false, userWasPenetrated: false)
        let entry = NightEntry(date: .now, hadSex: true, partnerDetails: [partner], skippedNight: false, substances: ["GHB", "MDMA"])
        context.insert(entry)
        try context.save()

        // Simulate the CloudKit union after two devices materialized the same
        // legacy row: identical (sortIndex, key) duplicates appear.
        entry.substanceRecords = (entry.substanceRecords ?? []) + [
            LoggedSubstanceRecord(name: "GHB", isInjection: false, sortIndex: 0)
        ]
        entry.partnerRecords = (entry.partnerRecords ?? []) + [
            PartnerDetailRecord(partner: partner, sortIndex: 0)
        ]
        try context.save()

        #expect(entry.substances == ["GHB", "MDMA"])
        #expect(entry.partnerDetails.count == 1)
        #expect(entry.partnerDetails.first?.id == partner.id)
    }

    @Test("Setters replace typed records without leaving orphans in the store")
    func settersReplaceWithoutOrphans() throws {
        let context = try makeContext()
        let entry = NightEntry(date: .now, hadSex: false, skippedNight: false, substances: ["GHB", "MDMA"])
        context.insert(entry)
        try context.save()

        entry.substances = ["Cannabis"]
        try context.save()

        #expect(entry.substances == ["Cannabis"])
        let allRecords = try context.fetch(FetchDescriptor<LoggedSubstanceRecord>())
        #expect(allRecords.count == 1)
        #expect(allRecords.first?.name == "Cannabis")
    }

    @Test("Injection and non-injection substances stay separate with order preserved")
    func injectionSeparationAndOrder() throws {
        let context = try makeContext()
        let entry = NightEntry(
            date: .now,
            hadSex: false,
            skippedNight: false,
            substances: ["Cannabis", "Alcohol", "GHB"],
            injectionSubstances: ["3-MMC", "Ketamine"]
        )
        context.insert(entry)
        try context.save()

        #expect(entry.substances == ["Cannabis", "Alcohol", "GHB"])
        #expect(entry.injectionSubstances == ["3-MMC", "Ketamine"])

        // Rewriting one list leaves the other untouched.
        entry.injectionSubstances = []
        #expect(entry.substances == ["Cannabis", "Alcohol", "GHB"])
        #expect(entry.injectionSubstances.isEmpty)
    }

    @Test("Partner records round-trip all fields including identity")
    func partnerRoundTrip() throws {
        let context = try makeContext()
        let partner = SexPartnerRecord(name: "Chris", phoneNumber: "+31699999999", theyWerePenetrated: true, userWasPenetrated: true)
        let entry = NightEntry(date: .now, hadSex: true, partnerDetails: [partner], skippedNight: false, substances: [])
        context.insert(entry)
        try context.save()

        let restored = entry.partnerDetails.first
        #expect(restored?.id == partner.id)
        #expect(restored?.name == "Chris")
        #expect(restored?.phoneNumber == "+31699999999")
        #expect(restored?.theyWerePenetrated == true)
        #expect(restored?.userWasPenetrated == true)
    }

    @Test("Deleting an entry cascades to its typed child records")
    func cascadeDelete() throws {
        let context = try makeContext()
        let entry = NightEntry(
            date: .now,
            hadSex: true,
            partnerDetails: [SexPartnerRecord(name: "Alex", phoneNumber: "", theyWerePenetrated: false, userWasPenetrated: false)],
            skippedNight: false,
            substances: ["GHB"],
            triggerTags: [.party]
        )
        context.insert(entry)
        try context.save()

        context.delete(entry)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<LoggedSubstanceRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PartnerDetailRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<TriggerTagRecord>()).isEmpty)
    }

    @Test("Typed records enable #Predicate filtering across entries")
    func predicateFiltering() throws {
        let context = try makeContext()
        context.insert(NightEntry(date: .now, hadSex: false, skippedNight: false, substances: ["GHB"]))
        context.insert(NightEntry(date: .now, hadSex: false, skippedNight: false, substances: ["Cannabis"]))
        try context.save()

        let descriptor = FetchDescriptor<LoggedSubstanceRecord>(
            predicate: #Predicate { $0.name == "GHB" }
        )
        let matches = try context.fetch(descriptor)
        #expect(matches.count == 1)
        #expect(matches.first?.entry != nil)
    }
}
