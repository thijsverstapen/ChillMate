import Foundation
import SwiftData

enum ChillMateModelContainer {
    @MainActor private static var localContainer: ModelContainer?
    @MainActor private static var recoveryContainer: ModelContainer?

    @MainActor
    static func container() -> ModelContainer {
        do {
            return try resolvedContainer()
        } catch {
            if let recoveryContainer = try? makeRecoveryContainer() {
                return recoveryContainer
            }

            fatalError("Unable to create ChillMate model container: \(error.localizedDescription)")
        }
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

        let container = try ModelContainer(for: schema, configurations: [configuration])
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .private("iCloud.com.codex.ChillMate"))
        let container = try ModelContainer(for: schema, configurations: [configuration])
        LocalSecurityService.applyFileProtection()
        recoveryContainer = container
        return container
    }

    private static var appSchema: Schema {
        Schema([
            NightEntry.self,
            UserProfile.self,
            STDTestRecord.self,
            DrugDoseTimerRecord.self,
            SaferSessionPlan.self,
            RiskCheckRecord.self,
            JournalEntry.self
        ])
    }
}
