import Foundation
import HealthKit
import SwiftData
import Testing
import ChillMateCore
@testable import ChillMate

/// What ChillMate puts into Apple Health, and what it asks for.
///
/// Until 5.1.0 every sleep and sexual-activity sample carried the night's
/// substances, condom use, penetration and free-text note as metadata, where any
/// app with read access to that type could read them. These pin the replacement
/// from the outside: build a night full of exactly those details, turn it into
/// the samples that would be saved, and look at every key and every value.
@MainActor
@Suite("Apple Health writing")
struct HealthKitWritingTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            NightEntry.self,
            LoggedSubstanceRecord.self,
            PartnerDetailRecord.self,
            TriggerTagRecord.self
        ])
        return ModelContext(try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        ))
    }

    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    /// A night carrying every detail that used to leak, each spelled so it would
    /// be recognisable anywhere it turned up.
    private func revealingNight(in context: ModelContext) -> NightEntry {
        let night = NightEntry(
            date: start,
            startDate: start,
            endDate: start.addingTimeInterval(6 * 3600),
            hadSex: true,
            usedCondom: true,
            wasPenetrated: true,
            skippedNight: false,
            substances: [Substance.mdma.rawValue, Substance.ghb.rawValue],
            sleptYet: true,
            sleepHours: 7,
            note: "PRIVATE-NOTE-SENTINEL"
        )
        context.insert(night)
        return night
    }

    private static let appleKeys: Set<String> = [
        HKMetadataKeyWasUserEntered,
        HKMetadataKeySyncIdentifier,
        HKMetadataKeySyncVersion
    ]

    @Test("A saved night carries Apple's keys and nothing else")
    func onlyAppleMetadata() throws {
        let context = try makeContext()
        let night = revealingNight(in: context)
        let drafts = HealthKitService.drafts(for: HealthLogSnapshot(entry: night), includeSleep: true)
        let samples = drafts.compactMap { HealthKitService.sample(from: $0, version: .now) }

        #expect(samples.count == 2)
        for sample in samples {
            let metadata = try #require(sample.metadata)
            #expect(Set(metadata.keys) == Self.appleKeys)
            #expect(metadata[HealthKitService.legacyMetadataKey] == nil)
        }
    }

    /// The keys are the obvious check; this is the thorough one. Nothing that was
    /// typed about the night appears in any value, under any key.
    @Test("No detail of the night appears anywhere in what is written")
    func nothingOfTheNightLeaks() throws {
        let context = try makeContext()
        let night = revealingNight(in: context)
        let drafts = HealthKitService.drafts(for: HealthLogSnapshot(entry: night), includeSleep: true)
        let written = drafts
            .compactMap { HealthKitService.sample(from: $0, version: .now) }
            .flatMap { ($0.metadata ?? [:]).values.map { "\($0)" } }
            .joined(separator: "|")

        for revealing in ["PRIVATE-NOTE-SENTINEL", Substance.mdma.rawValue, Substance.ghb.rawValue] {
            #expect(!written.contains(revealing), "\(revealing) reached Apple Health")
        }
    }

    /// Saving the same night twice replaces its sample, because both saves share
    /// an identifier. Built from the night's random id and nothing else.
    @Test("Each kind of sample has one stable identifier per night")
    func syncIdentifiersAreStable() throws {
        let context = try makeContext()
        let night = revealingNight(in: context)
        let first = HealthKitService.drafts(for: HealthLogSnapshot(entry: night), includeSleep: true)
        let again = HealthKitService.drafts(for: HealthLogSnapshot(entry: night), includeSleep: true)

        #expect(first.map(\.syncIdentifier) == again.map(\.syncIdentifier))
        #expect(Set(first.map(\.syncIdentifier)) == [
            "\(night.id.uuidString)-sexual-activity",
            "\(night.id.uuidString)-sleep"
        ])
    }

    @Test("Sleep is left out when Health already has it from somewhere else")
    func sleepCanBeLeftOut() throws {
        let context = try makeContext()
        let night = revealingNight(in: context)
        let drafts = HealthKitService.drafts(for: HealthLogSnapshot(entry: night), includeSleep: false)
        #expect(drafts.map(\.kind) == [.sexualActivity])
    }

    @Test("A skipped night writes no sexual activity")
    func skippedNightWritesNoSex() throws {
        let context = try makeContext()
        let night = revealingNight(in: context)
        night.skippedNight = true
        let drafts = HealthKitService.drafts(for: HealthLogSnapshot(entry: night), includeSleep: true)
        #expect(!drafts.contains { $0.kind == .sexualActivity })
    }

    @Test("A later version is always higher, so Health keeps the newest save")
    func versionRises() throws {
        let context = try makeContext()
        let night = revealingNight(in: context)
        let draft = try #require(HealthKitService.drafts(for: HealthLogSnapshot(entry: night), includeSleep: true).first)
        let earlier = HealthKitService.metadata(for: draft, version: start)[HKMetadataKeySyncVersion] as? Int
        let later = HealthKitService.metadata(for: draft, version: start.addingTimeInterval(1))[HKMetadataKeySyncVersion] as? Int
        #expect((earlier ?? 0) < (later ?? 0))
    }
}

/// What each switch in Settings asks iOS for.
@Suite("Apple Health access")
struct HealthKitAccessTests {

    private static let neverWritten: [HKObjectType?] = [
        HKObjectType.quantityType(forIdentifier: .heartRate),
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
        HKObjectType.quantityType(forIdentifier: .restingHeartRate),
        HKObjectType.quantityType(forIdentifier: .respiratoryRate),
        HKObjectType.workoutType()
    ]

    private static let neverRead: [HKObjectType?] = [
        HKObjectType.quantityType(forIdentifier: .respiratoryRate),
        HKObjectType.workoutType(),
        HKObjectType.categoryType(forIdentifier: .sexualActivity),
        HKObjectType.categoryType(forIdentifier: .mindfulSession)
    ]

    @Test("No switch asks to write anything ChillMate only reads", arguments: HealthKitPermissionScope.allCases)
    func nothingReadOnlyIsWritten(scope: HealthKitPermissionScope) {
        let share = HealthKitService.authorizationTypes(for: [scope]).share
        for type in Self.neverWritten.compactMap({ $0 }) {
            #expect(!share.contains { $0 == type }, "\(scope) asks to write \(type)")
        }
    }

    @Test("No switch asks to read anything ChillMate never reads", arguments: HealthKitPermissionScope.allCases)
    func nothingUnusedIsRead(scope: HealthKitPermissionScope) {
        let read = HealthKitService.authorizationTypes(for: [scope]).read
        for type in Self.neverRead.compactMap({ $0 }) {
            #expect(!read.contains(type), "\(scope) asks to read \(type)")
        }
    }

    /// Everything together is exactly what the app uses, so adding a type to a
    /// scope has to be a decision made here as well.
    @Test("Every switch together asks for exactly what the app uses")
    func everythingIsExactly() {
        let all = HealthKitService.authorizationTypes(for: Set(HealthKitPermissionScope.allCases))
        let share = Set(all.share.map(\.identifier))
        let read = Set(all.read.map(\.identifier))

        #expect(share == [
            HKCategoryTypeIdentifier.sexualActivity.rawValue,
            HKCategoryTypeIdentifier.sleepAnalysis.rawValue,
            HKCategoryTypeIdentifier.mindfulSession.rawValue
        ])
        #expect(read == [
            HKCategoryTypeIdentifier.sleepAnalysis.rawValue,
            HKQuantityTypeIdentifier.heartRate.rawValue,
            HKQuantityTypeIdentifier.restingHeartRate.rawValue,
            HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue
        ])
    }
}

/// Replacing what versions before 5.1.0 wrote.
@Suite("Apple Health cleanup")
struct HealthLegacyCleanupTests {

    private let end = Date(timeIntervalSince1970: 1_790_000_000)

    private func night(id: UUID = UUID(), sleepHours: Double = 7, hadSex: Bool = true) -> HealthLogSnapshot {
        HealthLogSnapshot(
            id: id,
            startDate: end.addingTimeInterval(-6 * 3600),
            endDate: end,
            hadSex: hadSex,
            skippedNight: false,
            sleptYet: sleepHours > 0,
            sleepHours: sleepHours
        )
    }

    /// A legacy sample exactly where a night would write one today.
    private func legacy(_ kind: HealthSampleKind, of snapshot: HealthLogSnapshot, uuid: UUID = UUID(), nudge: TimeInterval = 0) -> LegacyHealthSample {
        let draft = HealthKitService.drafts(for: snapshot, includeSleep: true).first { $0.kind == kind }!
        return LegacyHealthSample(
            uuid: uuid,
            kind: kind,
            interval: DateInterval(start: draft.interval.start.addingTimeInterval(nudge), end: draft.interval.end.addingTimeInterval(nudge)),
            value: draft.value
        )
    }

    @Test("A sample that matches a night takes that night's identifier")
    func matchedTakesNightIdentifier() {
        let snapshot = night()
        let copies = HealthLegacyCleanup.copies(of: [legacy(.sleep, of: snapshot)], matching: [snapshot])
        #expect(copies.map(\.syncIdentifier) == [HealthSampleKind.sleep.syncIdentifier(for: snapshot.id)])
    }

    /// HealthKit hands dates back close to how they went in, not always to the bit.
    @Test("Matching tolerates a fraction of a second")
    func matchingTolerates() {
        let snapshot = night()
        let copies = HealthLegacyCleanup.copies(of: [legacy(.sleep, of: snapshot, nudge: 0.4)], matching: [snapshot])
        #expect(copies.first?.syncIdentifier == HealthSampleKind.sleep.syncIdentifier(for: snapshot.id))
    }

    /// Every edit before 5.1.0 wrote the night again beside the last copy.
    @Test("Exact duplicates become one copy")
    func duplicatesCollapse() {
        let snapshot = night()
        let copies = HealthLegacyCleanup.copies(
            of: [legacy(.sleep, of: snapshot), legacy(.sleep, of: snapshot), legacy(.sleep, of: snapshot)],
            matching: [snapshot]
        )
        #expect(copies.count == 1)
    }

    /// A night deleted from ChillMate still had its sleep in Health. It keeps it.
    @Test("A sample with no night left is still copied, not lost")
    func unmatchedIsKept() {
        let orphan = legacy(.sleep, of: night())
        let copies = HealthLegacyCleanup.copies(of: [orphan], matching: [])
        #expect(copies.count == 1)
        #expect(copies.first?.interval == orphan.interval)
        #expect(copies.first?.syncIdentifier == "legacy-\(orphan.uuid.uuidString)")
    }

    /// An earlier save of a night whose sleep has since changed is a different
    /// sample, and Health had it. It is kept as it was rather than guessed away.
    @Test("An older, different sample for the same night is kept separately")
    func staleSampleIsKeptSeparately() {
        let now = night(sleepHours: 7)
        let before = night(id: now.id, sleepHours: 5)
        let copies = HealthLegacyCleanup.copies(of: [legacy(.sleep, of: now), legacy(.sleep, of: before)], matching: [now])
        #expect(copies.count == 2)
        #expect(copies.filter { $0.syncIdentifier == HealthSampleKind.sleep.syncIdentifier(for: now.id) }.count == 1)
    }

    /// A run that was stopped halfway starts again from the same samples. It has
    /// to make the same copies under the same identifiers, or the second run adds
    /// to the first instead of replacing it.
    @Test("The same samples in any order make the same copies")
    func deterministic() {
        let snapshot = night()
        let samples = [legacy(.sleep, of: snapshot), legacy(.sexualActivity, of: snapshot), legacy(.sleep, of: night())]
        let forward = HealthLegacyCleanup.copies(of: samples, matching: [snapshot])
        let backward = HealthLegacyCleanup.copies(of: samples.reversed(), matching: [snapshot])
        #expect(forward == backward)
    }
}

/// Filling in sleep from Health, against a Health that says exactly what it is told.
@MainActor
@Suite("Sleep backfill")
struct SleepBackfillTests {

    private final class ScriptedHealth: HealthReading {
        var intervals: [DateInterval] = []
        var askedToExcludeOwn: [Bool] = []

        func asleepIntervals(in window: DateInterval, excludingOwnSamples: Bool) async throws -> [DateInterval] {
            askedToExcludeOwn.append(excludingOwnSamples)
            return intervals
        }
        func latestHRV() async throws -> Double? { nil }
        func latestHeartRate() async throws -> Double? { nil }
        func latestRestingHeartRate() async throws -> Double? { nil }
        func removeLegacyMetadata(matching nights: [HealthLogSnapshot]) async throws -> Bool { true }
        func requestAuthorization() async throws {}
        func requestAuthorization(scopes: Set<HealthKitPermissionScope>) async throws {}
        func save(_ snapshot: HealthLogSnapshot, sleepReadAllowed: Bool) async throws {}
        func saveMindfulMinutes(from startDate: Date, to endDate: Date) async throws {}
        func saveStateOfMind(date: Date, mood: AftercareMood) async throws {}
        func sleepHours(from startDate: Date, to endDate: Date) async throws -> Double { 0 }
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            NightEntry.self,
            LoggedSubstanceRecord.self,
            PartnerDetailRecord.self,
            TriggerTagRecord.self
        ])
        return ModelContext(try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        ))
    }

    private func defaults(_ name: String = #function, sleepOn: Bool = true) -> UserDefaults {
        let suite = "SleepBackfillTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(sleepOn, forKey: DefaultsKey.healthKitSleepReadWriteEnabled)
        // No real notification from a test.
        defaults.set(false, forKey: DefaultsKey.notificationsEnabled)
        return defaults
    }

    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    /// A night that ended ten hours before `now`.
    @discardableResult
    private func night(in context: ModelContext, sleptYet: Bool = false, sleepHours: Double = 0, skipped: Bool = false) -> NightEntry {
        let end = now.addingTimeInterval(-10 * 3600)
        let entry = NightEntry(
            date: end.addingTimeInterval(-5 * 3600),
            startDate: end.addingTimeInterval(-5 * 3600),
            endDate: end,
            hadSex: false,
            skippedNight: skipped,
            substances: [],
            sleptYet: sleptYet,
            sleepHours: sleepHours
        )
        context.insert(entry)
        return entry
    }

    /// Seven hours after the night, recorded twice, ending two hours ago.
    private var sevenHoursTwice: [DateInterval] {
        let sleep = DateInterval(start: now.addingTimeInterval(-9 * 3600), end: now.addingTimeInterval(-2 * 3600))
        return [sleep, sleep]
    }

    private func services(_ health: ScriptedHealth) -> Services {
        var services = Services.live
        services.health = health
        return services
    }

    @Test("A night with no sleep gets what Health recorded, counted once")
    func fillsOnce() async throws {
        let context = try makeContext()
        let entry = night(in: context)
        let health = ScriptedHealth()
        health.intervals = sevenHoursTwice

        let filled = await SleepBackfill.run(context: context, services: services(health), defaults: defaults(), now: now)

        #expect(filled == 1)
        #expect(entry.sleptYet)
        #expect(entry.sleepHours == 7)
    }

    /// ChillMate's own sleep samples are figures somebody typed, possibly for a
    /// neighbouring night. Filling from them would copy a guess into a log.
    @Test("It only ever reads sleep a device recorded")
    func excludesOwnSamples() async throws {
        let context = try makeContext()
        night(in: context)
        let health = ScriptedHealth()
        health.intervals = sevenHoursTwice

        await SleepBackfill.run(context: context, services: services(health), defaults: defaults(), now: now)

        #expect(!health.askedToExcludeOwn.isEmpty)
        #expect(health.askedToExcludeOwn.allSatisfy { $0 })
    }

    @Test("A figure somebody typed is never replaced")
    func typedFigureStays() async throws {
        let context = try makeContext()
        let entry = night(in: context, sleptYet: true, sleepHours: 5)
        let health = ScriptedHealth()
        health.intervals = sevenHoursTwice

        await SleepBackfill.run(context: context, services: services(health), defaults: defaults(), now: now)

        #expect(entry.sleepHours == 5)
    }

    @Test("A skipped night is left alone")
    func skippedStays() async throws {
        let context = try makeContext()
        let entry = night(in: context, skipped: true)
        let health = ScriptedHealth()
        health.intervals = sevenHoursTwice

        await SleepBackfill.run(context: context, services: services(health), defaults: defaults(), now: now)

        #expect(!entry.sleptYet)
    }

    @Test("Nothing is read unless sleep is switched on in Settings")
    func offMeansOff() async throws {
        let context = try makeContext()
        let entry = night(in: context)
        let health = ScriptedHealth()
        health.intervals = sevenHoursTwice

        let filled = await SleepBackfill.run(context: context, services: services(health), defaults: defaults(sleepOn: false), now: now)

        #expect(filled == 0)
        #expect(health.askedToExcludeOwn.isEmpty)
        #expect(!entry.sleptYet)
    }

    @Test("A second pass finds nothing left to do")
    func secondPassIsQuiet() async throws {
        let context = try makeContext()
        night(in: context)
        let health = ScriptedHealth()
        health.intervals = sevenHoursTwice
        let settings = defaults()

        await SleepBackfill.run(context: context, services: services(health), defaults: settings, now: now)
        let again = await SleepBackfill.run(context: context, services: services(health), defaults: settings, now: now)

        #expect(again == 0)
    }
}
