import Foundation
import OSLog
import SwiftData
import ChillMateCore

/// Fills in how long somebody slept after a night, from what Apple Health
/// recorded, so they do not have to type it.
///
/// Runs when the app opens or comes back to the front, and right after a night is
/// saved. Every rule about *whether* to write lives in `SleepFill.decide`, which is
/// tested on its own; this is only the reading and the writing.
///
/// Three things it never does:
///
/// - Overwrite a night that already has sleep. A figure the person typed, or one
///   aftercare already imported, is theirs.
/// - Count ChillMate's own sleep samples. Those are figures somebody typed, not
///   sleep a device measured, and one night's typed sleep can overlap the next.
/// - Ask for permission. It runs only for somebody who turned sleep on in Settings,
///   and a read HealthKit has not allowed simply comes back empty.
@MainActor
enum SleepBackfill {
    private static var isRunning = false

    /// - Returns: how many nights it filled.
    @discardableResult
    static func run(
        context: ModelContext? = nil,
        services: Services = .live,
        defaults: UserDefaults = .standard,
        now: Date = .now
    ) async -> Int {
        guard defaults.bool(forKey: DefaultsKey.healthKitSleepReadWriteEnabled) else { return 0 }
        // The decoy store has nothing to fill, and nothing here should read Health
        // on behalf of a store somebody is being shown under duress.
        guard !LocalSecurityService.isInDuressMode else { return 0 }
        // Launch and becoming active arrive together; one pass is enough.
        guard !isRunning else { return 0 }
        isRunning = true
        defer { isRunning = false }

        let context = context ?? ChillMateModelContainer.container().mainContext
        let nights = candidates(in: context, now: now)
        guard !nights.isEmpty else { return 0 }

        var filled: [(night: NightEntry, hours: Double)] = []
        for night in nights {
            let window = SleepFill.window(forNightEndingAt: night.endDate)
            let intervals: [DateInterval]
            do {
                intervals = try await services.health.asleepIntervals(in: window, excludingOwnSamples: true)
            } catch {
                // Most often the phone is locked and Health's store is sealed. The
                // next time the app is opened it will be unlocked.
                Logger.data.info("Sleep backfill could not read Health: \(error.localizedDescription, privacy: .public)")
                break
            }

            // Re-checked after the await: the person may have typed a figure into
            // this night while Health was being read.
            let decision = SleepFill.decide(
                nightEnd: night.endDate,
                alreadyHasSleep: night.sleptYet,
                skipped: night.skippedNight,
                intervals: intervals,
                now: now
            )
            if case .record(let hours) = decision {
                let rounded = (hours * 10).rounded() / 10
                night.sleptYet = true
                night.sleepHours = rounded
                filled.append((night, rounded))
            }
        }

        guard !filled.isEmpty else { return 0 }
        context.saveChanges()

        // The same nudge the log sheet sent when it found sleep, once per pass and
        // for the most recent night, not once for every night filled at once.
        if let latest = filled.max(by: { $0.night.endDate < $1.night.endDate }),
           latest.hours >= 7,
           defaults.bool(forKey: DefaultsKey.notificationsEnabled) {
            services.notifications.schedulePositiveSleepNotification(hours: latest.hours)
        }
        return filled.count
    }

    /// Nights that could still need sleep: recent, not skipped, and without a
    /// figure. Bounded by the lookback, so the fetch never grows with history.
    private static func candidates(in context: ModelContext, now: Date) -> [NightEntry] {
        let cutoff = now.addingTimeInterval(-SleepFill.lookback)
        let descriptor = FetchDescriptor<NightEntry>(
            predicate: #Predicate<NightEntry> { night in
                night.endDate >= cutoff && night.sleptYet == false && night.skippedNight == false
            },
            sortBy: [SortDescriptor(\.endDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
