import Foundation
import OSLog
import SwiftData

enum ChillMateModelContainer {
    @MainActor private static var localContainer: ModelContainer?
    @MainActor private static var recoveryContainer: ModelContainer?

    @MainActor
    static func container() -> ModelContainer {
        // Under unit tests the app is the test host and fully launches, but the test
        // simulator has no iCloud account, so SwiftData's CloudKit mirroring traps during
        // its async setup (a crash the synchronous recovery path below cannot catch). Use a
        // local in-memory store for tests; logic tests don't need CloudKit or persistence.
        if isRunningUnitTests, let testContainer = try? makeRecoveryContainer() {
            return testContainer
        }

        do {
            return try resolvedContainer()
        } catch {
            if let recoveryContainer = try? makeRecoveryContainer() {
                return recoveryContainer
            }

            // Both the CloudKit-backed store and the in-memory recovery store
            // failed. Log before trapping so the reason survives in the device
            // console and in a crash report, rather than only the message text.
            Logger.data.fault("Model container unavailable: \(error.localizedDescription, privacy: .public)")
            fatalError("Unable to create ChillMate model container: \(error.localizedDescription)")
        }
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    @MainActor
    static func containerForDataDeletion() throws -> ModelContainer {
        try resolvedContainer()
    }

    @MainActor
    private static func resolvedContainer() throws -> ModelContainer {
        if let localContainer {
            return localContainer
        }

        let container = try makeContainer()
        localContainer = container
        return container
    }

    @MainActor
    private static func makeContainer() throws -> ModelContainer {
        try ensureApplicationSupportDirectory()

        let schema = appSchema
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.codex.ChillMate")
        )

        let container = try ModelContainer(for: schema, migrationPlan: ChillMateMigrationPlan.self, configurations: [configuration])
        LocalSecurityService.applyFileProtection()
        return container
    }

    private static func ensureApplicationSupportDirectory() throws {
        guard let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        try FileManager.default.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)
    }

    @MainActor
    private static func makeRecoveryContainer() throws -> ModelContainer {
        if let recoveryContainer {
            return recoveryContainer
        }

        let schema = appSchema
        // In-memory recovery store is a local last resort; CloudKit is intentionally
        // omitted because SwiftData rejects combining it with isStoredInMemoryOnly,
        // which would make this fallback fail exactly when it's needed most.
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        LocalSecurityService.applyFileProtection()
        recoveryContainer = container
        return container
    }

    private static var appSchema: Schema {
        Schema(ChillMateSchemaModels.all)
    }
}

/// Materializes NightEntry's typed child records (substances, partners, trigger
/// tags) from the legacy JSON blobs. Runs every launch but only touches rows
/// still stamped `typedRecordsVersion == 0` — the stamp lives on the entry
/// itself (not a local flag), so a run against the in-memory recovery store or a
/// failed save simply retries next launch, and rows synced later from an older
/// build get picked up too. Blobs stay in place as a dual-written fallback, so
/// this can never lose data.
@MainActor
enum TypedRecordsMigration {
    static func runIfNeeded() {
        let defaults = UserDefaults.standard
        let context = ChillMateModelContainer.container().mainContext

        // Once a run finds nothing left, later launches only need a bounded
        // "is there anything new?" probe rather than a full predicate fetch over
        // the whole table. A row synced later from an older build still gets
        // picked up, because the probe is a real query — it is just capped at one
        // row instead of materializing every match.
        let settled = defaults.bool(forKey: DefaultsKey.typedRecordsMigrationCompleted)
        var descriptor = FetchDescriptor<NightEntry>(
            predicate: #Predicate { $0.typedRecordsVersion == 0 }
        )
        if settled {
            descriptor.fetchLimit = 1
        }

        guard let probe = try? context.fetch(descriptor), !probe.isEmpty else {
            defaults.set(true, forKey: DefaultsKey.typedRecordsMigrationCompleted)
            return
        }

        // Something turned up; if we were in the settled state, re-fetch in full.
        let entries: [NightEntry]
        if settled {
            var full = FetchDescriptor<NightEntry>(
                predicate: #Predicate { $0.typedRecordsVersion == 0 }
            )
            full.fetchLimit = 0
            let refetched = context.fetchLogging(full)
            entries = refetched.isEmpty ? probe : refetched
        } else {
            entries = probe
        }

        for entry in entries {
            entry.materializeTypedRecordsIfNeeded()
        }
        context.saveChanges()
        defaults.set(true, forKey: DefaultsKey.typedRecordsMigrationCompleted)
        Logger.data.info("Typed-records migration materialized \(entries.count, privacy: .public) entries")
    }
}

/// Versioned baseline for the schema as it shipped through 4.2.0.
///
/// Establishing this before publish gave future schema changes an explicit
/// migration foundation instead of relying solely on inferred lightweight
/// migration.
enum ChillMateSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] { ChillMateSchemaModels.all }
}

/// 4.2.1: adds `NightEntry.contentVersion`, the edit counter that lets views
/// distinguish "an entry changed" from "a row was added or removed".
///
/// The model list is identical — only an attribute was added, with a default, so
/// SwiftData's lightweight inference handles it. The version is bumped anyway so
/// the store records which shape it is on and a future stage that *does* need
/// custom work has a defined predecessor to migrate from.
enum ChillMateSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] { ChillMateSchemaModels.all }
}

/// Single list of persisted models, shared by every schema version and by the
/// live container, so the three can never drift apart.
enum ChillMateSchemaModels {
    static let all: [any PersistentModel.Type] = [
        NightEntry.self,
        LoggedSubstanceRecord.self,
        PartnerDetailRecord.self,
        TriggerTagRecord.self,
        UserProfile.self,
        STDTestRecord.self,
        DrugDoseTimerRecord.self,
        SaferSessionPlan.self,
        RiskCheckRecord.self,
        JournalEntry.self
    ]
}

enum ChillMateMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ChillMateSchemaV1.self, ChillMateSchemaV2.self]
    }

    /// V1 → V2 is `.lightweight`: the only change is a new attribute carrying a
    /// default, which SwiftData can infer. It is declared explicitly rather than
    /// left to an empty `stages` array so the path between versions is stated in
    /// code, and so the next stage that needs a `.custom` handler has an obvious
    /// place to go.
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: ChillMateSchemaV1.self, toVersion: ChillMateSchemaV2.self)
        ]
    }
}

extension Logger {
    /// Shared logger for the SwiftData persistence layer.
    static let data = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.codex.ChillMate", category: "data")
}

extension ModelContext {
    /// Saves pending changes, logging any failure instead of silently discarding it via `try?`.
    /// Success behavior is identical to the previous `try? save()`; failures are now diagnosable
    /// instead of being lost, which matters for the health data ChillMate stores.
    func saveChanges(_ caller: String = #function) {
        do {
            try save()
        } catch {
            Logger.data.error("SwiftData save failed in \(caller, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fetches, logging any failure and returning an empty result.
    ///
    /// Behaviour matches the `(try? fetch(...)) ?? []` this replaces — the caller
    /// still gets an empty array — but a failing fetch now leaves a trace instead
    /// of being indistinguishable from a genuinely empty table. That distinction
    /// matters here: "no dose timers" and "the store could not be read" render the
    /// same way on screen but mean very different things.
    func fetchLogging<T>(
        _ descriptor: FetchDescriptor<T>,
        _ caller: String = #function
    ) -> [T] {
        do {
            return try fetch(descriptor)
        } catch {
            Logger.data.error("SwiftData fetch failed in \(caller, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
