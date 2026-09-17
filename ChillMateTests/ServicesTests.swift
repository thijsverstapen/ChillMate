import Foundation
import Testing
import ChillMateCore
@testable import ChillMate

/// The seam, exercised.
///
/// Seven singletons were named directly in a hundred and ten places. Renaming
/// them to go through a container would be tidying; what makes it worth doing is
/// that something else can be put in their place, so this puts something else in
/// their place and watches the app talk to it.
@MainActor
@Suite("Services")
struct ServicesTests {

    /// Records what it was told, and does nothing else. In particular it does
    /// not touch WatchConnectivity, which is the point: the real one cannot be
    /// used in a test at all.
    private final class RecordingWatch: WatchRelaying {
        var sentTimers: [[DrugDoseTimerRecord]] = []
        var settingsPushes = 0

        func activate() {}
        func sendActiveTimers(_ timers: [DrugDoseTimerRecord]) { sentTimers.append(timers) }
        func sendSettings() { settingsPushes += 1 }
        func sendMetrics(recoveryStreakDays: Int, dailyScore: Int, dailyScoreActive: Bool) {}
        func sendLatestHeartRate(_ value: Double?) {}
        func sendLatestHRV(_ value: Double?) {}
        func syncStandaloneState() {}
    }

    private func services(watch: RecordingWatch) -> Services {
        var services = Services.live
        services.watch = watch
        return services
    }

    private func timer(_ substance: Substance, hoursAgo: Double = 0) -> DrugDoseTimerRecord {
        DrugDoseTimerRecord(
            substanceName: substance.rawValue,
            startedAt: .now.addingTimeInterval(-hoursAgo * 3600),
            durationHours: 4
        )
    }

    @Test("A broadcast reaches the watch that was handed in")
    func broadcastReachesTheInjectedWatch() throws {
        let watch = RecordingWatch()
        let running = timer(.mdma)
        let defaults = UserDefaults(suiteName: "group.com.codex.ChillMate.tests.services")!
        defaults.removePersistentDomain(forName: "group.com.codex.ChillMate.tests.services")

        ActiveDoseTimer.broadcast([running], services: services(watch: watch), defaults: defaults)

        #expect(watch.sentTimers.count == 1)
        let sent = try #require(watch.sentTimers.first)
        #expect(sent.map(\.substanceName) == [Substance.mdma.rawValue])
    }

    /// Substituting one service leaves the rest alone, which is what makes this
    /// usable: a test replaces the thing it is about and inherits the rest.
    @Test("Replacing one service leaves the others in place")
    func replacingOneLeavesTheRest() {
        let watch = RecordingWatch()
        let services = services(watch: watch)
        #expect(services.watch is RecordingWatch)
        #expect(!(services.notifications is RecordingWatch))
    }

    /// `Services.live` is the only place the concrete types are named, and it
    /// has to name all of them or something still reaches for a global.
    @Test("The live set is complete")
    func liveIsComplete() {
        let services = Services.live
        #expect(services.notifications is NotificationService)
        #expect(services.health is HealthKitService)
        #expect(services.watch is WatchConnectivityService)
        #expect(services.cloudBackups is ICloudBackupService)
        #expect(services.encryptedBackups is EncryptedBackupService)
        #expect(services.spotlight is SpotlightService)
        #expect(services.location is LocationLookupService)
    }
}
