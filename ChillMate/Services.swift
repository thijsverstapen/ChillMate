import CoreLocation
import Foundation
import SwiftData
import SwiftUI
import ChillMateCore

/// Everything ChillMate talks to that is not itself.
///
/// The app reached for seven singletons by name in a hundred and ten places.
/// That is fine until you want to prove something about the code that calls
/// them: `NotificationService.shared` writes to the real notification centre, so
/// a test could either schedule real notifications or test nothing, and it chose
/// nothing. Thirty-two scheduling methods, including the PEP window and the
/// safer-plan reminders, had no coverage of their own for that reason.
///
/// Each service now has a protocol covering exactly the members the app uses,
/// and `Services` collects them. Views take it from the environment, so a test
/// or a preview substitutes the lot in one line; code that has no environment —
/// App Intents, the services themselves — takes `Services.live`, which is the
/// one place the concrete types are named.
///
/// The singletons are still there and still do the work. What changed is that
/// nothing outside this file says their names.

/// Scheduling and cancelling every local notification the app sends.
///
/// Exactly the members the app reaches for, and no more: a protocol wide enough
/// to cover the whole class would be a second copy of it to keep in step.
@MainActor
protocol NotificationScheduling: Sendable {
    func clearDailyAffirmations()
    func clearInactivityReminders()
    func clearPEPWindowReminders()
    func clearRedoseNudge(id: UUID)
    func clearSTIReminder()
    func clearSafeRouteCheck()
    func clearSafetyCheckInsForTonight() async
    func clearScheduledNotifications()
    func clearSessionCheckIns(id: UUID)
    func clearWeekendSafetyCheckIns()
    func clearWeeklySummary()
    func registerCategories()
    func requestAuthorization() async throws -> Bool
    func schedule48hFollowUp(entryID: UUID, sessionDate: Date)
    func scheduleAftercareReminder(entryID: UUID, after date: Date)
    func scheduleCheckInReminder()
    func scheduleDailyAffirmations()
    func scheduleDailyAffirmationsUsingOnDeviceModel(languageCode: String) async
    // A protocol cannot carry a default argument, so the default moves to an
    // extension and every caller keeps the shape it had.
    func scheduleInactivityReminders(from lastUse: Date)
    func schedulePEPWindowReminders(entry: NightEntry)
    func schedulePositiveSleepNotification(hours: Double)
    func schedulePrepReminders(planID: UUID, plannedSexAt plannedDate: Date)
    func scheduleRedoseNudge(id: UUID, startsAt: Date, durationHours: Double)
    func scheduleRiskWarning(count: Int)
    func scheduleSTDResultReminder(testID: UUID, dueDate: Date)
    func scheduleSTIReminder(dueDate: Date)
    func scheduleSafeRouteCheck(expectedArrival: Date)
    func scheduleSaferPlanReminders(planID: UUID, endingAt endingDate: Date)
    func scheduleSessionCheckIns(id: UUID, startsAt startDate: Date, endsAt endDate: Date, destination: NotificationDestination)
    func scheduleWeekendSafetyCheckIns()
    func scheduleWeeklySummary(streak: Int, score: Int)
    func snoozeCurrentCheckIn()
}

extension NotificationService: NotificationScheduling {}

extension NotificationScheduling {
    func scheduleInactivityReminders(from lastUse: Date = .now) {
        scheduleInactivityReminders(from: lastUse)
    }
}

/// Reading from and writing to Apple Health.
///
/// Exactly the members the app reaches for, and no more: a protocol wide enough
/// to cover the whole class would be a second copy of it to keep in step.
@MainActor
protocol HealthReading: Sendable {
    func latestHRV() async throws -> Double?
    func latestHeartRate() async throws -> Double?
    func latestRestingHeartRate() async throws -> Double?
    func requestAuthorization() async throws
    // Two overloads on the concrete type: one asks for everything, one asks for
    // a named set. Both are called, so both are here.
    func requestAuthorization(scopes: Set<HealthKitPermissionScope>) async throws
    func save(_ snapshot: HealthLogSnapshot) async throws
    func saveMindfulMinutes(from startDate: Date, to endDate: Date) async throws
    func saveStateOfMind(date: Date, mood: AftercareMood) async throws
    func sleepHours(from startDate: Date, to endDate: Date) async throws -> Double
    func sleepHoursAfterEntry(startDate: Date) async throws -> Double
}

extension HealthKitService: HealthReading {}

/// What the phone tells the watch.
///
/// Exactly the members the app reaches for, and no more: a protocol wide enough
/// to cover the whole class would be a second copy of it to keep in step.
@MainActor
protocol WatchRelaying: Sendable {
    func activate()
    func sendActiveTimers(_ timers: [DrugDoseTimerRecord])
    func sendLatestHRV(_ ms: Double?)
    func sendLatestHeartRate(_ bpm: Double?)
    func sendMetrics(recoveryStreakDays: Int, dailyScore: Int, dailyScoreActive: Bool)
    func sendSettings()
    func syncStandaloneState()
}

extension WatchConnectivityService: WatchRelaying {}

/// Encrypted backups in the user's own iCloud Drive.
///
/// Exactly the members the app reaches for, and no more: a protocol wide enough
/// to cover the whole class would be a second copy of it to keep in step.
@MainActor
protocol CloudBackups: Sendable {
    func deleteBackups() throws
    var isAvailable: Bool { get }
    func restoreLatestBackup(into context: ModelContext) throws -> ChillMateBackupImportSummary
    func saveLatestBackup(localContext: ModelContext) throws -> Date
    var statusLine: String { get }
}

extension ICloudBackupService: CloudBackups {}

/// Sealing and opening the encrypted archive, and the on-device recovery snapshot.
///
/// Exactly the members the app reaches for, and no more: a protocol wide enough
/// to cover the whole class would be a second copy of it to keep in step.
@MainActor
protocol EncryptedBackups: Sendable {
    func deleteOnDeviceRecoverySnapshot() throws
    func encryptedBackupData(localContext: ModelContext) throws -> Data
    func importEncryptedBackupData(_ data: Data, into context: ModelContext) throws -> ChillMateBackupImportSummary
    func refreshOnDeviceRecoverySnapshot(localContext: ModelContext) throws -> Bool
    func restoreOnDeviceRecoverySnapshotIfNeeded(into context: ModelContext) throws -> ChillMateBackupImportSummary?
}

extension EncryptedBackupService: EncryptedBackups {}

/// What ChillMate offers to Spotlight.
///
/// Exactly the members the app reaches for, and no more: a protocol wide enough
/// to cover the whole class would be a second copy of it to keep in step.
@MainActor
protocol SpotlightIndexing: Sendable {
    func indexJournalEntry(_ entry: JournalEntry)
    func indexTools()
    func removeJournalEntry(_ entry: JournalEntry)
}

extension SpotlightService: SpotlightIndexing {}

/// One location, when the user asks for one.
///
/// Exactly the members the app reaches for, and no more: a protocol wide enough
/// to cover the whole class would be a second copy of it to keep in step.
@MainActor
protocol LocationLookup: Sendable {
    func currentLoggedLocation() async throws -> LoggedLocation
}

extension LocationLookupService: LocationLookup {}

/// The set of services a piece of the app is running against.
///
/// A struct rather than a container with lookups: the members are known at
/// compile time, and something that could be missing at run time is the kind of
/// dependency injection that trades one class of bug for another.
@MainActor
struct Services {
    var notifications: any NotificationScheduling
    var health: any HealthReading
    var watch: any WatchRelaying
    var cloudBackups: any CloudBackups
    var encryptedBackups: any EncryptedBackups
    var spotlight: any SpotlightIndexing
    var location: any LocationLookup

    /// The real ones. The only place in the app where these types are named.
    static let live = Services(
        notifications: NotificationService.shared,
        health: HealthKitService.shared,
        watch: WatchConnectivityService.shared,
        cloudBackups: ICloudBackupService.shared,
        encryptedBackups: EncryptedBackupService.shared,
        spotlight: SpotlightService.shared,
        location: LocationLookupService.shared
    )
}

private struct ServicesKey: @preconcurrency EnvironmentKey {
    @MainActor static var defaultValue: Services { .live }
}

extension EnvironmentValues {
    /// The services this part of the tree is running against.
    ///
    /// Defaults to the real ones, so a view that does not think about it behaves
    /// exactly as it did before the environment existed. That default is the
    /// reason this could be introduced across a hundred and ten call sites
    /// without a flag day.
    var services: Services {
        get { self[ServicesKey.self] }
        set { self[ServicesKey.self] = newValue }
    }
}
