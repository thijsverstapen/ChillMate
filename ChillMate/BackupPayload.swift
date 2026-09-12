import Foundation
import SwiftData
import UIKit
import ChillMateCore

/// What an encrypted backup actually contains: the archive envelope and one DTO
/// per model.
///
/// Split out of `EncryptedBackupService.swift`, which held the two services, the
/// error types, the archive and eight hundred lines of serialization. The split
/// is along the line that matters for schema changes: CLAUDE.md's rule is that a
/// backup taken on the previous version has to keep restoring, and this is the
/// file that decides whether it does.
///
/// This is a move. Nothing about the encoded shape changes, which would break
/// exactly that promise.

/// No longer `private`: the service that writes and reads it lives in another
/// file now. Everything it is assembled from stays private to this one, which is
/// the point — the DTOs are the on-disk shape and nothing outside here should be
/// able to name them.
struct ChillMateBackupArchive: Codable {
    // `fileprivate`, so the DTOs stay private to this file while the archive
    // itself is nameable from the service. The service only ever calls
    // `make(from:)`, `decode(from:)`, `encoded()`, `merge(into:)`, `isEmpty` and
    // `importSummary` — it has no business reaching into the on-disk shape, and
    // now it cannot. Codable synthesis is generated in this file and is happy
    // with fileprivate storage.
    fileprivate var schemaVersion: Int = 1
    fileprivate var exportedAt: Date = .now
    fileprivate var deviceID: String = EncryptedBackupDevice.identity
    fileprivate var nightEntries: [NightEntryDTO]
    fileprivate var profiles: [UserProfileDTO]
    fileprivate var stdTests: [STDTestDTO]
    fileprivate var drugTimers: [DrugDoseTimerDTO]
    fileprivate var saferPlans: [SaferSessionPlanDTO]
    fileprivate var riskChecks: [RiskCheckDTO]
    fileprivate var journals: [JournalDTO]

    var isEmpty: Bool {
        nightEntries.isEmpty &&
        profiles.isEmpty &&
        stdTests.isEmpty &&
        drugTimers.isEmpty &&
        saferPlans.isEmpty &&
        riskChecks.isEmpty &&
        journals.isEmpty
    }

    static func storeIsEmpty(in context: ModelContext) throws -> Bool {
        let nightEntryCount = try context.fetchCount(FetchDescriptor<NightEntry>())
        let profileCount = try context.fetchCount(FetchDescriptor<UserProfile>())
        let stdTestCount = try context.fetchCount(FetchDescriptor<STDTestRecord>())
        let timerCount = try context.fetchCount(FetchDescriptor<DrugDoseTimerRecord>())
        let planCount = try context.fetchCount(FetchDescriptor<SaferSessionPlan>())
        let riskCheckCount = try context.fetchCount(FetchDescriptor<RiskCheckRecord>())
        let journalCount = try context.fetchCount(FetchDescriptor<JournalEntry>())

        return nightEntryCount == 0 &&
        profileCount == 0 &&
        stdTestCount == 0 &&
        timerCount == 0 &&
        planCount == 0 &&
        riskCheckCount == 0 &&
        journalCount == 0
    }

    static func make(from context: ModelContext) throws -> Self {
        let nightEntries = try context.fetch(FetchDescriptor<NightEntry>())
            .map(NightEntryDTO.init)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
            .map(UserProfileDTO.init)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let stdTests = try context.fetch(FetchDescriptor<STDTestRecord>())
            .map(STDTestDTO.init)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let drugTimers = try context.fetch(FetchDescriptor<DrugDoseTimerRecord>())
            .map(DrugDoseTimerDTO.init)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let saferPlans = try context.fetch(FetchDescriptor<SaferSessionPlan>())
            .map(SaferSessionPlanDTO.init)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let riskChecks = try context.fetch(FetchDescriptor<RiskCheckRecord>())
            .map(RiskCheckDTO.init)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let journals = try context.fetch(FetchDescriptor<JournalEntry>())
            .map(JournalDTO.init)
            .sorted { $0.id.uuidString < $1.id.uuidString }

        return ChillMateBackupArchive(
            nightEntries: nightEntries,
            profiles: profiles,
            stdTests: stdTests,
            drugTimers: drugTimers,
            saferPlans: saferPlans,
            riskChecks: riskChecks,
            journals: journals
        )
    }

    static func decode(from data: Data) throws -> Self {
        try JSONDecoder.chillMateBackup.decode(Self.self, from: data)
    }

    func encoded() throws -> Data {
        try JSONEncoder.chillMateBackup.encode(self)
    }

    func merge(into context: ModelContext) throws {
        try mergeNightEntries(into: context)
        try mergeProfiles(into: context)
        try mergeSTDTests(into: context)
        try mergeDrugTimers(into: context)
        try mergeSaferPlans(into: context)
        try mergeRiskChecks(into: context)
        try mergeJournals(into: context)
    }

    var importSummary: ChillMateBackupImportSummary {
        ChillMateBackupImportSummary(
            profiles: profiles.count,
            nightEntries: nightEntries.count,
            stdTests: stdTests.count,
            drugTimers: drugTimers.count,
            saferPlans: saferPlans.count,
            riskChecks: riskChecks.count,
            journals: journals.count
        )
    }

    private func mergeNightEntries(into context: ModelContext) throws {
        var existing = Dictionary(try context.fetch(FetchDescriptor<NightEntry>()).map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        for dto in nightEntries {
            if let entry = existing[dto.id] {
                dto.apply(to: entry)
            } else {
                let entry = dto.model()
                existing[dto.id] = entry
                context.insert(entry)
            }
        }
    }

    private func mergeProfiles(into context: ModelContext) throws {
        var existing = Dictionary(try context.fetch(FetchDescriptor<UserProfile>()).map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        for dto in profiles {
            if let profile = existing[dto.id] {
                dto.apply(to: profile)
            } else {
                let profile = dto.model()
                existing[dto.id] = profile
                context.insert(profile)
            }
        }
    }

    private func mergeSTDTests(into context: ModelContext) throws {
        var existing = Dictionary(try context.fetch(FetchDescriptor<STDTestRecord>()).map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        for dto in stdTests {
            if let record = existing[dto.id] {
                dto.apply(to: record)
            } else {
                let record = dto.model()
                existing[dto.id] = record
                context.insert(record)
            }
        }
    }

    private func mergeDrugTimers(into context: ModelContext) throws {
        var existing = Dictionary(try context.fetch(FetchDescriptor<DrugDoseTimerRecord>()).map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        for dto in drugTimers {
            if let record = existing[dto.id] {
                dto.apply(to: record)
            } else {
                let record = dto.model()
                existing[dto.id] = record
                context.insert(record)
            }
        }
    }

    private func mergeSaferPlans(into context: ModelContext) throws {
        var existing = Dictionary(try context.fetch(FetchDescriptor<SaferSessionPlan>()).map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        for dto in saferPlans {
            if let plan = existing[dto.id] {
                dto.apply(to: plan)
            } else {
                let plan = dto.model()
                existing[dto.id] = plan
                context.insert(plan)
            }
        }
    }

    private func mergeRiskChecks(into context: ModelContext) throws {
        var existing = Dictionary(try context.fetch(FetchDescriptor<RiskCheckRecord>()).map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        for dto in riskChecks {
            if let record = existing[dto.id] {
                dto.apply(to: record)
            } else {
                let record = dto.model()
                existing[dto.id] = record
                context.insert(record)
            }
        }
    }

    private func mergeJournals(into context: ModelContext) throws {
        var existing = Dictionary(try context.fetch(FetchDescriptor<JournalEntry>()).map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        for dto in journals {
            if let journal = existing[dto.id] {
                dto.apply(to: journal)
            } else {
                let journal = dto.model()
                existing[dto.id] = journal
                context.insert(journal)
            }
        }
    }
}

private enum EncryptedBackupDevice {
    static var identity: String {
        if let existing = UserDefaults.standard.string(forKey: "encryptedBackupDeviceID") {
            return existing
        }

        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "encryptedBackupDeviceID")
        return id
    }
}

private extension JSONEncoder {
    static var chillMateBackup: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var chillMateBackup: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private struct NightEntryDTO: Codable {
    var id: UUID
    var date: Date
    var startDate: Date
    var endDate: Date
    var hadSex: Bool
    var partnerCount: Int
    var usedCondom: Bool
    var wasPenetrated: Bool
    var partnerDetails: [SexPartnerRecord]
    var skippedNight: Bool
    var substances: [String]
    var injectionSubstances: [String]
    var triggerTags: [ChillTrigger]?
    var changeReasons: [ChangeReason]?
    var reportedMemoryGap: Bool?
    var memorySafeNow: Bool?
    var memoryInjuries: Bool?
    var memoryConsentConcern: Bool?
    var memoryNeedsHelp: Bool?
    var memoryNotes: String?
    var sleptYet: Bool
    var sleepHours: Double
    var locationName: String
    var locationLatitude: Double?
    var locationLongitude: Double?
    var note: String
    var aftercareCompletedAt: Date?
    var aftercareSleepRecorded: Bool
    var aftercareSleepHours: Double
    var aftercareDrankWater: Bool
    var aftercareAteFood: Bool
    var aftercareFoodNote: String
    var aftercareSymptoms: [AftercareSymptom]
    var aftercareMood: AftercareMood
    var aftercareFeeling: String
    var createdAt: Date

    init(_ entry: NightEntry) {
        id = entry.id
        date = entry.date
        startDate = entry.startDate
        endDate = entry.endDate
        hadSex = entry.hadSex
        partnerCount = entry.partnerCount
        usedCondom = entry.usedCondom
        wasPenetrated = entry.wasPenetrated
        partnerDetails = entry.partnerDetails
        skippedNight = entry.skippedNight
        substances = entry.substances
        injectionSubstances = entry.injectionSubstances
        triggerTags = entry.triggerTags
        changeReasons = entry.changeReasons
        reportedMemoryGap = entry.reportedMemoryGap
        memorySafeNow = entry.memorySafeNow
        memoryInjuries = entry.memoryInjuries
        memoryConsentConcern = entry.memoryConsentConcern
        memoryNeedsHelp = entry.memoryNeedsHelp
        memoryNotes = entry.memoryNotes
        sleptYet = entry.sleptYet
        sleepHours = entry.sleepHours
        locationName = entry.locationName
        locationLatitude = entry.locationLatitude
        locationLongitude = entry.locationLongitude
        note = entry.note
        aftercareCompletedAt = entry.aftercareCompletedAt
        aftercareSleepRecorded = entry.aftercareSleepRecorded
        aftercareSleepHours = entry.aftercareSleepHours
        aftercareDrankWater = entry.aftercareDrankWater
        aftercareAteFood = entry.aftercareAteFood
        aftercareFoodNote = entry.aftercareFoodNote
        aftercareSymptoms = entry.aftercareSymptoms
        aftercareMood = AftercareMood(rawValue: entry.aftercareMood) ?? .okay
        aftercareFeeling = entry.aftercareFeeling
        createdAt = entry.createdAt
    }

    func model() -> NightEntry {
        NightEntry(
            id: id,
            date: date,
            startDate: startDate,
            endDate: endDate,
            hadSex: hadSex,
            partnerCount: partnerCount,
            usedCondom: usedCondom,
            wasPenetrated: wasPenetrated,
            partnerDetails: partnerDetails,
            skippedNight: skippedNight,
            substances: substances,
            injectionSubstances: injectionSubstances,
            triggerTags: triggerTags ?? [],
            changeReasons: changeReasons ?? [],
            reportedMemoryGap: reportedMemoryGap ?? false,
            memorySafeNow: memorySafeNow ?? false,
            memoryInjuries: memoryInjuries ?? false,
            memoryConsentConcern: memoryConsentConcern ?? false,
            memoryNeedsHelp: memoryNeedsHelp ?? false,
            memoryNotes: memoryNotes ?? "",
            sleptYet: sleptYet,
            sleepHours: sleepHours,
            locationName: locationName,
            locationLatitude: locationLatitude,
            locationLongitude: locationLongitude,
            note: note,
            aftercareCompletedAt: aftercareCompletedAt,
            aftercareSleepRecorded: aftercareSleepRecorded,
            aftercareSleepHours: aftercareSleepHours,
            aftercareDrankWater: aftercareDrankWater,
            aftercareAteFood: aftercareAteFood,
            aftercareFoodNote: aftercareFoodNote,
            aftercareSymptoms: aftercareSymptoms,
            aftercareMood: aftercareMood,
            aftercareFeeling: aftercareFeeling,
            createdAt: createdAt
        )
    }

    func apply(to entry: NightEntry) {
        entry.date = date
        entry.startDate = startDate
        entry.endDate = endDate
        entry.hadSex = hadSex
        entry.partnerCount = partnerCount
        entry.usedCondom = usedCondom
        entry.wasPenetrated = wasPenetrated
        entry.partnerDetails = partnerDetails
        entry.skippedNight = skippedNight
        entry.substances = substances
        entry.injectionSubstances = injectionSubstances
        entry.triggerTags = triggerTags ?? []
        entry.changeReasons = changeReasons ?? []
        entry.reportedMemoryGap = reportedMemoryGap ?? false
        entry.memorySafeNow = memorySafeNow ?? false
        entry.memoryInjuries = memoryInjuries ?? false
        entry.memoryConsentConcern = memoryConsentConcern ?? false
        entry.memoryNeedsHelp = memoryNeedsHelp ?? false
        entry.memoryNotes = memoryNotes ?? ""
        entry.sleptYet = sleptYet
        entry.sleepHours = sleepHours
        entry.locationName = locationName
        entry.locationLatitude = locationLatitude
        entry.locationLongitude = locationLongitude
        entry.note = note
        entry.aftercareCompletedAt = aftercareCompletedAt
        entry.aftercareSleepRecorded = aftercareSleepRecorded
        entry.aftercareSleepHours = aftercareSleepHours
        entry.aftercareDrankWater = aftercareDrankWater
        entry.aftercareAteFood = aftercareAteFood
        entry.aftercareFoodNote = aftercareFoodNote
        entry.aftercareSymptoms = aftercareSymptoms
        entry.aftercareMood = aftercareMood.rawValue
        entry.aftercareFeeling = aftercareFeeling
        entry.createdAt = createdAt
    }
}

private struct UserProfileDTO: Codable {
    var id: UUID
    var name: String
    var age: Int
    var dateOfBirth: Date
    var sex: String
    var sexualOrientation: String
    var sexualRole: String
    var isOnPrEP: Bool
    var prepStartDate: Date
    var prepSchedule: String?
    var weightKg: Double
    var heightCm: Double
    var homeAddress: String?
    var medicationsData: Data?
    var profileImageData: Data?
    var createdAt: Date

    init(_ profile: UserProfile) {
        id = profile.id
        name = profile.name
        age = profile.age
        dateOfBirth = profile.dateOfBirth
        sex = profile.sex
        sexualOrientation = profile.sexualOrientation
        sexualRole = profile.sexualRole
        isOnPrEP = profile.isOnPrEP
        prepStartDate = profile.prepStartDate
        prepSchedule = profile.prepSchedule
        weightKg = profile.weightKg
        heightCm = profile.heightCm
        homeAddress = profile.homeAddress
        medicationsData = profile.medicationsData
        profileImageData = profile.profileImageData
        createdAt = profile.createdAt
    }

    func model() -> UserProfile {
        UserProfile(
            id: id,
            name: name,
            age: age,
            dateOfBirth: dateOfBirth,
            sex: ProfileSex(rawValue: sex) ?? .other,
            sexualOrientation: SexualOrientation(rawValue: sexualOrientation) ?? .other,
            sexualRole: SexualRole(rawValue: sexualRole) ?? .notApplicable,
            isOnPrEP: isOnPrEP,
            prepStartDate: prepStartDate,
            prepSchedule: PrEPSchedule(rawValue: prepSchedule ?? PrEPSchedule.daily.rawValue) ?? .daily,
            weightKg: weightKg,
            heightCm: heightCm,
            homeAddress: homeAddress ?? "",
            medications: (try? JSONDecoder().decode([ProfileMedication].self, from: medicationsData ?? Data("[]".utf8))) ?? [],
            profileImageData: profileImageData,
            createdAt: createdAt
        )
    }

    func apply(to profile: UserProfile) {
        profile.name = name
        profile.age = age
        profile.dateOfBirth = dateOfBirth
        profile.sex = sex
        profile.sexualOrientation = sexualOrientation
        profile.sexualRole = sexualRole
        profile.isOnPrEP = isOnPrEP
        profile.prepStartDate = prepStartDate
        profile.prepSchedule = prepSchedule ?? PrEPSchedule.daily.rawValue
        profile.weightKg = weightKg
        profile.heightCm = heightCm
        profile.homeAddress = homeAddress ?? ""
        profile.medicationsData = medicationsData ?? Data("[]".utf8)
        profile.profileImageData = profileImageData
        profile.createdAt = createdAt
    }
}

private struct STDTestDTO: Codable {
    var id: UUID
    var testDate: Date
    var oralResult: String
    var genitalResult: String
    var analResult: String
    var foundSTIs: [String]
    var notes: String
    var createdAt: Date
    var resultPhotoData: Data?

    init(_ record: STDTestRecord) {
        id = record.id
        testDate = record.testDate
        oralResult = record.oralResult
        genitalResult = record.genitalResult
        analResult = record.analResult
        foundSTIs = record.foundSTIs
        notes = record.notes
        createdAt = record.createdAt
        resultPhotoData = record.resultPhotoData
    }

    func model() -> STDTestRecord {
        STDTestRecord(
            id: id,
            testDate: testDate,
            oralResult: STDResultStatus(rawValue: oralResult) ?? .pending,
            genitalResult: STDResultStatus(rawValue: genitalResult) ?? .pending,
            analResult: STDResultStatus(rawValue: analResult) ?? .pending,
            foundSTIs: foundSTIs,
            notes: notes,
            createdAt: createdAt,
            resultPhotoData: resultPhotoData
        )
    }

    func apply(to record: STDTestRecord) {
        record.testDate = testDate
        record.oralResult = oralResult
        record.genitalResult = genitalResult
        record.analResult = analResult
        record.foundSTIs = foundSTIs
        record.notes = notes
        record.createdAt = createdAt
        record.resultPhotoData = resultPhotoData
    }
}

private struct DrugDoseTimerDTO: Codable {
    var id: UUID
    var substanceName: String
    var startedAt: Date
    var durationHours: Double
    var administrationRoute: String
    var personName: String
    var doseNote: String
    var redoseDecision: String
    var redoseDecisionAt: Date?
    var liveActivityID: String
    var createdAt: Date

    init(_ record: DrugDoseTimerRecord) {
        id = record.id
        substanceName = record.substanceName
        startedAt = record.startedAt
        durationHours = record.durationHours
        administrationRoute = record.administrationRoute
        personName = record.personName
        doseNote = record.doseNote
        redoseDecision = record.redoseDecision
        redoseDecisionAt = record.redoseDecisionAt
        liveActivityID = record.liveActivityID
        createdAt = record.createdAt
    }

    func model() -> DrugDoseTimerRecord {
        DrugDoseTimerRecord(
            id: id,
            substanceName: substanceName,
            startedAt: startedAt,
            durationHours: durationHours,
            administrationRoute: AdministrationRoute(rawValue: administrationRoute) ?? .swallowed,
            personName: personName,
            doseNote: doseNote,
            redoseDecision: RedoseDecision(rawValue: redoseDecision) ?? .undecided,
            redoseDecisionAt: redoseDecisionAt,
            liveActivityID: liveActivityID,
            createdAt: createdAt
        )
    }

    func apply(to record: DrugDoseTimerRecord) {
        record.substanceName = substanceName
        record.startedAt = startedAt
        record.durationHours = durationHours
        record.administrationRoute = administrationRoute
        record.personName = personName
        record.doseNote = doseNote
        record.redoseDecision = redoseDecision
        record.redoseDecisionAt = redoseDecisionAt
        record.liveActivityID = liveActivityID
        record.createdAt = createdAt
    }
}

private struct SaferSessionPlanDTO: Codable {
    var id: UUID
    var plannedDate: Date
    var endingDate: Date
    var sleepChecked: Bool
    var hydrationChecked: Bool
    var medicationInteractionChecked: Bool
    var medicationNotes: String
    var plannedSubstanceLimits: String
    var emergencyContactReady: Bool
    var transportPlanned: Bool
    var transportPlan: String
    var condomsPacked: Bool
    var lubePacked: Bool
    var prepTaken: Bool
    var dontMixAcknowledged: Bool
    var partnerModeEnabled: Bool
    var sharedSafetyPlan: String
    var agreedBoundaries: String
    var groupMemberNames: [String]
    var groupCheckInMinutes: Int
    var aftercareReminderForEveryone: Bool
    var createdAt: Date

    init(_ plan: SaferSessionPlan) {
        id = plan.id
        plannedDate = plan.plannedDate
        endingDate = plan.endingDate
        sleepChecked = plan.sleepChecked
        hydrationChecked = plan.hydrationChecked
        medicationInteractionChecked = plan.medicationInteractionChecked
        medicationNotes = plan.medicationNotes
        plannedSubstanceLimits = plan.plannedSubstanceLimits
        emergencyContactReady = plan.emergencyContactReady
        transportPlanned = plan.transportPlanned
        transportPlan = plan.transportPlan
        condomsPacked = plan.condomsPacked
        lubePacked = plan.lubePacked
        prepTaken = plan.prepTaken
        dontMixAcknowledged = plan.dontMixAcknowledged
        partnerModeEnabled = plan.partnerModeEnabled
        sharedSafetyPlan = plan.sharedSafetyPlan
        agreedBoundaries = plan.agreedBoundaries
        groupMemberNames = plan.groupMemberNames
        groupCheckInMinutes = plan.groupCheckInMinutes
        aftercareReminderForEveryone = plan.aftercareReminderForEveryone
        createdAt = plan.createdAt
    }

    func model() -> SaferSessionPlan {
        SaferSessionPlan(
            id: id,
            plannedDate: plannedDate,
            endingDate: endingDate,
            sleepChecked: sleepChecked,
            hydrationChecked: hydrationChecked,
            medicationInteractionChecked: medicationInteractionChecked,
            medicationNotes: medicationNotes,
            plannedSubstanceLimits: plannedSubstanceLimits,
            emergencyContactReady: emergencyContactReady,
            transportPlanned: transportPlanned,
            transportPlan: transportPlan,
            condomsPacked: condomsPacked,
            lubePacked: lubePacked,
            prepTaken: prepTaken,
            dontMixAcknowledged: dontMixAcknowledged,
            partnerModeEnabled: partnerModeEnabled,
            sharedSafetyPlan: sharedSafetyPlan,
            agreedBoundaries: agreedBoundaries,
            groupMemberNames: groupMemberNames,
            groupCheckInMinutes: groupCheckInMinutes,
            aftercareReminderForEveryone: aftercareReminderForEveryone,
            createdAt: createdAt
        )
    }

    func apply(to plan: SaferSessionPlan) {
        plan.plannedDate = plannedDate
        plan.endingDate = endingDate
        plan.sleepChecked = sleepChecked
        plan.hydrationChecked = hydrationChecked
        plan.medicationInteractionChecked = medicationInteractionChecked
        plan.medicationNotes = medicationNotes
        plan.plannedSubstanceLimits = plannedSubstanceLimits
        plan.emergencyContactReady = emergencyContactReady
        plan.transportPlanned = transportPlanned
        plan.transportPlan = transportPlan
        plan.condomsPacked = condomsPacked
        plan.lubePacked = lubePacked
        plan.prepTaken = prepTaken
        plan.dontMixAcknowledged = dontMixAcknowledged
        plan.partnerModeEnabled = partnerModeEnabled
        plan.sharedSafetyPlan = sharedSafetyPlan
        plan.agreedBoundaries = agreedBoundaries
        plan.groupMemberNames = groupMemberNames
        plan.groupCheckInMinutes = groupCheckInMinutes
        plan.aftercareReminderForEveryone = aftercareReminderForEveryone
        plan.createdAt = createdAt
    }
}

private struct RiskCheckDTO: Codable {
    var id: UUID
    var medicationText: String
    var timing: String
    var substanceNames: [String]
    var serotoninLevel: String
    var dehydrationLevel: String
    var stimulantLevel: String
    var warnings: [String]
    var createdAt: Date

    init(_ record: RiskCheckRecord) {
        id = record.id
        medicationText = record.medicationText
        timing = record.timing
        substanceNames = record.substanceNames
        serotoninLevel = record.serotoninLevel
        dehydrationLevel = record.dehydrationLevel
        stimulantLevel = record.stimulantLevel
        warnings = record.warnings
        createdAt = record.createdAt
    }

    func model() -> RiskCheckRecord {
        RiskCheckRecord(
            id: id,
            medicationText: medicationText,
            timing: CombinationTiming(rawValue: timing) ?? .sameSession,
            substanceNames: substanceNames,
            serotoninLevel: serotoninLevel,
            dehydrationLevel: dehydrationLevel,
            stimulantLevel: stimulantLevel,
            warnings: warnings,
            createdAt: createdAt
        )
    }

    func apply(to record: RiskCheckRecord) {
        record.medicationText = medicationText
        record.timing = timing
        record.substanceNames = substanceNames
        record.serotoninLevel = serotoninLevel
        record.dehydrationLevel = dehydrationLevel
        record.stimulantLevel = stimulantLevel
        record.warnings = warnings
        record.createdAt = createdAt
    }
}

private struct JournalDTO: Codable {
    var id: UUID
    var date: Date
    var rememberClearly: String
    var uncomfortableMoments: String
    var consentConcerns: String
    var regrets: String
    var feelsGoodAbout: String
    var photos: [Data]
    var createdAt: Date

    init(_ entry: JournalEntry) {
        id = entry.id
        date = entry.date
        rememberClearly = entry.rememberClearly
        uncomfortableMoments = entry.uncomfortableMoments
        consentConcerns = entry.consentConcerns
        regrets = entry.regrets
        feelsGoodAbout = entry.feelsGoodAbout
        photos = entry.photos
        createdAt = entry.createdAt
    }

    func model() -> JournalEntry {
        JournalEntry(
            id: id,
            date: date,
            rememberClearly: rememberClearly,
            uncomfortableMoments: uncomfortableMoments,
            consentConcerns: consentConcerns,
            regrets: regrets,
            feelsGoodAbout: feelsGoodAbout,
            photos: photos,
            createdAt: createdAt
        )
    }

    func apply(to entry: JournalEntry) {
        entry.date = date
        entry.rememberClearly = rememberClearly
        entry.uncomfortableMoments = uncomfortableMoments
        entry.consentConcerns = consentConcerns
        entry.regrets = regrets
        entry.feelsGoodAbout = feelsGoodAbout
        entry.photos = photos
        entry.createdAt = createdAt
    }
}
