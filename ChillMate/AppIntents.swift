import AppIntents
import SwiftData
import SwiftUI

// MARK: - Hydration log (shared daily flag)

/// Single source of truth for the lightweight "drank water today" flag, shared
/// across the app, the widgets/Live Activity, and Siri via the App Group. It is
/// date-stamped so it naturally resets each day. Previously each surface wrote
/// its own dead key (`widgetHydrationLogged`) or posted an unobserved
/// notification, so "log hydration" recorded nothing; this unifies them.
enum HydrationLog {
    static let appGroup = "group.com.codex.ChillMate"
    static let key = "lastHydrationLogDate"

    private static var store: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    static func markLoggedNow() {
        store.set(Date.now.timeIntervalSince1970, forKey: key)
    }

    static var loggedDate: Date? {
        let stamp = store.double(forKey: key)
        return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }

    static var isLoggedToday: Bool {
        guard let loggedDate else { return false }
        return Calendar.current.isDateInToday(loggedDate)
    }
}

// MARK: - Log Hydration

struct LogHydrationIntent: AppIntent {
    static let title: LocalizedStringResource = "Log hydration"
    static let description = IntentDescription("Marks that you drank water in ChillMate.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await MainActor.run {
            // Persist the daily flag (works even when the app isn't running) and
            // post for any live UI to refresh immediately.
            HydrationLog.markLoggedNow()
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
        // Write directly to the shared store so this works whether or not the app
        // is in the foreground. (It previously set a `pendingQuickAction` key that
        // nothing ever read, so nothing was logged.)
        let message = await MainActor.run { () -> String in
            let context = ChillMateModelContainer.container().mainContext
            let startOfToday = Calendar.current.startOfDay(for: .now)
            let descriptor = FetchDescriptor<NightEntry>(
                predicate: #Predicate { $0.date >= startOfToday }
            )
            if let existing = try? context.fetch(descriptor), !existing.isEmpty {
                return String(localized: "You already have an entry logged for today.")
            }
            context.insert(NightEntry(date: .now, hadSex: false, skippedNight: true, substances: []))
            context.saveChanges()
            return String(localized: "Logged a clear night in ChillMate.")
        }
        return .result(value: message)
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

// MARK: - Open Risk Checker

struct OpenRiskCheckerIntent: AppIntent {
    static let title: LocalizedStringResource = "Check a combination"
    static let description = IntentDescription("Opens the risk checker in ChillMate to check how substances and medication combine.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            UserDefaults.standard.set(NotificationDestination.combinationRisk.rawValue, forKey: "pendingAppDestination")
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
                "I drank water in \(.applicationName)",
                "Log water in \(.applicationName)"
            ],
            shortTitle: "Log hydration",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: LogSkippedNightIntent(),
            phrases: [
                "Log nothing happened in \(.applicationName)",
                "Check in with \(.applicationName)",
                "Log a clear night in \(.applicationName)"
            ],
            shortTitle: "Log nothing happened",
            systemImageName: "moon.zzz.fill"
        )
        AppShortcut(
            intent: OpenSafeRouteIntent(),
            phrases: [
                "Get me home with \(.applicationName)",
                "Safe route in \(.applicationName)",
                "Take me home with \(.applicationName)"
            ],
            shortTitle: "Safe route home",
            systemImageName: "location.fill"
        )
        AppShortcut(
            intent: OpenLogSheetIntent(),
            phrases: [
                "Log a Chill in \(.applicationName)",
                "Start a log in \(.applicationName)",
                "Record a session in \(.applicationName)"
            ],
            shortTitle: "Log a Chill",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: OpenTimersIntent(),
            phrases: [
                "Open timers in \(.applicationName)",
                "Show my check-in timers in \(.applicationName)"
            ],
            shortTitle: "Check-in timers",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: OpenEmergencyIntent(),
            phrases: [
                "Open emergency in \(.applicationName)",
                "Show emergency info in \(.applicationName)",
                "I need help in \(.applicationName)"
            ],
            shortTitle: "Emergency info",
            systemImageName: "sos.circle.fill"
        )
        AppShortcut(
            intent: OpenRiskCheckerIntent(),
            phrases: [
                "Check a combination in \(.applicationName)",
                "Open the risk checker in \(.applicationName)",
                "Is this safe to mix in \(.applicationName)"
            ],
            shortTitle: "Risk checker",
            systemImageName: "exclamationmark.shield.fill"
        )
    }
}
