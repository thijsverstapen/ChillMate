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
    }

    var substances: [String] {
        get { NightEntry.decode(substancesData) }
        set { substancesData = NightEntry.encode(newValue) }
    }

    var injectionSubstances: [String] {
        get { NightEntry.decode(injectionSubstancesData) }
        set { injectionSubstancesData = NightEntry.encode(newValue) }
    }

    var partnerDetails: [SexPartnerRecord] {
        get { NightEntry.decodePartners(partnerDetailsData) }
        set { partnerDetailsData = NightEntry.encodePartners(newValue) }
    }

    var triggerTags: [ChillTrigger] {
        get { NightEntry.decodeTriggers(triggerTagsData) }
        set { triggerTagsData = NightEntry.encodeTriggers(newValue) }
    }

    var changeReasons: [ChangeReason] {
        get { NightEntry.decodeChangeReasons(changeReasonsData) }
        set { changeReasonsData = NightEntry.encodeChangeReasons(newValue) }
    }

    var aftercareSymptoms: [AftercareSymptom] {
        get { NightEntry.decodeSymptoms(aftercareSymptomsData) }
        set { aftercareSymptomsData = NightEntry.encodeSymptoms(newValue) }
    }

    var isTrackedEvent: Bool {
        hadSex && !skippedNight
    }

    var partnerSummary: String {
        let count = max(partnerDetails.count, max(1, partnerCount))
        return "\(count) \(count == 1 ? "person" : "people")"
    }

    var sleepSummary: String {
        guard sleptYet else {
            return "Sleep not yet logged"
        }

        return "\(SleepMood(hours: sleepHours).emoji) \(sleepHours.formatted(.number.precision(.fractionLength(0...1)))) h sleep"
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

    var saferSexSummary: String {
        guard hadSex, !skippedNight else {
            return "No sex recorded"
        }

        let condomText = usedCondom ? "Condom used" : "No condom"
        let penetrationText = wasPenetrated ? "penetrated" : "not penetrated"
        return "\(condomText), \(penetrationText)"
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
            return "No location"
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

    private static func encode(_ substances: [String]) -> Data {
        (try? JSONEncoder().encode(substances)) ?? Data("[]".utf8)
    }

    private static func decode(_ data: Data) -> [String] {
        (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    private static func encodePartners(_ partners: [SexPartnerRecord]) -> Data {
        (try? JSONEncoder().encode(partners)) ?? Data("[]".utf8)
    }

    private static func decodePartners(_ data: Data) -> [SexPartnerRecord] {
        (try? JSONDecoder().decode([SexPartnerRecord].self, from: data)) ?? []
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
        let rawValues = symptoms.map(\.rawValue)
        return (try? JSONEncoder().encode(rawValues)) ?? Data("[]".utf8)
    }

    private static func decodeSymptoms(_ data: Data) -> [AftercareSymptom] {
        let rawValues = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        return rawValues.compactMap(AftercareSymptom.init(rawValue:))
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
        return trimmed.isEmpty ? "Unnamed person" : trimmed
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
            "alcohol rebound, stimulant comedown, lack of sleep, or feeling overstimulated"
        case .depressed:
            "serotonin dip, sleep debt, alcohol rebound, or emotional overload"
        case .numb:
            "dissociation, exhaustion, emotional shutdown, or a delayed stress response"
        case .exhausted:
            "sleep deprivation, dehydration, low food intake, or a long stimulant window"
        case .overstimulated:
            "stimulant overload, too little rest, dehydration, or intense sensory input"
        case .shaky:
            "stimulants, low blood sugar, dehydration, anxiety, or alcohol rebound"
        case .dissociated:
            "ketamine or other dissociatives, stress, sleep loss, or feeling unsafe"
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
            "Rested"
        case 4..<6:
            "Some sleep"
        case 2..<4:
            "Low sleep"
        case 0..<2:
            "Very little sleep"
        default:
            "Sleep"
        }
    }
}
