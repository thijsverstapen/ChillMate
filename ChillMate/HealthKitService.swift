import Foundation
import HealthKit
import ChillMateCore

/// What a saved night contributes to Apple Health: when, and whether — nothing else.
///
/// Until 5.1.0 this carried the substances, whether a condom was used, whether
/// somebody was penetrated, and the free-text note, and all of it was written into
/// the metadata of every sleep and sexual-activity sample. HealthKit hands a
/// sample's metadata to every app the person lets read that type, so any sleep
/// tracker, fitness app or insurer's wellness app with sleep access could read
/// "MDMA, GHB" and the note off ChillMate's sleep entries. It also went into
/// Health's own export.
///
/// Those fields are gone from this type rather than merely unused, so the leak
/// cannot come back by somebody adding a key to a dictionary. Anything added here
/// is something every app with Health access to that type can see.
struct HealthLogSnapshot: Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let hadSex: Bool
    let skippedNight: Bool
    let sleptYet: Bool
    let sleepHours: Double

    init(entry: NightEntry) {
        id = entry.id
        startDate = entry.startDate
        endDate = entry.endDate
        hadSex = entry.hadSex
        skippedNight = entry.skippedNight
        sleptYet = entry.sleptYet
        sleepHours = entry.sleepHours
    }

    init(id: UUID, startDate: Date, endDate: Date, hadSex: Bool, skippedNight: Bool, sleptYet: Bool, sleepHours: Double) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.hadSex = hadSex
        self.skippedNight = skippedNight
        self.sleptYet = sleptYet
        self.sleepHours = sleepHours
    }
}

@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    private init() {}

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Types

    nonisolated static var sexualActivityType: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .sexualActivity) }
    nonisolated static var sleepAnalysisType: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .sleepAnalysis) }
    nonisolated static var heartRateType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .heartRate) }
    nonisolated static var restingHeartRateType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .restingHeartRate) }
    nonisolated static var mindfulSessionType: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .mindfulSession) }
    nonisolated static var heartRateVariabilityType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) }

    // MARK: - Authorization

    /// What each scope asks iOS for, and nothing beyond it.
    ///
    /// Heart rate and HRV used to be requested for writing as well as reading, and
    /// workouts for both, so the system sheet asked to let ChillMate *write* heart
    /// rate and workouts it never writes. Breathing rate was requested and never
    /// read by anything. A privacy app asking for more than it uses is the one
    /// thing it cannot afford, and App Review checks for it too.
    ///
    /// Resting heart rate rides with heart rate. It had a scope of its own that no
    /// switch in Settings could turn on, so the dashboard's read of it asked iOS
    /// for access nobody had been shown.
    ///
    /// Static and pure so the tests can hold every scope to exactly this.
    nonisolated static func authorizationTypes(
        for scopes: Set<HealthKitPermissionScope>
    ) -> (share: Set<HKSampleType>, read: Set<HKObjectType>) {
        var share = Set<HKSampleType>()
        var read = Set<HKObjectType>()

        if scopes.contains(.sexualActivityWrite), let type = sexualActivityType {
            share.insert(type)
        }
        if scopes.contains(.sleepReadWrite), let type = sleepAnalysisType {
            share.insert(type)
            read.insert(type)
        }
        if scopes.contains(.heartRateRead) {
            if let type = heartRateType { read.insert(type) }
            if let type = restingHeartRateType { read.insert(type) }
        }
        if scopes.contains(.heartRateVariabilityRead), let type = heartRateVariabilityType {
            read.insert(type)
        }
        if scopes.contains(.mindfulWrite), let type = mindfulSessionType {
            share.insert(type)
        }
        return (share, read)
    }

    func requestAuthorization() async throws {
        try await requestAuthorization(scopes: [.sexualActivityWrite, .sleepReadWrite])
    }

    func requestAuthorization(scopes: Set<HealthKitPermissionScope>) async throws {
        guard isAvailable else {
            throw HealthKitError.unavailable
        }

        let types = Self.authorizationTypes(for: scopes)
        guard !types.share.isEmpty || !types.read.isEmpty else {
            throw HealthKitError.missingTypes
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: types.share, read: types.read) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.authorizationDenied)
                }
            }
        }
    }

    /// Whether ChillMate may write this type. Unlike reading, write access is
    /// something HealthKit will say out loud.
    func canWrite(_ type: HKObjectType) -> Bool {
        store.authorizationStatus(for: type) == .sharingAuthorized
    }

    // MARK: - State of Mind

    /// Mirrors an aftercare mood into Apple Health as a State of Mind sample
    /// (momentary emotion, associated with health). Requests share authorization
    /// on first use; callers gate on the user's Apple Health sync setting.
    ///
    /// Carries a valence and a label and nothing from the night itself.
    func saveStateOfMind(date: Date, mood: AftercareMood) async throws {
        guard isAvailable else {
            throw HealthKitError.unavailable
        }

        let type = HKSampleType.stateOfMindType()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: [type], read: []) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.authorizationDenied)
                }
            }
        }

        let mapping = Self.stateOfMindMapping(for: mood)
        let sample = HKStateOfMind(
            date: date,
            kind: .momentaryEmotion,
            valence: mapping.valence,
            labels: [mapping.label],
            associations: [.health]
        )
        try await store.save(sample)
    }

    private static func stateOfMindMapping(for mood: AftercareMood) -> (valence: Double, label: HKStateOfMind.Label) {
        switch mood {
        case .grounded: (0.6, .calm)
        case .okay: (0.25, .content)
        case .tender: (0.0, .sad)
        case .anxious: (-0.4, .anxious)
        case .low: (-0.6, .sad)
        case .overwhelmed: (-0.7, .overwhelmed)
        }
    }

    // MARK: - Sleep

    /// Read only: asking for sleep to show it should not also ask to write it.
    func requestSleepReadAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.unavailable }
        guard let sleepAnalysisType = Self.sleepAnalysisType else { throw HealthKitError.missingTypes }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: [], read: [sleepAnalysisType]) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.authorizationDenied)
                }
            }
        }
    }

    /// Every recorded asleep interval that touches `window`, from every source or
    /// from every source except ChillMate.
    ///
    /// Intervals rather than a total, so the caller can count each moment once:
    /// see `SleepFill.asleepDuration`.
    func asleepIntervals(in window: DateInterval, excludingOwnSamples: Bool = false) async throws -> [DateInterval] {
        guard isAvailable else { throw HealthKitError.unavailable }
        guard let sleepAnalysisType = Self.sleepAnalysisType else { throw HealthKitError.missingTypes }

        // Anything overlapping the window, not only what starts inside it: a sleep
        // that began just before the window still ended inside it.
        var predicate: NSPredicate = HKQuery.predicateForSamples(withStart: window.start, end: window.end, options: [])
        if excludingOwnSamples {
            let own = HKQuery.predicateForObjects(from: HKSource.default())
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                predicate, NSCompoundPredicate(notPredicateWithSubpredicate: own)
            ])
        }

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepAnalysisType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
                }
            }
            store.execute(query)
        }

        let asleep: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        return samples
            .filter { asleep.contains($0.value) && $0.endDate > $0.startDate }
            .map { DateInterval(start: $0.startDate, end: $0.endDate) }
    }

    /// Hours asleep between two moments, each moment counted once however many
    /// devices recorded it.
    ///
    /// This used to add up every sample from every source, so a night recorded by
    /// a watch and a sleep app read as twice as long as it was.
    func sleepHours(from startDate: Date, to endDate: Date) async throws -> Double {
        try await requestSleepReadAuthorization()
        let window = DateInterval(start: startDate, end: max(startDate, endDate))
        let intervals = try await asleepIntervals(in: window)
        return SleepFill.asleepDuration(of: intervals, within: window) / 3600
    }

    // MARK: - Heart

    func latestHRV() async throws -> Double? {
        guard isAvailable, let hrvType = Self.heartRateVariabilityType else { return nil }
        try await requestAuthorization(scopes: [.heartRateVariabilityRead])
        return try await latestQuantity(hrvType, unit: HKUnit.secondUnit(with: .milli))
    }

    func latestHeartRate() async throws -> Double? {
        guard isAvailable, let hrType = Self.heartRateType else { return nil }
        try await requestAuthorization(scopes: [.heartRateRead])
        return try await latestQuantity(hrType, unit: HKUnit(from: "count/min"))
    }

    /// Resting heart rate is a steadier recovery signal than a spot heart-rate
    /// reading, because Apple Health derives it across a whole day.
    func latestRestingHeartRate() async throws -> Double? {
        guard isAvailable, let type = Self.restingHeartRateType else { return nil }
        try await requestAuthorization(scopes: [.heartRateRead])
        return try await latestQuantity(type, unit: HKUnit(from: "count/min"))
    }

    private func latestQuantity(_ type: HKQuantityType, unit: HKUnit) async throws -> Double? {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    // MARK: - Writing

    /// Records a completed breathing session as mindful minutes. Called from panic
    /// support, so the time someone spent calming down counts for something outside
    /// ChillMate too. Silent on failure: the session already happened either way.
    func saveMindfulMinutes(from startDate: Date, to endDate: Date) async throws {
        guard isAvailable, let mindfulSessionType = Self.mindfulSessionType, endDate > startDate else { return }
        try await requestAuthorization(scopes: [.mindfulWrite])

        let sample = HKCategorySample(
            type: mindfulSessionType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: startDate,
            end: endDate
        )
        try await store.save(sample)
    }

    /// Writes a saved night to Apple Health.
    ///
    /// - Parameter sleepReadAllowed: whether the person lets ChillMate read sleep.
    ///   When they do, a sleep sample is written only if Health has no sleep from
    ///   another source for that night. Somebody whose watch records sleep already
    ///   has it in Health, and ChillMate's copy would sit beside the watch's as a
    ///   second record of the same hours. Somebody with nothing recording sleep
    ///   still gets the figure they typed. Without read access the check cannot be
    ///   made, so the typed figure is written as before.
    func save(_ snapshot: HealthLogSnapshot, sleepReadAllowed: Bool) async throws {
        guard isAvailable else {
            throw HealthKitError.unavailable
        }

        try await requestAuthorization()

        var includeSleep = true
        if sleepReadAllowed, snapshot.sleptYet, snapshot.sleepHours > 0 {
            let window = SleepFill.window(forNightEndingAt: snapshot.endDate)
            let others = try await asleepIntervals(in: window, excludingOwnSamples: true)
            includeSleep = SleepFill.asleepDuration(of: others, within: window) == 0
        }

        let drafts = Self.drafts(for: snapshot, includeSleep: includeSleep)
        let version = Date.now
        if !drafts.isEmpty {
            try await store.save(drafts.compactMap { Self.sample(from: $0, version: version) })
        }

        // Whatever this night no longer is, take back out of Health: a night saved
        // again without sex, or whose sleep a device has since recorded. Only this
        // night's own samples can match, by their sync identifier.
        let written = Set(drafts.map(\.kind))
        for kind in HealthSampleKind.allCases where !written.contains(kind) {
            _ = try? await deleteOwnSamples(of: kind, syncIdentifiers: [kind.syncIdentifier(for: snapshot.id)])
        }
    }

    /// What a night becomes in Health, before it becomes HealthKit objects. Static
    /// and pure so the tests can inspect everything that will be written.
    nonisolated static func drafts(for snapshot: HealthLogSnapshot, includeSleep: Bool) -> [HealthSampleDraft] {
        var drafts: [HealthSampleDraft] = []

        if snapshot.hadSex, !snapshot.skippedNight {
            drafts.append(HealthSampleDraft(
                kind: .sexualActivity,
                interval: DateInterval(
                    start: snapshot.startDate,
                    end: max(snapshot.endDate, snapshot.startDate.addingTimeInterval(60))
                ),
                value: HKCategoryValue.notApplicable.rawValue,
                syncIdentifier: HealthSampleKind.sexualActivity.syncIdentifier(for: snapshot.id)
            ))
        }

        if includeSleep, snapshot.sleptYet, snapshot.sleepHours > 0 {
            let end = snapshot.endDate
            drafts.append(HealthSampleDraft(
                kind: .sleep,
                interval: DateInterval(start: end.addingTimeInterval(-(snapshot.sleepHours * 60 * 60)), end: end),
                value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                syncIdentifier: HealthSampleKind.sleep.syncIdentifier(for: snapshot.id)
            ))
        }

        return drafts
    }

    /// The only metadata ChillMate writes is Apple's own, and none of it is about
    /// the night:
    ///
    /// - `WasUserEntered`, because every one of these was typed by the person, not
    ///   measured, and other apps should be able to tell.
    /// - A sync identifier built from the night's random id, and a version. Saving
    ///   the same night again replaces its sample instead of adding a second one.
    nonisolated static func metadata(for draft: HealthSampleDraft, version: Date) -> [String: Any] {
        [
            HKMetadataKeyWasUserEntered: true,
            HKMetadataKeySyncIdentifier: draft.syncIdentifier,
            // Must rise on every save for Health to replace the previous sample;
            // the save time, in milliseconds, always does.
            HKMetadataKeySyncVersion: Int(version.timeIntervalSince1970 * 1000)
        ]
    }

    nonisolated static func sample(from draft: HealthSampleDraft, version: Date) -> HKCategorySample? {
        guard let type = draft.kind.categoryType else { return nil }
        return HKCategorySample(
            type: type,
            value: draft.value,
            start: draft.interval.start,
            end: draft.interval.end,
            metadata: metadata(for: draft, version: version)
        )
    }

    private func deleteOwnSamples(of kind: HealthSampleKind, syncIdentifiers: [String]) async throws -> Int {
        guard let type = kind.categoryType, !syncIdentifiers.isEmpty else { return 0 }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForObjects(from: HKSource.default()),
            HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: syncIdentifiers)
        ])
        return try await delete(type, matching: predicate)
    }

    private func delete(_ type: HKObjectType, matching predicate: NSPredicate) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            store.deleteObjects(of: type, predicate: predicate) { _, count, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: count)
                }
            }
        }
    }

    // MARK: - Removing what earlier versions wrote

    /// A key every sample written before 5.1.0 carries, and nothing since does.
    ///
    /// Earlier versions wrote five custom keys on every sample, always all five, so
    /// any one of them identifies exactly those samples and nothing else.
    nonisolated static let legacyMetadataKey = "ChillMateSubstances"

    /// Replaces every sample an earlier version wrote with a copy that carries
    /// nothing about the night, and reports whether none are left.
    ///
    /// Copies first, deletes second, and every copy has a sync identifier, so being
    /// stopped halfway loses nothing and running again cannot duplicate anything.
    /// A kind ChillMate may no longer write is left as it is, since it could
    /// neither copy nor delete it; the person can still delete everything ChillMate
    /// wrote from the Health app, where ChillMate is listed among their apps.
    ///
    /// HealthKit only lets an app delete samples it wrote itself, and the predicate
    /// says so as well, so this cannot touch anything a watch, the phone or another
    /// app recorded.
    func removeLegacyMetadata(matching nights: [HealthLogSnapshot]) async throws -> Bool {
        guard isAvailable else { return false }

        var remaining = false
        for kind in HealthSampleKind.allCases {
            guard let type = kind.categoryType else { continue }
            // Never allowed to write means ChillMate never wrote any.
            if store.authorizationStatus(for: type) == .notDetermined { continue }

            let legacy = try await legacyTaggedSamples(of: kind)
            guard !legacy.isEmpty else { continue }
            guard canWrite(type) else {
                remaining = true
                continue
            }

            let copies = HealthLegacyCleanup.copies(of: legacy, matching: nights)
            let version = Date.now
            try await store.save(copies.compactMap { Self.sample(from: $0, version: version) })
            _ = try await delete(type, matching: Self.ownLegacyPredicate)
        }
        return !remaining
    }

    private static var ownLegacyPredicate: NSPredicate {
        NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForObjects(from: HKSource.default()),
            HKQuery.predicateForObjects(withMetadataKey: legacyMetadataKey)
        ])
    }

    private func legacyTaggedSamples(of kind: HealthSampleKind) async throws -> [LegacyHealthSample] {
        guard let type = kind.categoryType else { return [] }
        // An app always sees the samples it wrote itself, whether or not it may
        // read that type, so this works for sexual activity too.
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: Self.ownLegacyPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
                }
            }
            store.execute(query)
        }
        return samples.map {
            LegacyHealthSample(
                uuid: $0.uuid,
                kind: kind,
                interval: DateInterval(start: $0.startDate, end: max($0.startDate, $0.endDate)),
                value: $0.value
            )
        }
    }
}

/// The two kinds of sample a night becomes.
enum HealthSampleKind: String, CaseIterable, Sendable {
    case sexualActivity = "sexual-activity"
    case sleep

    var categoryType: HKCategoryType? {
        switch self {
        case .sexualActivity: HealthKitService.sexualActivityType
        case .sleep: HealthKitService.sleepAnalysisType
        }
    }

    /// Built from the night's random id and nothing else, so it says nothing about
    /// the night to an app that reads it.
    func syncIdentifier(for night: UUID) -> String {
        "\(night.uuidString)-\(rawValue)"
    }
}

/// One sample ChillMate is about to write, before it becomes an `HKCategorySample`.
///
/// There is deliberately nowhere on this to put anything about the night.
struct HealthSampleDraft: Equatable, Sendable {
    let kind: HealthSampleKind
    let interval: DateInterval
    let value: Int
    let syncIdentifier: String
}

/// A sample an earlier version wrote, reduced to what a clean copy of it needs.
struct LegacyHealthSample: Equatable, Sendable {
    let uuid: UUID
    let kind: HealthSampleKind
    let interval: DateInterval
    let value: Int
}

enum HealthKitPermissionScope: String, CaseIterable, Identifiable {
    // Raw values are what Settings shows. They used to say "read/write" on scopes
    // that only wrote and on scopes that only read; each now names the data, and
    // the caption says what ChillMate does with it.
    //
    // Workouts and breathing rate are gone. Both were requested — workouts for
    // writing as well as reading — and neither was ever used.
    case sexualActivityWrite = "Sexual activity"
    case sleepReadWrite = "Sleep"
    case heartRateRead = "Heart rate"
    case heartRateVariabilityRead = "Heart rate variability"
    case mindfulWrite = "Mindful minutes"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .sexualActivityWrite: "heart.text.square.fill"
        case .sleepReadWrite: "bed.double.fill"
        case .heartRateRead: "heart.fill"
        case .heartRateVariabilityRead: "waveform.path.ecg"
        case .mindfulWrite: "brain.head.profile"
        }
    }

    /// What ChillMate does with the data, and nothing it might do one day.
    ///
    /// Two of these used to promise features that did not exist ("prepare HRV as a
    /// future recovery-score input", "use workout context later"), which is asking
    /// for health data on the strength of a reason that is not yet true.
    var caption: String {
        switch self {
        case .sexualActivityWrite:
            String(localized: "Writes when it happened, from nights you save. Nothing else about the night.")
        case .sleepReadWrite:
            String(localized: "Reads your sleep to fill in how long you slept after a night. Writes sleep you type in only when Apple Health has none for that night.")
        case .heartRateRead:
            String(localized: "Reads your heart rate for your Apple Watch, and your resting heart rate to show beside your recovery score.")
        case .heartRateVariabilityRead:
            String(localized: "Reads heart rate variability, which is part of your daily recovery score.")
        case .mindfulWrite:
            String(localized: "Writes breathing sessions of a minute or longer from panic support as mindful minutes.")
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
            String(localized: "Apple Health is not available on this device.")
        case .missingTypes:
            String(localized: "ChillMate could not find the Apple Health types it needs.")
        case .authorizationDenied:
            String(localized: "Apple Health permission was not granted.")
        case .saveFailed:
            String(localized: "ChillMate could not save the log to Apple Health.")
        }
    }
}

/// Conformance declared here rather than beside the protocol: `HealthReading`
/// inherits `Sendable`, and Swift treats a Sendable conformance in another
/// file as retroactive — a warning today and an error in a future language
/// mode.
extension HealthKitService: HealthReading {}
