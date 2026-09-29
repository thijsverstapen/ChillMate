import Foundation
import HealthKit

/// Heart rate from this watch's own sensor, while the app is open.
///
/// The phone used to relay its most recent Apple Health sample, which it read
/// only when its Home screen appeared, so the watch showed what the heart had
/// been doing whenever the phone app was last opened. The watch has the sensor,
/// so it reads it: the newest sample from the last few minutes, and each new one
/// as the watch records it. Nothing is stored or sent anywhere.
@MainActor
final class WatchHeartRateReader: ObservableObject {
    @Published private(set) var latest: HealthSample?

    private let store = HKHealthStore()
    private var task: Task<Void, Never>?

    /// Starts reading. Asks for permission the first time; a person who says no
    /// simply gets no heart-rate card.
    func start() {
        guard task == nil, HKHealthStore.isHealthDataAvailable() else { return }
        let heartRate = HKQuantityType(.heartRate)
        let store = store
        task = Task { [weak self] in
            do {
                try await store.requestAuthorization(toShare: [], read: [heartRate])
            } catch {
                return
            }
            // Only samples recent enough to be shown as now. Older ones would be
            // dropped by `WatchLogic.isCurrent` anyway.
            let since = Date.now.addingTimeInterval(-WatchLogic.readingIsCurrentFor)
            let descriptor = HKAnchoredObjectQueryDescriptor(
                predicates: [.quantitySample(type: heartRate, predicate: HKQuery.predicateForSamples(withStart: since, end: nil))],
                anchor: nil
            )
            let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())
            do {
                for try await update in descriptor.results(for: store) {
                    guard let sample = update.addedSamples.max(by: { $0.endDate < $1.endDate }) else { continue }
                    let reading = HealthSample(value: sample.quantity.doubleValue(for: beatsPerMinute), date: sample.endDate)
                    guard let self else { return }
                    if let current = self.latest, current.date >= reading.date { continue }
                    self.latest = reading
                }
            } catch {
                // The query ends when the task is cancelled; nothing to report.
            }
        }
    }

    /// Stops reading, when the app leaves the screen or warnings are switched off.
    func stop() {
        task?.cancel()
        task = nil
    }
}
