import Foundation
import SwiftData
import Testing
@testable import ChillMate

/// Giving a store that predates an `#Index` the indexes a new store gets.
///
/// Each test builds a real on-disk store in its own temporary directory, because
/// the thing being repaired is what Core Data writes to disk, and an in-memory
/// store has no SQL to inspect.
@MainActor
@Suite("Store index repair")
struct StoreIndexRepairTests {

    private let schema = Schema(ChillMateSchemaModels.all)

    private func makeDirectory(_ name: String = #function) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoreIndexRepairTests-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A store with one night in it, closed again.
    private func makeStore(at url: URL) throws {
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
        )
        container.mainContext.insert(NightEntry(date: .now, hadSex: false, skippedNight: true, substances: []))
        try container.mainContext.save()
    }

    private func nightCount(at url: URL) throws -> Int {
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
        )
        return try container.mainContext.fetchCount(FetchDescriptor<NightEntry>())
    }

    /// What an install from before 5.1.0 has: the same tables and rows, none of
    /// the indexes.
    private func dropIndexes(_ names: some Sequence<String>, at url: URL) throws {
        let database = try StoreIndexRepair.Database(url: url, readOnly: false)
        for name in names {
            try database.execute("DROP INDEX IF EXISTS \"\(name)\"")
        }
    }

    /// The premise. If a fresh store stopped indexing the date every list sorts
    /// by, there would be nothing for this to repair and the tests below would
    /// prove nothing.
    @Test("A fresh store indexes the night's date")
    func freshStoreHasTheDateIndex() throws {
        let fresh = try StoreIndexRepair.freshStoreIndexes(schema: schema)
        #expect(fresh.values.contains { $0.contains("ZNIGHTENTRY") && $0.contains("ZDATE") })
    }

    /// The case that matters: an old store comes out with exactly a new store's
    /// indexes, and keeps its rows.
    @Test("An old store gets a new store's indexes and keeps its data")
    func repairsAnOldStore() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("old.store")

        try makeStore(at: url)
        let fresh = try StoreIndexRepair.freshStoreIndexes(schema: schema)
        let untouched = try StoreIndexRepair.indexes(in: url).filter { fresh[$0.key] == nil }
        try dropIndexes(fresh.keys, at: url)
        #expect(try StoreIndexRepair.indexes(in: url) == untouched)

        #expect(try StoreIndexRepair.apply(fresh, to: url))

        // Every declared index back under Core Data's own name, and Core Data's
        // other indexes exactly as they were.
        let after = try StoreIndexRepair.indexes(in: url)
        #expect(after.filter { fresh[$0.key] != nil }.keys.sorted() == fresh.keys.sorted())
        #expect(after.filter { fresh[$0.key] == nil } == untouched)
        #expect(try nightCount(at: url) == 1)
    }

    /// The app can be killed halfway, or two launches can race.
    @Test("Running it twice changes nothing the second time")
    func idempotent() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("old.store")

        try makeStore(at: url)
        let fresh = try StoreIndexRepair.freshStoreIndexes(schema: schema)
        try dropIndexes(fresh.keys.sorted().prefix(fresh.count / 2), at: url)

        #expect(try StoreIndexRepair.apply(fresh, to: url))
        let once = try StoreIndexRepair.indexes(in: url)
        #expect(try StoreIndexRepair.apply(fresh, to: url))
        #expect(try StoreIndexRepair.indexes(in: url) == once)
    }

    /// A store the container has yet to migrate may lack a column an index
    /// needs. That index waits for the next launch; nothing fails.
    @Test("An index on a missing column is left for later, not an error")
    func missingColumnWaits() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("old.store")
        try makeStore(at: url)

        let wanted = ["Z_NightEntry_notYet": "CREATE INDEX Z_NightEntry_notYet ON ZNIGHTENTRY (ZNOTACOLUMN)"]
        #expect(try StoreIndexRepair.apply(wanted, to: url) == false)
        #expect(try nightCount(at: url) == 1)
    }

    @Test("Nothing is created for an install that has no store yet")
    func noStoreNoWork() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("missing.store")
        let suite = "StoreIndexRepairTests.noStoreNoWork"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        StoreIndexRepair.runIfNeeded(storeURL: url, schema: schema, defaults: defaults)

        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(defaults.integer(forKey: DefaultsKey.storeIndexRevision) == StoreIndexRepair.revision)
    }

    @Test("Core Data's statements are made conditional, and only once")
    func conditional() {
        #expect(StoreIndexRepair.conditional("CREATE INDEX A ON T (C)") == "CREATE INDEX IF NOT EXISTS A ON T (C)")
        #expect(StoreIndexRepair.conditional("CREATE UNIQUE INDEX A ON T (C)") == "CREATE UNIQUE INDEX IF NOT EXISTS A ON T (C)")
        #expect(StoreIndexRepair.conditional("CREATE INDEX IF NOT EXISTS A ON T (C)") == "CREATE INDEX IF NOT EXISTS A ON T (C)")
    }

    /// The repair runs once per revision. An `#Index` added without bumping it
    /// would never reach an existing store, which is the bug this exists to fix,
    /// back again. Update the list and bump `StoreIndexRepair.revision` together.
    @Test("The indexes a fresh store gets are the ones this revision repairs")
    func revisionMatchesTheModel() throws {
        let names = try StoreIndexRepair.freshStoreIndexes(schema: schema).keys.sorted()
        #expect(StoreIndexRepair.revision == 1)
        #expect(names == Self.revisionOneIndexes, "The model's indexes changed: bump StoreIndexRepair.revision and update this list.")
    }

    private static let revisionOneIndexes = [
        "Z_DrugDoseTimerRecord_SwiftDataIndexOnBinarystartedAt",
        "Z_JournalEntry_SwiftDataIndexOnBinarydate",
        "Z_NightEntry_SwiftDataIndexOnBinarydate",
        "Z_RiskCheckRecord_SwiftDataIndexOnBinarycreatedAt",
        "Z_STDTestRecord_SwiftDataIndexOnBinarytestDate",
        "Z_SaferSessionPlan_SwiftDataIndexOnBinarycreatedAt",
        "Z_SaferSessionPlan_SwiftDataIndexOnBinaryplannedDate",
        "Z_UserProfile_SwiftDataIndexOnBinarycreatedAt"
    ]
}
