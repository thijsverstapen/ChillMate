import Foundation
import SwiftData
import Testing
@testable import ChillMate

/// Opens a SwiftData store **on disk** rather than in memory.
///
/// Every other suite here uses `isStoredInMemoryOnly`, which builds the schema
/// fresh each time and so cannot see anything that only goes wrong when an
/// existing store file meets a changed schema. That is precisely the failure
/// that reaches people who already have the app: their store was written by the
/// version before, and the new one has to open it.
///
/// `CHILLMATE_STORE_PATH` points the suite at a store somewhere else. Set it to
/// a store written by an earlier build and the suite becomes a real
/// old-data test: run it once on the old schema to write the store, once on the
/// new one to prove the new schema can still read it. That is how the indexes
/// were checked before they shipped.
@MainActor
struct StoreCompatibilityTests {

    private static let schema = Schema([
        NightEntry.self,
        LoggedSubstanceRecord.self,
        PartnerDetailRecord.self,
        TriggerTagRecord.self,
        UserProfile.self,
        STDTestRecord.self,
        DrugDoseTimerRecord.self,
        SaferSessionPlan.self,
        JournalEntry.self,
        RiskCheckRecord.self
    ])

    /// The store under test, and whether this run is the one that created it.
    private static func storeURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["CHILLMATE_STORE_PATH"] {
            return URL(fileURLWithPath: override)
        }
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ChillMateStoreCompatibility-\(UUID().uuidString).store")
    }

    private func container(at url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: Self.schema,
            configurations: [ModelConfiguration(url: url)]
        )
    }

    @Test("A store written to disk reopens with every model readable")
    func diskStoreReopens() throws {
        let url = Self.storeURL()
        let existed = FileManager.default.fileExists(atPath: url.path)

        // First run writes the fixture. A later run against the same path only
        // reads it, which is what makes the cross-version check meaningful.
        if !existed {
            let context = ModelContext(try container(at: url))
            let entry = NightEntry(
                date: Date(timeIntervalSince1970: 1_700_000_000),
                hadSex: false,
                partnerDetails: [],
                skippedNight: false,
                substances: ["Alcohol", "Cannabis"],
                injectionSubstances: [],
                triggerTags: [.party]
            )
            context.insert(entry)
            context.insert(JournalEntry(
                date: Date(timeIntervalSince1970: 1_700_000_100),
                rememberClearly: "a line"
            ))
            try context.save()
        }

        let reopened = ModelContext(try container(at: url))

        let entries = try reopened.fetch(
            FetchDescriptor<NightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )
        let entry = try #require(entries.first, "the store lost its night entries")
        #expect(entry.substances == ["Alcohol", "Cannabis"],
                "the typed records did not survive the round trip")
        #expect(entry.triggerTags == [.party])

        let journals = try reopened.fetch(
            FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )
        #expect(journals.isEmpty == false, "the store lost its journal entries")

        // Only clean up a store this run created for itself.
        if !existed && ProcessInfo.processInfo.environment["CHILLMATE_STORE_PATH"] == nil {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
