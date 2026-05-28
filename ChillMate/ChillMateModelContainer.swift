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
        let schema = appSchema
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .none
        )

        let container = try ModelContainer(for: schema, configurations: [configuration])
        LocalSecurityService.applyFileProtection()
        return container
    }

    @MainActor
    private static func makeRecoveryContainer() throws -> ModelContainer {
        if let recoveryContainer {
            return recoveryContainer
        }

        let schema = appSchema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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
