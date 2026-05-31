import AppIntents
import SwiftData
import SwiftUI

// MARK: - Log Hydration

struct LogHydrationIntent: AppIntent {
    static let title: LocalizedStringResource = "Log hydration"
    static let description = IntentDescription("Marks that you drank water in ChillMate.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await MainActor.run {
            NotificationCenter.default.post(name: .watchDidLogHydration, object: nil)
        }
        return .result(value: "Hydration logged in ChillMate.")
    }
}

// MARK: - Log Nothing Happened

struct LogSkippedNightIntent: AppIntent {
    static let title: LocalizedStringResource = "Log nothing happened"
    static let description = IntentDescription("Records a checked Chill with no substance or sex tags.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await MainActor.run {
            UserDefaults.standard.set("quickSkip", forKey: "pendingQuickAction")
        }
        return .result(value: "Logged in ChillMate.")
    }
}

// MARK: - Open Safe Route

struct OpenSafeRouteIntent: AppIntent {
    static let title: LocalizedStringResource = "Open safe route home"
    static let description = IntentDescription("Opens the safe route home screen in ChillMate.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            UserDefaults.standard.set(NotificationDestination.safeRoute.rawValue, forKey: "pendingAppDestination")
        }
        return .result()
    }
}

// MARK: - Open Log Sheet

struct OpenLogSheetIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a Chill"
    static let description = IntentDescription("Opens the log sheet in ChillMate to record a session.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            UserDefaults.standard.set(NotificationDestination.log.rawValue, forKey: "pendingAppDestination")
        }
        return .result()
    }
}

// MARK: - Open Timers

struct OpenTimersIntent: AppIntent {
    static let title: LocalizedStringResource = "Open ChillMate timers"
    static let description = IntentDescription("Opens check-in timers in ChillMate.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            UserDefaults.standard.set(NotificationDestination.timers.rawValue, forKey: "pendingAppDestination")
        }
        return .result()
    }
}

// MARK: - Open Emergency

struct OpenEmergencyIntent: AppIntent {
    static let title: LocalizedStringResource = "Open emergency info"
    static let description = IntentDescription("Opens emergency contacts and safety info in ChillMate.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            UserDefaults.standard.set(NotificationDestination.emergency.rawValue, forKey: "pendingAppDestination")
        }
        return .result()
    }
}

// MARK: - Shortcuts Provider

struct ChillMateShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogHydrationIntent(),
            phrases: [
                "Log hydration in \(.applicationName)",
                "I drank water in \(.applicationName)"
            ],
            shortTitle: "Log hydration",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: LogSkippedNightIntent(),
            phrases: [
                "Log nothing happened in \(.applicationName)",
                "Check in with \(.applicationName)"
            ],
            shortTitle: "Log nothing happened",
            systemImageName: "moon.zzz.fill"
        )
        AppShortcut(
            intent: OpenSafeRouteIntent(),
            phrases: [
                "Get me home with \(.applicationName)",
                "Safe route in \(.applicationName)"
            ],
            shortTitle: "Safe route home",
            systemImageName: "location.fill"
        )
        AppShortcut(
            intent: OpenLogSheetIntent(),
            phrases: ["Log a Chill in \(.applicationName)"],
            shortTitle: "Log a Chill",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: OpenEmergencyIntent(),
            phrases: ["Open emergency in \(.applicationName)"],
            shortTitle: "Emergency info",
            systemImageName: "sos.circle.fill"
        )
    }
}
