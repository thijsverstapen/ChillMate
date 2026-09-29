import Foundation
import OSLog
import SwiftData

/// Takes back what versions before 5.1.0 wrote into Apple Health beside each
/// night: the substances, whether a condom was used, whether somebody was
/// penetrated, and the note.
///
/// Those rode along as metadata on every sleep and sexual-activity sample, where
/// every app with Health access to sleep could read them, and Health's own export
/// included them. Metadata cannot be edited in place, so each such sample is
/// replaced by a copy with the same type, value and times and none of that, and
/// then deleted. Health looks the same afterwards; the words are gone.
///
/// Runs once per install, from launch. It is safe to stop at any point: copies are
/// written before anything is deleted, and every copy has a sync identifier, so a
/// second run replaces the first run's copies instead of adding to them.
@MainActor
enum HealthLegacyCleanup {
    private static var isRunning = false

    static func runIfNeeded(
        context: ModelContext? = nil,
        services: Services = .live,
        defaults: UserDefaults = .standard
    ) async {
        guard !defaults.bool(forKey: DefaultsKey.healthLegacyMetadataRemoved) else { return }
        // Matching copies to nights needs the real nights, not the decoy store.
        // Waiting a launch costs nothing; the samples are not going anywhere.
        guard !LocalSecurityService.isInDuressMode else { return }
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let context = context ?? ChillMateModelContainer.container().mainContext
        // Only nights that could ever have written a sample.
        let descriptor = FetchDescriptor<NightEntry>(
            predicate: #Predicate<NightEntry> { $0.hadSex || $0.sleptYet }
        )
        let nights = ((try? context.fetch(descriptor)) ?? []).map(HealthLogSnapshot.init(entry:))

        do {
            if try await services.health.removeLegacyMetadata(matching: nights) {
                defaults.set(true, forKey: DefaultsKey.healthLegacyMetadataRemoved)
            }
        } catch {
            // Most often a locked phone. The flag stays unset, so the next launch
            // tries again.
            Logger.data.info("Health metadata cleanup deferred: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// How far apart two times may be and still be the same moment. A night's
    /// times come back out of HealthKit very close to how they went in, but not
    /// always to the last bit.
    nonisolated static let tolerance: TimeInterval = 1

    /// The clean copies to write in place of `legacy`.
    ///
    /// - One copy for each distinct sample. Exact duplicates — the same night
    ///   written twice — become one, which loses nothing.
    /// - A copy that matches what one of `nights` would write today takes that
    ///   night's sync identifier, so saving the night again replaces it rather than
    ///   adding a second one beside it.
    /// - Anything else keeps its times and value under an identifier made from its
    ///   own id: a night since deleted from ChillMate still has its sleep in
    ///   Health, as it did before.
    ///
    /// Deterministic in its input, so a run that was interrupted and starts over
    /// makes the same copies with the same identifiers.
    nonisolated static func copies(
        of legacy: [LegacyHealthSample],
        matching nights: [HealthLogSnapshot]
    ) -> [HealthSampleDraft] {
        let expected = nights.flatMap { HealthKitService.drafts(for: $0, includeSleep: true) }

        func same(_ a: DateInterval, _ b: DateInterval) -> Bool {
            abs(a.start.timeIntervalSince(b.start)) <= tolerance && abs(a.end.timeIntervalSince(b.end)) <= tolerance
        }

        var copies: [HealthSampleDraft] = []
        for sample in legacy.sorted(by: { $0.uuid.uuidString < $1.uuid.uuidString }) {
            let isDuplicate = copies.contains {
                $0.kind == sample.kind && $0.value == sample.value && same($0.interval, sample.interval)
            }
            if isDuplicate { continue }

            let night = expected.first {
                $0.kind == sample.kind && $0.value == sample.value && same($0.interval, sample.interval)
            }
            copies.append(HealthSampleDraft(
                kind: sample.kind,
                interval: sample.interval,
                value: sample.value,
                syncIdentifier: night?.syncIdentifier ?? "legacy-\(sample.uuid.uuidString)"
            ))
        }
        return copies
    }
}
