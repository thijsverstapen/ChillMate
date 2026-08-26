import AppIntents
import SwiftData
import SwiftUI

// MARK: - Hydration log (shared daily flag)

/// Single source of truth for the lightweight "drank water today" flag, shared
/// across the app, the widgets/Live Activity, and Siri via the App Group. It is
/// date-stamped so it naturally resets each day. Previously each surface wrote
/// its own dead key (`widgetHydrationLogged`) or posted an unobserved
/// notification, so "log hydration" recorded nothing; this unifies them.
///
/// Note that the flag lives in the App Group suite, never in `UserDefaults.standard`,
/// which is why there is no `DefaultsKey` entry for it. `WidgetLogHydrationIntent` in
/// the Live Activity extension writes the same key into the same suite from its own
/// copy of the string, because this file is compiled into the app target only. Change
/// either the key or the suite at one end and hydration logging silently stops
/// crossing the process boundary.
enum HydrationLog {
    static let appGroup = WidgetSharedKey.suiteName
    static let key = WidgetSharedKey.hydrationLogDate

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
            UserDefaults.standard.set(NotificationDestination.safeRoute.rawValue, forKey: DefaultsKey.pendingAppDestination)
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
            UserDefaults.standard.set(NotificationDestination.log.rawValue, forKey: DefaultsKey.pendingAppDestination)
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
            UserDefaults.standard.set(NotificationDestination.timers.rawValue, forKey: DefaultsKey.pendingAppDestination)
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
            UserDefaults.standard.set(NotificationDestination.emergency.rawValue, forKey: DefaultsKey.pendingAppDestination)
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
            UserDefaults.standard.set(NotificationDestination.combinationRisk.rawValue, forKey: DefaultsKey.pendingAppDestination)
        }
        return .result()
    }
}

// MARK: - Substance as an intent parameter

/// Lets Siri and Shortcuts pass a substance into an intent, which is what turns
/// these from "open a screen" into "answer a question" or "start the thing".
extension Substance: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Substance")
    }

    /// Spelled out case by case rather than derived from `allCases`: the App
    /// Intents metadata processor reads this at build time and rejects anything
    /// it cannot see as a literal dictionary.
    ///
    /// These are drug and brand names. They read the same in every language
    /// ChillMate ships, so they are surfaced verbatim rather than translated.
    static let caseDisplayRepresentations: [Substance: DisplayRepresentation] = [
        .cannabis: DisplayRepresentation(title: "Cannabis"),
        .alcohol: DisplayRepresentation(title: "Alcohol"),
        .mdma: DisplayRepresentation(title: "MDMA"),
        .threeMMC: DisplayRepresentation(title: "3MMC"),
        .ketamine: DisplayRepresentation(title: "Ketamine"),
        .ghb: DisplayRepresentation(title: "GHB"),
        .gbl: DisplayRepresentation(title: "GBL"),
        .cocaine: DisplayRepresentation(title: "Cocaine"),
        .poppers: DisplayRepresentation(title: "Poppers"),
        .kamagra: DisplayRepresentation(title: "Kamagra"),
        .viagra: DisplayRepresentation(title: "Viagra"),
        .psychedelics: DisplayRepresentation(title: "Psychedelics"),
        .unknown: DisplayRepresentation(title: "Unknown"),
        .other: DisplayRepresentation(title: "Other")
    ]
}

// MARK: - Check a combination and answer

struct CheckCombinationIntent: AppIntent {
    static let title: LocalizedStringResource = "Check two substances"
    static let description = IntentDescription("Asks ChillMate how two substances combine and reads the verdict back to you.")
    static let openAppWhenRun = false

    @Parameter(title: "First substance")
    var first: Substance

    @Parameter(title: "Second substance")
    var second: Substance

    static var parameterSummary: some ParameterSummary {
        Summary("Check \(\.$first) with \(\.$second)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard first != second else {
            let same = String(localized: "Pick two different substances.")
            return .result(value: same, dialog: "\(same)")
        }

        // Sorted most severe first by the checker, so the first row is the verdict.
        let warnings = SubstanceInteractionChecker.warnings(for: [first, second])

        guard let worst = warnings.first else {
            let none = String(localized: "ChillMate has nothing on file for \(first.rawValue) with \(second.rawValue). That does not mean it is safe. It means there is nothing on file here.")
            return .result(value: none, dialog: "\(none)")
        }

        let verdict = String(localized: "\(worst.level.label). \(worst.warning)")
        return .result(value: verdict, dialog: "\(verdict)")
    }
}

// MARK: - Start a dose timer

struct StartDoseTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a dose timer"
    static let description = IntentDescription("Starts a ChillMate check-in timer for a substance, with a Live Activity on the Lock Screen.")
    static let openAppWhenRun = false

    @Parameter(title: "Substance")
    var substance: Substance

    @Parameter(title: "Hours", default: 2, inclusiveRange: (1, 12))
    var hours: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Start a \(\.$hours) hour timer for \(\.$substance)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let started: (id: UUID, startsAt: Date, endsAt: Date) = await MainActor.run {
            let context = ChillMateModelContainer.container().mainContext
            let timer = DrugDoseTimerRecord(
                substanceName: substance.rawValue,
                startedAt: .now,
                durationHours: Double(hours)
            )
            context.insert(timer)
            context.saveChanges()
            DrugTimerLiveActivityController.start(for: timer)
            context.saveChanges()
            return (timer.id, timer.startedAt, timer.endsAt)
        }

        if (try? await NotificationService.shared.requestAuthorization()) == true {
            await NotificationService.shared.scheduleSessionCheckIns(
                id: started.id,
                startsAt: started.startsAt,
                endsAt: started.endsAt,
                destination: .timers
            )
        }

        let message = String(localized: "Started a \(hours) hour timer for \(substance.rawValue).")
        return .result(value: message, dialog: "\(message)")
    }
}

// MARK: - Log a substance

struct LogSubstanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a substance"
    static let description = IntentDescription("Records a Chill in ChillMate with one substance, without opening the app.")
    static let openAppWhenRun = false

    @Parameter(title: "Substance")
    var substance: Substance

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$substance) in ChillMate")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = await MainActor.run { () -> String in
            let context = ChillMateModelContainer.container().mainContext
            let startOfToday = Calendar.current.startOfDay(for: .now)
            let descriptor = FetchDescriptor<NightEntry>(
                predicate: #Predicate { $0.date >= startOfToday }
            )

            // Add to today's entry when there already is one, so a second "log
            // ketamine" does not create a competing record for the same night.
            if let existing = try? context.fetch(descriptor), let entry = existing.first {
                var names = entry.substances
                if !names.contains(substance.rawValue) {
                    names.append(substance.rawValue)
                    entry.substances = names
                }
                entry.skippedNight = false
                context.saveChanges()
                return String(localized: "Added \(substance.rawValue) to tonight's log.")
            }

            context.insert(
                NightEntry(date: .now, hadSex: false, skippedNight: false, substances: [substance.rawValue])
            )
            context.saveChanges()
            return String(localized: "Logged \(substance.rawValue) in ChillMate.")
        }
        return .result(value: message, dialog: "\(message)")
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
            intent: CheckCombinationIntent(),
            phrases: [
                "Check a mix with \(.applicationName)",
                "Ask \(.applicationName) about two substances",
                "What does \(.applicationName) say about mixing"
            ],
            shortTitle: "Check two substances",
            systemImageName: "exclamationmark.shield.fill"
        )
        AppShortcut(
            intent: StartDoseTimerIntent(),
            phrases: [
                "Start a dose timer in \(.applicationName)",
                "Start a \(.applicationName) timer",
                "Track a dose with \(.applicationName)"
            ],
            shortTitle: "Start a dose timer",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: LogSubstanceIntent(),
            phrases: [
                "Log a substance in \(.applicationName)",
                "Record what I took in \(.applicationName)"
            ],
            shortTitle: "Log a substance",
            systemImageName: "square.and.pencil"
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
