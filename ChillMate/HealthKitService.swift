import Foundation
import HealthKit

struct HealthLogSnapshot: Sendable {
    let date: Date
    let startDate: Date
    let endDate: Date
    let hadSex: Bool
    let usedCondom: Bool
    let wasPenetrated: Bool
    let skippedNight: Bool
    let substances: [String]
    let sleptYet: Bool
    let sleepHours: Double
    let note: String

    init(entry: NightEntry) {
        date = entry.date
        startDate = entry.startDate
        endDate = entry.endDate
        hadSex = entry.hadSex
        usedCondom = entry.usedCondom
        wasPenetrated = entry.wasPenetrated
        skippedNight = entry.skippedNight
        substances = entry.substances
        sleptYet = entry.sleptYet
        sleepHours = entry.sleepHours
        note = entry.note
    }
}

@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    private var sexualActivityType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .sexualActivity)
    }

    private var sleepAnalysisType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
    }

    private var heartRateType: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .heartRate)
    }

    private var heartRateVariabilityType: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
    }

    private init() {}

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        try await requestAuthorization(scopes: [.sexualActivityWrite, .sleepReadWrite])
    }

    func requestAuthorization(scopes: Set<HealthKitPermissionScope>) async throws {
        guard isAvailable else {
            throw HealthKitError.unavailable
        }

        var shareTypes = Set<HKSampleType>()
        var readTypes = Set<HKObjectType>()

        if scopes.contains(.sexualActivityWrite), let sexualActivityType {
            shareTypes.insert(sexualActivityType)
        }

        if scopes.contains(.sleepReadWrite), let sleepAnalysisType {
            shareTypes.insert(sleepAnalysisType)
            readTypes.insert(sleepAnalysisType)
        }

        if scopes.contains(.heartRateRead), let heartRateType {
            shareTypes.insert(heartRateType)
            readTypes.insert(heartRateType)
        }

        if scopes.contains(.heartRateVariabilityRead), let heartRateVariabilityType {
            shareTypes.insert(heartRateVariabilityType)
            readTypes.insert(heartRateVariabilityType)
        }

        if scopes.contains(.workoutRead) {
            shareTypes.insert(HKObjectType.workoutType())
            readTypes.insert(HKObjectType.workoutType())
        }

        guard !shareTypes.isEmpty || !readTypes.isEmpty else {
            throw HealthKitError.missingTypes
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.authorizationDenied)
                }
            }
        }
    }

    func requestSleepReadAuthorization() async throws {
        guard isAvailable else {
            throw HealthKitError.unavailable
        }

        guard let sleepAnalysisType else {
            throw HealthKitError.missingTypes
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: [], read: [sleepAnalysisType]) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.authorizationDenied)
                }
            }
        }
    }

    func sleepHours(from startDate: Date, to endDate: Date) async throws -> Double {
        guard isAvailable else {
            throw HealthKitError.unavailable
        }

        guard let sleepAnalysisType else {
            throw HealthKitError.missingTypes
        }

        try await requestSleepReadAuthorization()

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate]
        )

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepAnalysisType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }

            store.execute(query)
        }

        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]

        let seconds = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0) { partialResult, sample in
                partialResult + sample.endDate.timeIntervalSince(sample.startDate)
            }

        return seconds / 3600
    }

    func latestHRV() async throws -> Double? {
        guard isAvailable, let hrvType = heartRateVariabilityType else {
            return nil
        }

        try await requestAuthorization(scopes: [.heartRateVariabilityRead])

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let sdnn = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                continuation.resume(returning: sdnn)
            }
            store.execute(query)
        }
    }

    func latestHeartRate() async throws -> Double? {
        guard isAvailable, let hrType = heartRateType else {
            return nil
        }

        try await requestAuthorization(scopes: [.heartRateRead])

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let bpm = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: bpm)
            }
            store.execute(query)
        }
    }

    func sleepHoursAfterEntry(startDate: Date) async throws -> Double {
        let windowEnd = startDate.addingTimeInterval(16 * 60 * 60)
        return try await sleepHours(from: startDate, to: windowEnd)
    }

    func save(_ snapshot: HealthLogSnapshot) async throws {
        guard isAvailable else {
            throw HealthKitError.unavailable
        }

        try await requestAuthorization()

        let samples = makeSamples(from: snapshot)
        guard !samples.isEmpty else {
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.save(samples) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.saveFailed)
                }
            }
        }
    }

    private func makeSamples(from snapshot: HealthLogSnapshot) -> [HKSample] {
        var samples: [HKSample] = []
        let metadata = metadata(for: snapshot)

        if snapshot.hadSex, !snapshot.skippedNight, let sexualActivityType {
            let sample = HKCategorySample(
                type: sexualActivityType,
                value: HKCategoryValue.notApplicable.rawValue,
                start: snapshot.startDate,
                end: max(snapshot.endDate, snapshot.startDate.addingTimeInterval(60)),
                metadata: metadata
            )
            samples.append(sample)
        }

        if snapshot.sleptYet, snapshot.sleepHours > 0, let sleepAnalysisType {
            let endDate = snapshot.endDate
            let startDate = endDate.addingTimeInterval(-(snapshot.sleepHours * 60 * 60))
            let sample = HKCategorySample(
                type: sleepAnalysisType,
                value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                start: startDate,
                end: endDate,
                metadata: metadata
            )
            samples.append(sample)
        }

        return samples
    }

    private func metadata(for snapshot: HealthLogSnapshot) -> [String: Any] {
        [
            "ChillMateSubstances": snapshot.substances.joined(separator: ", "),
            "ChillMateUsedCondom": snapshot.usedCondom,
            "ChillMateWasPenetrated": snapshot.wasPenetrated,
            "ChillMateSkippedNight": snapshot.skippedNight,
            "ChillMateNote": snapshot.note
        ]
    }
}

enum HealthKitPermissionScope: String, CaseIterable, Identifiable {
    case sexualActivityWrite = "Sexual activity read/write"
    case sleepReadWrite = "Sleep read/write"
    case heartRateRead = "Heart rate read/write"
    case heartRateVariabilityRead = "HRV read/write"
    case workoutRead = "Workout read/write"

    var id: String { rawValue }

    var storageKey: String {
        switch self {
        case .sexualActivityWrite:
            "healthKitSexualActivityWriteEnabled"
        case .sleepReadWrite:
            "healthKitSleepReadWriteEnabled"
        case .heartRateRead:
            "healthKitHeartRateReadEnabled"
        case .heartRateVariabilityRead:
            "healthKitHRVReadEnabled"
        case .workoutRead:
            "healthKitWorkoutReadEnabled"
        }
    }

    var symbolName: String {
        switch self {
        case .sexualActivityWrite:
            "heart.text.square.fill"
        case .sleepReadWrite:
            "bed.double.fill"
        case .heartRateRead:
            "heart.fill"
        case .heartRateVariabilityRead:
            "waveform.path.ecg"
        case .workoutRead:
            "figure.run"
        }
    }

    var caption: String {
        switch self {
        case .sexualActivityWrite:
            "Use Apple Health sexual activity access for Chill log export."
        case .sleepReadWrite:
            "Read sleep for aftercare and write sleep from saved logs."
        case .heartRateRead:
            "Prepare heart-rate signals for safer check-ins and Watch support."
        case .heartRateVariabilityRead:
            "Prepare HRV as a future recovery-score input."
        case .workoutRead:
            "Use workout context later to avoid false stress alerts."
        }
    }
}

enum HealthKitError: LocalizedError {
    case unavailable
    case missingTypes
    case authorizationDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Apple Health is not available on this device."
        case .missingTypes:
            "ChillMate could not find the Apple Health types it needs."
        case .authorizationDenied:
            "Apple Health permission was not granted."
        case .saveFailed:
            "ChillMate could not save the log to Apple Health."
        }
    }
}
