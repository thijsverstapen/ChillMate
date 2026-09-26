import Foundation
import OSLog
import SQLite3
import SwiftData

/// Gives a store made before an `#Index` existed the indexes a new store gets.
///
/// `#Index` reaches new stores only. Opening an existing one with a model that
/// adds an index changes nothing: Core Data does not treat an index-only change
/// as a model change, so it never migrates and never creates the index. 5.1.0
/// indexed the dates every screen sorts by, and that sped up exactly the installs
/// with short histories while skipping every long one. Checked by writing a store
/// with a build that had no indexes and opening it with one that did: zero date
/// indexes afterwards, against eight on a fresh install.
///
/// A schema migration could force it, but only by freezing a copy of all ten
/// models first — a stage between two identical shapes aborts at launch (see
/// `ChillMateSchemaV1`). This does the one thing needed instead, without touching
/// the model: it asks Core Data what a fresh store looks like, by creating one in
/// a temporary directory, and adds whichever of that store's indexes the real
/// store is missing, before the real store is opened.
///
/// - Nothing is dropped, altered or rewritten. Every statement is Core Data's own
///   `CREATE INDEX`, made conditional, so the store ends up with the same indexes
///   a fresh install has, under the same names.
/// - An index whose column the store does not have yet — a store that the
///   container is about to migrate — is skipped, and the next launch tries again.
/// - It runs once per `revision`. Adding an `#Index` means bumping it, and
///   `StoreIndexRepairTests` fails until the two agree.
enum StoreIndexRepair {

    /// Bump whenever an `#Index` is added, removed or changed.
    static let revision = 1

    /// The index SQL a store needs, keyed by index name.
    typealias IndexStatements = [String: String]

    @MainActor
    static func runIfNeeded(storeURL: URL, schema: Schema, defaults: UserDefaults = .standard) {
        guard defaults.integer(forKey: DefaultsKey.storeIndexRevision) < revision else { return }
        // A store that does not exist yet is created with every index already.
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            defaults.set(revision, forKey: DefaultsKey.storeIndexRevision)
            return
        }

        do {
            let wanted = try freshStoreIndexes(schema: schema)
            if try apply(wanted, to: storeURL) {
                defaults.set(revision, forKey: DefaultsKey.storeIndexRevision)
            }
        } catch {
            // Most often the phone is locked and the store is sealed. Nothing was
            // changed; the next launch tries again.
            Logger.data.info("Store index repair deferred: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The indexes Core Data creates for `schema` in a brand-new store.
    @MainActor
    static func freshStoreIndexes(schema: Schema) throws -> IndexStatements {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoreIndexRepair-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("fresh.store")
        do {
            // Scoped so the container is gone before the file is read.
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            _ = try ModelContainer(for: schema, configurations: [configuration])
        }
        // Only the indexes `#Index` declares. A fresh store also has Core Data's
        // own, for relationships and change history, which every store has had
        // from the start and which are Core Data's to manage.
        return try indexes(in: url).filter { $0.key.contains(swiftDataIndexMarker) }
    }

    /// What SwiftData puts in the name of every index an `#Index` creates, as in
    /// `Z_NightEntry_SwiftDataIndexOnBinarydate`. If that ever changed, the filter
    /// would find nothing and the repair would do nothing, and the tests fail.
    static let swiftDataIndexMarker = "SwiftDataIndexOn"

    /// Every index in the store at `url` that has SQL, keyed by name.
    static func indexes(in url: URL) throws -> IndexStatements {
        let database = try Database(url: url, readOnly: true)
        var result: IndexStatements = [:]
        try database.each("SELECT name, sql FROM sqlite_master WHERE type = 'index' AND sql IS NOT NULL") { row in
            result[row[0]] = row[1]
        }
        return result
    }

    /// Adds every wanted index the store lacks. Returns whether none are missing
    /// afterwards.
    static func apply(_ wanted: IndexStatements, to url: URL) throws -> Bool {
        let database = try Database(url: url, readOnly: false)
        var present = Set<String>()
        try database.each("SELECT name FROM sqlite_master WHERE type = 'index'") { row in
            present.insert(row[0])
        }

        var complete = true
        for (name, sql) in wanted.sorted(by: { $0.key < $1.key }) where !present.contains(name) {
            do {
                try database.execute(conditional(sql))
                Logger.data.info("Store index repair added \(name, privacy: .public)")
            } catch {
                // A column the store does not have yet. The container migrates the
                // store after this; the next launch finds the column and adds it.
                complete = false
            }
        }
        return complete
    }

    /// `CREATE INDEX x` as `CREATE INDEX IF NOT EXISTS x`, so running twice, or
    /// racing another launch, cannot fail on an index that is already there.
    static func conditional(_ sql: String) -> String {
        for prefix in ["CREATE UNIQUE INDEX ", "CREATE INDEX "] where sql.hasPrefix(prefix) {
            let rest = sql.dropFirst(prefix.count)
            if rest.hasPrefix("IF NOT EXISTS ") { return sql }
            return prefix + "IF NOT EXISTS " + rest
        }
        return sql
    }

    /// Just enough SQLite to read a schema and add an index.
    ///
    /// `@safe`: the raw handle never leaves this class, and every call through it
    /// is marked where it happens.
    @safe final class Database {
        private var handle: OpaquePointer?

        struct Failure: LocalizedError {
            let message: String
            var errorDescription: String? { message }
        }

        init(url: URL, readOnly: Bool) throws {
            let flags = readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE
            let status = unsafe sqlite3_open_v2(url.path, &handle, flags, nil)
            guard status == SQLITE_OK else {
                let message = unsafe String(cString: sqlite3_errstr(status))
                unsafe sqlite3_close(handle)
                throw Failure(message: message)
            }
            // Core Data keeps its stores in WAL mode; waiting briefly beats failing
            // on a lock another process holds for a moment.
            unsafe sqlite3_busy_timeout(handle, 2_000)
        }

        deinit {
            unsafe sqlite3_close(handle)
        }

        func execute(_ sql: String) throws {
            var error: UnsafeMutablePointer<CChar>?
            guard unsafe sqlite3_exec(handle, sql, nil, nil, &error) == SQLITE_OK else {
                let message = unsafe error.map { unsafe String(cString: $0) } ?? "unknown"
                unsafe sqlite3_free(error)
                throw Failure(message: message)
            }
        }

        func each(_ sql: String, _ body: ([String]) -> Void) throws {
            var statement: OpaquePointer?
            guard unsafe sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Failure(message: unsafe String(cString: sqlite3_errmsg(handle)))
            }
            defer { unsafe sqlite3_finalize(statement) }

            let columns = unsafe sqlite3_column_count(statement)
            while unsafe sqlite3_step(statement) == SQLITE_ROW {
                let row = (0..<columns).map { column in
                    unsafe sqlite3_column_text(statement, column).map { unsafe String(cString: $0) } ?? ""
                }
                body(row)
            }
        }
    }
}
