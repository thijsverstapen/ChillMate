import Foundation
import SwiftData

@Model
final class NightEntry {
    var id: UUID = UUID()
    var date: Date = Date.now
    var startDate: Date = Date.now
    var endDate: Date = Date.now
    var hadSex: Bool = false
    var partnerCount: Int = 1
    var usedCondom: Bool = false
    var wasPenetrated: Bool = false
    var partnerDetailsData: Data = Data("[]".utf8)
    var skippedNight: Bool = false
    var substancesData: Data = Data("[]".utf8)
    var injectionSubstancesData: Data = Data("[]".utf8)
    var triggerTagsData: Data = Data("[]".utf8)
    var changeReasonsData: Data = Data("[]".utf8)
    var reportedMemoryGap: Bool = false
    var memorySafeNow: Bool = false
    var memoryInjuries: Bool = false
    var memoryConsentConcern: Bool = false
    var memoryNeedsHelp: Bool = false
    var memoryNotes: String = ""
    var sleptYet: Bool = false
    var sleepHours: Double = 0
    var locationName: String = ""
    var locationLatitude: Double?
    var locationLongitude: Double?
    var note: String = ""
    var aftercareCompletedAt: Date?
    var aftercareSleepRecorded: Bool = false
    var aftercareSleepHours: Double = 0
    var aftercareDrankWater: Bool = false
    var aftercareAteFood: Bool = false
    var aftercareFoodNote: String = ""
    var aftercareSymptomsData: Data = Data("[]".utf8)
    var aftercareMood: String = AftercareMood.okay.rawValue
    var aftercareFeeling: String = ""
    var createdAt: Date = Date.now
    /// 0 = row written by a build before typed child records existed (or not yet
    /// materialized); 1 = typed records are authoritative for this row. Stored on
    /// the entry itself so it travels atomically with the parent CloudKit record:
    /// a synced row from a current build arrives already stamped 1 and is never
    /// re-materialized, even while its child records are still importing.
    var typedRecordsVersion: Int = 0

    /// Bumped by every setter that changes displayed content.
    ///
    /// Views that cache derived values (the dashboard's metrics, most of all) need
    /// to know an entry was *edited*, not just added or removed. Summing this
    /// across the fetched rows gives a cheap key that changes on edits too — a
    /// row-count comparison does not, which is how the dashboard came to show
    /// stale figures after editing a night.
    ///
    /// It has a default and is a plain Int, so it round-trips through CloudKit like
    /// every other attribute. Overflow is harmless: this is an equality key, not a
    /// counter anyone reads.
    var contentVersion: Int = 0

    /// Records that this entry's displayed content changed.
    func markContentChanged() {
        contentVersion &+= 1
    }

    init(
        id: UUID = UUID(),
        date: Date,
        startDate: Date? = nil,
        endDate: Date? = nil,
        hadSex: Bool,
        partnerCount: Int = 1,
        usedCondom: Bool = false,
        wasPenetrated: Bool = false,
        partnerDetails: [SexPartnerRecord] = [],
        skippedNight: Bool,
        substances: [String],
        injectionSubstances: [String] = [],
        triggerTags: [ChillTrigger] = [],
        changeReasons: [ChangeReason] = [],
        reportedMemoryGap: Bool = false,
        memorySafeNow: Bool = false,
        memoryInjuries: Bool = false,
        memoryConsentConcern: Bool = false,
        memoryNeedsHelp: Bool = false,
        memoryNotes: String = "",
        sleptYet: Bool = false,
        sleepHours: Double = 0,
        locationName: String = "",
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        note: String = "",
        aftercareCompletedAt: Date? = nil,
        aftercareSleepRecorded: Bool = false,
        aftercareSleepHours: Double = 0,
        aftercareDrankWater: Bool = false,
        aftercareAteFood: Bool = false,
        aftercareFoodNote: String = "",
        aftercareSymptoms: [AftercareSymptom] = [],
        aftercareMood: AftercareMood = .okay,
        aftercareFeeling: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.date = date
        let resolvedStartDate = startDate ?? date
        self.startDate = resolvedStartDate
        self.endDate = endDate ?? resolvedStartDate.addingTimeInterval(60 * 60)
        self.hadSex = hadSex
        self.partnerCount = partnerCount
        self.usedCondom = usedCondom
        self.wasPenetrated = wasPenetrated
        self.partnerDetailsData = NightEntry.encodePartners(partnerDetails)
        self.skippedNight = skippedNight
        self.substancesData = NightEntry.encode(substances)
        self.injectionSubstancesData = NightEntry.encode(injectionSubstances)
        self.triggerTagsData = NightEntry.encodeTriggers(triggerTags)
        self.changeReasonsData = NightEntry.encodeChangeReasons(changeReasons)
        self.reportedMemoryGap = reportedMemoryGap
        self.memorySafeNow = memorySafeNow
        self.memoryInjuries = memoryInjuries
        self.memoryConsentConcern = memoryConsentConcern
        self.memoryNeedsHelp = memoryNeedsHelp
        self.memoryNotes = memoryNotes
        self.sleptYet = sleptYet
        self.sleepHours = sleepHours
        self.locationName = locationName
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.note = note
        self.aftercareCompletedAt = aftercareCompletedAt
        self.aftercareSleepRecorded = aftercareSleepRecorded
        self.aftercareSleepHours = aftercareSleepHours
        self.aftercareDrankWater = aftercareDrankWater
        self.aftercareAteFood = aftercareAteFood
        self.aftercareFoodNote = aftercareFoodNote
        self.aftercareSymptomsData = NightEntry.encodeSymptoms(aftercareSymptoms)
        self.aftercareMood = aftercareMood.rawValue
        self.aftercareFeeling = aftercareFeeling
        self.createdAt = createdAt
        // Blobs are set above; this builds the matching typed child records.
        materializeTypedRecordsIfNeeded()
    }

    // MARK: Typed relationships
    //
    // Substances, partners, and trigger tags are stored as typed child models so
    // they can participate in #Predicate queries and sync as first-class CloudKit
    // records. The legacy JSON blobs above are kept and DUAL-WRITTEN by every
    // setter, which makes the migration safe and reversible:
    //   - rows written by this version have equal blob + typed data,
    //   - rows from older builds (or late CloudKit arrivals) have blob-only data,
    //     which the getters fall back to,
    //   - the encrypted-backup format (which reads these computed properties)
    //     stays byte-identical across versions.
    //
    // RETIRING THE BLOBS
    //
    // Dual-writing is a migration state, not a destination. It doubles the stored
    // bytes and the CloudKit record payload, makes every getter a fallback chain,
    // and leaves two representations that can in principle disagree. It is not
    // meant to be permanent, and until now nothing recorded when it ends.
    //
    // The blocker is CloudKit, not local data: a device still on an older build
    // writes blob-only rows, and those must keep resolving. So the exit condition
    // is a *release* condition, not a code one:
    //
    //   1. 4.2.1 (this release) — dual-write continues. TypedRecordsMigration
    //      stamps every local row typedRecordsVersion == 1.
    //   2. Once App Store adoption of >= 4.2.0 is effectively complete (no build
    //      older than typed records still syncing into a shared iCloud database,
    //      in practice two or more releases later), stop WRITING the blobs while
    //      still READING them. That is a one-line change in each setter.
    //   3. One release after that, drop the *Data properties in a schema V3 stage
    //      with a .custom handler that materializes any straggler rows first.
    //
    // Do not skip step 2: going straight from dual-write to dropped columns loses
    // data for anyone whose old device syncs a blob-only row after the upgrade.

    @Relationship(deleteRule: .cascade, inverse: \LoggedSubstanceRecord.entry)
    var substanceRecords: [LoggedSubstanceRecord]? = nil

    @Relationship(deleteRule: .cascade, inverse: \PartnerDetailRecord.entry)
    var partnerRecords: [PartnerDetailRecord]? = nil

    @Relationship(deleteRule: .cascade, inverse: \TriggerTagRecord.entry)
    var triggerRecords: [TriggerTagRecord]? = nil

    var substances: [String] {
        get {
            let typed = NightEntry.dedupedBySortKey(
                (substanceRecords ?? []).filter { !$0.isInjection },
                sortIndex: \.sortIndex, key: \.name
            ).map(\.name)
            return typed.isEmpty ? NightEntry.decode(substancesData) : typed
        }
        set {
            substancesData = NightEntry.encode(newValue)
            replaceSubstanceRecords(with: newValue, isInjection: false)
            markContentChanged()
        }
    }

    var injectionSubstances: [String] {
        get {
            let typed = NightEntry.dedupedBySortKey(
                (substanceRecords ?? []).filter(\.isInjection),
                sortIndex: \.sortIndex, key: \.name
            ).map(\.name)
            return typed.isEmpty ? NightEntry.decode(injectionSubstancesData) : typed
        }
        set {
            injectionSubstancesData = NightEntry.encode(newValue)
            replaceSubstanceRecords(with: newValue, isInjection: true)
            markContentChanged()
        }
    }

    var partnerDetails: [SexPartnerRecord] {
        get {
            let typed = NightEntry.dedupedBySortKey(
                partnerRecords ?? [],
                sortIndex: \.sortIndex, key: \.partnerID.uuidString
            ).map(\.asPartnerRecord)
            return typed.isEmpty ? NightEntry.decodePartners(partnerDetailsData) : typed
        }
        set {
            partnerDetailsData = NightEntry.encodePartners(newValue)
            let replaced = partnerRecords ?? []
            partnerRecords = newValue.enumerated().map { PartnerDetailRecord(partner: $0.element, sortIndex: $0.offset) }
            for record in replaced {
                record.modelContext?.delete(record)
            }
            markContentChanged()
        }
    }

    var triggerTags: [ChillTrigger] {
        get {
            let typed = NightEntry.dedupedBySortKey(
                triggerRecords ?? [],
                sortIndex: \.sortIndex, key: \.name
            ).compactMap { ChillTrigger(rawValue: $0.name) }
            return typed.isEmpty ? NightEntry.decodeTriggers(triggerTagsData) : typed
        }
        set {
            triggerTagsData = NightEntry.encodeTriggers(newValue)
            let replaced = triggerRecords ?? []
            triggerRecords = newValue.enumerated().map { TriggerTagRecord(name: $0.element.rawValue, sortIndex: $0.offset) }
            for record in replaced {
                record.modelContext?.delete(record)
            }
            markContentChanged()
        }
    }

    /// Sorts child records by sortIndex (key as deterministic tie-break) and drops
    /// exact (sortIndex, key) duplicates. Duplicates can only arise from a CloudKit
    /// union after two devices materialized the same legacy row concurrently; a
    /// legitimate repeated value always has a distinct sortIndex, so this never
    /// collapses real data. The store self-heals on the entry's next edit (setters
    /// rewrite children wholesale).
    private static func dedupedBySortKey<Record>(
        _ records: [Record],
        sortIndex: KeyPath<Record, Int>,
        key: KeyPath<Record, String>
    ) -> [Record] {
        var seen = Set<String>()
        return records
            .sorted {
                let a = ($0[keyPath: sortIndex], $0[keyPath: key])
                let b = ($1[keyPath: sortIndex], $1[keyPath: key])
                return a < b
            }
            .filter { seen.insert("\($0[keyPath: sortIndex])|\($0[keyPath: key])").inserted }
    }

    private func replaceSubstanceRecords(with names: [String], isInjection: Bool) {
        let existing = substanceRecords ?? []
        let replaced = existing.filter { $0.isInjection == isInjection }
        let kept = existing.filter { $0.isInjection != isInjection }
        let new = names.enumerated().map {
            LoggedSubstanceRecord(name: $0.element, isInjection: isInjection, sortIndex: $0.offset)
        }
        substanceRecords = kept + new
        for record in replaced {
            record.modelContext?.delete(record)
        }
    }

    /// Per-entry idempotent materialization of typed records from the legacy JSON
    /// blobs. Only runs for rows still stamped `typedRecordsVersion == 0`, so a
    /// CloudKit-synced row from a current build (children possibly still in
    /// flight) is never re-materialized into duplicates. Only fills empty
    /// relationships, then stamps the row.
    func materializeTypedRecordsIfNeeded() {
        guard typedRecordsVersion == 0 else { return }
        defer { typedRecordsVersion = 1 }

        if (substanceRecords ?? []).isEmpty {
            let plain = NightEntry.decode(substancesData)
            let injected = NightEntry.decode(injectionSubstancesData)
            if !plain.isEmpty || !injected.isEmpty {
                substanceRecords =
                    plain.enumerated().map { LoggedSubstanceRecord(name: $0.element, isInjection: false, sortIndex: $0.offset) } +
                    injected.enumerated().map { LoggedSubstanceRecord(name: $0.element, isInjection: true, sortIndex: $0.offset) }
            }
        }

        if (partnerRecords ?? []).isEmpty {
            let partners = NightEntry.decodePartners(partnerDetailsData)
            if !partners.isEmpty {
                partnerRecords = partners.enumerated().map { PartnerDetailRecord(partner: $0.element, sortIndex: $0.offset) }
            }
        }

        if (triggerRecords ?? []).isEmpty {
            let triggers = NightEntry.decodeTriggers(triggerTagsData)
            if !triggers.isEmpty {
                triggerRecords = triggers.enumerated().map { TriggerTagRecord(name: $0.element.rawValue, sortIndex: $0.offset) }
            }
        }
    }

    var changeReasons: [ChangeReason] {
        get { NightEntry.decodeChangeReasons(changeReasonsData) }
        set {
            changeReasonsData = NightEntry.encodeChangeReasons(newValue)
            markContentChanged()
        }
    }

    var aftercareSymptoms: [AftercareSymptom] {
        get { NightEntry.decodeSymptoms(aftercareSymptomsData) }
        set {
            aftercareSymptomsData = NightEntry.encodeSymptoms(newValue)
            markContentChanged()
        }
    }

    var isTrackedEvent: Bool {
        hadSex && !skippedNight
    }

    /// Uses a catalog plural rule rather than an inline `count == 1` ternary. The
    /// previous form hard-coded English "person"/"people", and a two-branch ternary
    /// cannot express languages with more than two plural categories anyway.
    var partnerSummary: String {
        let count = max(partnerDetails.count, max(1, partnerCount))
        return String(localized: "\(count) person")
    }

    var sleepSummary: String {
        guard sleptYet else {
            return String(localized: "Sleep not yet logged")
        }

        let hours = sleepHours.formatted(.number.precision(.fractionLength(0...1)))
        return "\(SleepMood(hours: sleepHours).emoji) \(String(localized: "\(hours) h sleep"))"
    }

    var timeFrameSummary: String {
        let calendar = Calendar.current
        let startTime = startDate.formatted(.dateTime.hour().minute())
        let endTime = endDate.formatted(.dateTime.hour().minute())

        if calendar.isDate(startDate, inSameDayAs: endDate) {
            return "\(startTime) - \(endTime)"
        }

        let start = startDate.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        let end = endDate.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        return "\(start) - \(end)"
    }

    /// The four outcomes are whole localized sentences rather than two clauses glued
    /// with a comma: word order and punctuation between them differ by language.
    var saferSexSummary: String {
        guard hadSex, !skippedNight else {
            return String(localized: "No sex recorded")
        }

        switch (usedCondom, wasPenetrated) {
        case (true, true):
            return String(localized: "Condom used, penetrated")
        case (true, false):
            return String(localized: "Condom used, not penetrated")
        case (false, true):
            return String(localized: "No condom, penetrated")
        case (false, false):
            return String(localized: "No condom, not penetrated")
        }
    }

    var hasLocation: Bool {
        locationLatitude != nil && locationLongitude != nil
    }

    var locationSummary: String {
        let trimmedName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }

        guard let locationLatitude, let locationLongitude else {
            return String(localized: "No location")
        }

        let latitude = locationLatitude.formatted(.number.precision(.fractionLength(3)))
        let longitude = locationLongitude.formatted(.number.precision(.fractionLength(3)))
        return "\(latitude), \(longitude)"
    }

    var suggestsPEPConcern: Bool {
        guard hadSex, !skippedNight else {
            return false
        }

        return !usedCondom || wasPenetrated || partnerDetails.contains(where: \.userWasPenetrated)
    }

    var pepDeadline: Date {
        startDate.addingTimeInterval(72 * 60 * 60)
    }

    // Coders are shared rather than allocated per call. These helpers run once per
    // property read, and the getters are read repeatedly per render, so the
    // allocations were not free. JSONEncoder/JSONDecoder are value types with no
    // mutable configuration here, so sharing them is safe.
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    private static func encode(_ substances: [String]) -> Data {
        (try? encoder.encode(substances)) ?? Data("[]".utf8)
    }

    private static func decode(_ data: Data) -> [String] {
        (try? decoder.decode([String].self, from: data)) ?? []
    }

    private static func encodePartners(_ partners: [SexPartnerRecord]) -> Data {
        (try? encoder.encode(partners)) ?? Data("[]".utf8)
    }

    private static func decodePartners(_ data: Data) -> [SexPartnerRecord] {
        (try? decoder.decode([SexPartnerRecord].self, from: data)) ?? []
    }

    private static func encodeTriggers(_ values: [ChillTrigger]) -> Data {
        encode(values.map(\.rawValue))
    }

    private static func decodeTriggers(_ data: Data) -> [ChillTrigger] {
        decode(data).compactMap(ChillTrigger.init(rawValue:))
    }

    private static func encodeChangeReasons(_ values: [ChangeReason]) -> Data {
        encode(values.map(\.rawValue))
    }

    private static func decodeChangeReasons(_ data: Data) -> [ChangeReason] {
        decode(data).compactMap(ChangeReason.init(rawValue:))
    }

    private static func encodeSymptoms(_ symptoms: [AftercareSymptom]) -> Data {
        encode(symptoms.map(\.rawValue))
    }

    private static func decodeSymptoms(_ data: Data) -> [AftercareSymptom] {
        decode(data).compactMap(AftercareSymptom.init(rawValue:))
    }
}

// MARK: - Typed child models
//
// CloudKit-compatible: every attribute has a default, the parent relationship is
// optional, and the inverse is declared once (on NightEntry). `sortIndex` preserves
// display order because SwiftData to-many relationships are unordered.

@Model
final class LoggedSubstanceRecord {
    var name: String = ""
    var isInjection: Bool = false
    var sortIndex: Int = 0
    var entry: NightEntry?

    init(name: String, isInjection: Bool = false, sortIndex: Int = 0) {
        self.name = name
        self.isInjection = isInjection
        self.sortIndex = sortIndex
    }
}

@Model
final class PartnerDetailRecord {
    var partnerID: UUID = UUID()
    var name: String = ""
    var phoneNumber: String = ""
    var theyWerePenetrated: Bool = false
    var userWasPenetrated: Bool = false
    var sortIndex: Int = 0
    var entry: NightEntry?

    init(partner: SexPartnerRecord, sortIndex: Int = 0) {
        self.partnerID = partner.id
        self.name = partner.name
        self.phoneNumber = partner.phoneNumber
        self.theyWerePenetrated = partner.theyWerePenetrated
        self.userWasPenetrated = partner.userWasPenetrated
        self.sortIndex = sortIndex
    }

    var asPartnerRecord: SexPartnerRecord {
        SexPartnerRecord(
            id: partnerID,
            name: name,
            phoneNumber: phoneNumber,
            theyWerePenetrated: theyWerePenetrated,
            userWasPenetrated: userWasPenetrated
        )
    }
}

@Model
final class TriggerTagRecord {
    var name: String = ""
    var sortIndex: Int = 0
    var entry: NightEntry?

    init(name: String, sortIndex: Int = 0) {
        self.name = name
        self.sortIndex = sortIndex
    }
}

enum ChillTrigger: String, CaseIterable, Identifiable, Codable {
    case horny = "Horny"
    case lonely = "Lonely"
    case invited = "Invited"
    case appDate = "App date"
    case party = "Party"
    case stress = "Stress"
    case impulsive = "Impulsive"
    case planned = "Planned"
    case depressed = "Depressed"
    case numb = "Numb"
    case anxious = "Anxious"
    case grief = "Grief"
    case trauma = "Trauma"
    case heartbreak = "Heartbreak"
    case celebration = "Celebration"
    case socialPressure = "Social pressure"
    case boredom = "Boredom"

    var id: String { rawValue }
}

enum ChangeReason: String, CaseIterable, Identifiable, Codable {
    case stress = "Stress"
    case breakup = "Breakup"
    case workPressure = "Work pressure"
    case loneliness = "Loneliness"
    case money = "Money"
    case housing = "Housing"
    case conflict = "Conflict"
    case boredom = "Boredom"
    case depression = "Depression"
    case anxiety = "Anxiety"
    case bereavement = "Bereavement"
    case trauma = "Trauma"
    case relationship = "Relationship"
    case health = "Health"
    case medication = "Medication change"

    var id: String { rawValue }
}

struct SexPartnerRecord: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var phoneNumber: String
    var theyWerePenetrated: Bool
    var userWasPenetrated: Bool

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Unnamed person") : trimmed
    }

    var normalizedPhoneNumber: String {
        phoneNumber.filter { $0.isNumber || $0 == "+" }
    }
}

enum AftercareMood: String, CaseIterable, Identifiable, Codable {
    case grounded = "Grounded"
    case okay = "Okay"
    case tender = "Tender"
    case anxious = "Anxious"
    case low = "Low"
    case overwhelmed = "Overwhelmed"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .grounded:
            "🙂"
        case .okay:
            "😌"
        case .tender:
            "🥹"
        case .anxious:
            "😟"
        case .low:
            "😔"
        case .overwhelmed:
            "😣"
        }
    }
}

enum AftercareSymptom: String, CaseIterable, Identifiable, Codable {
    case anxious = "Anxious"
    case depressed = "Depressed"
    case numb = "Numb"
    case exhausted = "Exhausted"
    case overstimulated = "Overstimulated"
    case shaky = "Shaky"
    case dissociated = "Dissociated"

    var id: String { rawValue }

    var likelyCause: String {
        switch self {
        case .anxious:
            String(localized: "alcohol rebound, stimulant comedown, lack of sleep, or feeling overstimulated")
        case .depressed:
            String(localized: "serotonin dip, sleep debt, alcohol rebound, or emotional overload")
        case .numb:
            String(localized: "dissociation, exhaustion, emotional shutdown, or a delayed stress response")
        case .exhausted:
            String(localized: "sleep deprivation, dehydration, low food intake, or a long stimulant window")
        case .overstimulated:
            String(localized: "stimulant overload, too little rest, dehydration, or intense sensory input")
        case .shaky:
            String(localized: "stimulants, low blood sugar, dehydration, anxiety, or alcohol rebound")
        case .dissociated:
            String(localized: "ketamine or other dissociatives, stress, sleep loss, or feeling unsafe")
        }
    }
}

struct SleepMood {
    let hours: Double

    var emoji: String {
        switch hours {
        case 6...:
            "😊"
        case 4..<6:
            "🙂"
        case 2..<4:
            "🙁"
        case 0..<2:
            "😢"
        default:
            "😐"
        }
    }

    var label: String {
        switch hours {
        case 6...:
            String(localized: "Rested")
        case 4..<6:
            String(localized: "Some sleep")
        case 2..<4:
            String(localized: "Low sleep")
        case 0..<2:
            String(localized: "Very little sleep")
        default:
            String(localized: "Sleep")
        }
    }
}
