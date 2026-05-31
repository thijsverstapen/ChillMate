import Foundation
import ActivityKit
import SwiftData

@Model
final class STDTestRecord {
    var id: UUID = UUID()
    var testDate: Date = Date.now
    var oralResult: String = STDResultStatus.pending.rawValue
    var genitalResult: String = STDResultStatus.pending.rawValue
    var analResult: String = STDResultStatus.pending.rawValue
    var foundSTIsData: Data = Data("[]".utf8)
    var notes: String = ""
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        testDate: Date,
        oralResult: STDResultStatus = .pending,
        genitalResult: STDResultStatus = .pending,
        analResult: STDResultStatus = .pending,
        foundSTIs: [String] = [],
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.testDate = testDate
        self.oralResult = oralResult.rawValue
        self.genitalResult = genitalResult.rawValue
        self.analResult = analResult.rawValue
        self.foundSTIsData = Self.encode(foundSTIs)
        self.notes = notes
        self.createdAt = createdAt
    }

    var foundSTIs: [String] {
        get { Self.decode(foundSTIsData) }
        set { foundSTIsData = Self.encode(newValue) }
    }

    var resultsDueDate: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: testDate) ?? testDate.addingTimeInterval(7 * 24 * 60 * 60)
    }

    var hasPositiveResult: Bool {
        oralResult == STDResultStatus.positive.rawValue ||
        genitalResult == STDResultStatus.positive.rawValue ||
        analResult == STDResultStatus.positive.rawValue
    }

    private static func encode(_ values: [String]) -> Data {
        (try? JSONEncoder().encode(values)) ?? Data("[]".utf8)
    }

    private static func decode(_ data: Data) -> [String] {
        (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

enum STDResultStatus: String, CaseIterable, Identifiable {
    case pending = "Pending"
    case negative = "Negative"
    case positive = "Positive"
    case inconclusive = "Inconclusive"

    var id: String { rawValue }
}

@Model
final class DrugDoseTimerRecord {
    var id: UUID = UUID()
    var substanceName: String = Substance.cannabis.rawValue
    var startedAt: Date = Date.now
    var durationHours: Double = 2
    var administrationRoute: String = AdministrationRoute.swallowed.rawValue
    var personName: String = ""
    var doseNote: String = ""
    var redoseDecision: String = RedoseDecision.undecided.rawValue
    var redoseDecisionAt: Date?
    var liveActivityID: String = ""
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        substanceName: String,
        startedAt: Date,
        durationHours: Double,
        administrationRoute: AdministrationRoute = .swallowed,
        personName: String = "",
        doseNote: String = "",
        redoseDecision: RedoseDecision = .undecided,
        redoseDecisionAt: Date? = nil,
        liveActivityID: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.substanceName = substanceName
        self.startedAt = startedAt
        self.durationHours = durationHours
        self.administrationRoute = administrationRoute.rawValue
        self.personName = personName
        self.doseNote = doseNote
        self.redoseDecision = redoseDecision.rawValue
        self.redoseDecisionAt = redoseDecisionAt
        self.liveActivityID = liveActivityID
        self.createdAt = createdAt
    }

    var endsAt: Date {
        startedAt.addingTimeInterval(durationHours * 60 * 60)
    }
}

enum AdministrationRoute: String, CaseIterable, Identifiable {
    case sniffed = "Sniffed"
    case injected = "Injected"
    case swallowed = "Swallowed"
    case smoked = "Smoked"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sniffed:
            "Nasal"
        case .injected:
            "Injection"
        case .swallowed:
            "Oral"
        case .smoked:
            "Inhaled"
        }
    }

    var symbolName: String {
        switch self {
        case .sniffed:
            "nose.fill"
        case .injected:
            "syringe.fill"
        case .swallowed:
            "mouth.fill"
        case .smoked:
            "smoke.fill"
        }
    }
}

@Model
final class SaferSessionPlan {
    var id: UUID = UUID()
    var plannedDate: Date = Date.now
    var endingDate: Date = Date.now.addingTimeInterval(4 * 60 * 60)
    var sleepChecked: Bool = false
    var hydrationChecked: Bool = false
    var medicationInteractionChecked: Bool = false
    var medicationNotes: String = ""
    var plannedSubstanceLimits: String = ""
    var emergencyContactReady: Bool = false
    var transportPlanned: Bool = false
    var transportPlan: String = ""
    var condomsPacked: Bool = false
    var lubePacked: Bool = false
    var prepTaken: Bool = false
    var dontMixAcknowledged: Bool = false
    var partnerModeEnabled: Bool = false
    var sharedSafetyPlan: String = ""
    var agreedBoundaries: String = ""
    var groupMemberNamesData: Data = Data("[]".utf8)
    var groupCheckInMinutes: Int = 90
    var aftercareReminderForEveryone: Bool = false
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        plannedDate: Date = .now,
        endingDate: Date? = nil,
        sleepChecked: Bool = false,
        hydrationChecked: Bool = false,
        medicationInteractionChecked: Bool = false,
        medicationNotes: String = "",
        plannedSubstanceLimits: String = "",
        emergencyContactReady: Bool = false,
        transportPlanned: Bool = false,
        transportPlan: String = "",
        condomsPacked: Bool = false,
        lubePacked: Bool = false,
        prepTaken: Bool = false,
        dontMixAcknowledged: Bool = false,
        partnerModeEnabled: Bool = false,
        sharedSafetyPlan: String = "",
        agreedBoundaries: String = "",
        groupMemberNames: [String] = [],
        groupCheckInMinutes: Int = 90,
        aftercareReminderForEveryone: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.plannedDate = plannedDate
        self.endingDate = endingDate ?? Calendar.current.date(byAdding: .hour, value: 4, to: plannedDate) ?? plannedDate.addingTimeInterval(4 * 60 * 60)
        self.sleepChecked = sleepChecked
        self.hydrationChecked = hydrationChecked
        self.medicationInteractionChecked = medicationInteractionChecked
        self.medicationNotes = medicationNotes
        self.plannedSubstanceLimits = plannedSubstanceLimits
        self.emergencyContactReady = emergencyContactReady
        self.transportPlanned = transportPlanned
        self.transportPlan = transportPlan
        self.condomsPacked = condomsPacked
        self.lubePacked = lubePacked
        self.prepTaken = prepTaken
        self.dontMixAcknowledged = dontMixAcknowledged
        self.partnerModeEnabled = partnerModeEnabled
        self.sharedSafetyPlan = sharedSafetyPlan
        self.agreedBoundaries = agreedBoundaries
        self.groupMemberNamesData = Self.encode(groupMemberNames)
        self.groupCheckInMinutes = groupCheckInMinutes
        self.aftercareReminderForEveryone = aftercareReminderForEveryone
        self.createdAt = createdAt
    }

    var groupMemberNames: [String] {
        get { Self.decode(groupMemberNamesData) }
        set { groupMemberNamesData = Self.encode(newValue) }
    }

    var completedCount: Int {
        [
            sleepChecked,
            hydrationChecked,
            medicationInteractionChecked,
            emergencyContactReady,
            transportPlanned,
            condomsPacked,
            lubePacked,
            prepTaken,
            dontMixAcknowledged
        ].filter { $0 }.count
    }

    private static func encode(_ values: [String]) -> Data {
        (try? JSONEncoder().encode(values)) ?? Data("[]".utf8)
    }

    private static func decode(_ data: Data) -> [String] {
        (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

@Model
final class JournalEntry {
    var id: UUID = UUID()
    var date: Date = Date.now
    var rememberClearly: String = ""
    var uncomfortableMoments: String = ""
    var consentConcerns: String = ""
    var regrets: String = ""
    var feelsGoodAbout: String = ""
    var photoDataBlobs: Data = Data("[]".utf8)
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        date: Date = .now,
        rememberClearly: String = "",
        uncomfortableMoments: String = "",
        consentConcerns: String = "",
        regrets: String = "",
        feelsGoodAbout: String = "",
        photos: [Data] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.rememberClearly = rememberClearly
        self.uncomfortableMoments = uncomfortableMoments
        self.consentConcerns = consentConcerns
        self.regrets = regrets
        self.feelsGoodAbout = feelsGoodAbout
        self.photoDataBlobs = Self.encode(photos)
        self.createdAt = createdAt
    }

    var photos: [Data] {
        get { Self.decode(photoDataBlobs) }
        set { photoDataBlobs = Self.encode(newValue) }
    }

    private static func encode(_ values: [Data]) -> Data {
        (try? JSONEncoder().encode(values.map { $0.base64EncodedString() })) ?? Data("[]".utf8)
    }

    private static func decode(_ data: Data) -> [Data] {
        let strings = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        return strings.compactMap { Data(base64Encoded: $0) }
    }
}

@Model
final class RiskCheckRecord {
    var id: UUID = UUID()
    var medicationText: String = ""
    var timing: String = CombinationTiming.sameSession.rawValue
    var substanceNamesData: Data = Data("[]".utf8)
    var serotoninLevel: String = ""
    var dehydrationLevel: String = ""
    var stimulantLevel: String = ""
    var warningsData: Data = Data("[]".utf8)
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        medicationText: String = "",
        timing: CombinationTiming,
        substanceNames: [String],
        serotoninLevel: String,
        dehydrationLevel: String,
        stimulantLevel: String,
        warnings: [String],
        createdAt: Date = .now
    ) {
        self.id = id
        self.medicationText = medicationText
        self.timing = timing.rawValue
        self.substanceNamesData = Self.encode(substanceNames)
        self.serotoninLevel = serotoninLevel
        self.dehydrationLevel = dehydrationLevel
        self.stimulantLevel = stimulantLevel
        self.warningsData = Self.encode(warnings)
        self.createdAt = createdAt
    }

    var substanceNames: [String] {
        get { Self.decode(substanceNamesData) }
        set { substanceNamesData = Self.encode(newValue) }
    }

    var warnings: [String] {
        get { Self.decode(warningsData) }
        set { warningsData = Self.encode(newValue) }
    }

    private static func encode(_ values: [String]) -> Data {
        (try? JSONEncoder().encode(values)) ?? Data("[]".utf8)
    }

    private static func decode(_ data: Data) -> [String] {
        (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

enum RedoseDecision: String, CaseIterable, Identifiable {
    case undecided = "Undecided"
    case redosed = "Still redosed"
    case avoided = "Did not redose"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .undecided:
            "Not answered"
        case .redosed:
            "Logged more"
        case .avoided:
            "Paused or stopped"
        }
    }
}

enum DrugTimerLiveActivityController {
    @MainActor
    static func start(for timer: DrugDoseTimerRecord, now: Date = .now) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let attributes = DrugTimerActivityAttributes(timerID: timer.id, substanceName: timer.substanceName)
        let contentState = DrugTimerActivityAttributes.ContentState(
            substanceName: timer.substanceName,
            endsAt: timer.endsAt,
            redoseNudgeActive: timer.redoseNudgeIsActive(at: now)
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: contentState, staleDate: timer.endsAt),
                pushType: nil
            )
            timer.liveActivityID = activity.id
        } catch {
            timer.liveActivityID = ""
            print("[ChillMate] Live Activity request failed: \(error)")
        }
    }

    @MainActor
    static func update(_ timer: DrugDoseTimerRecord, now: Date = .now) async {
        guard !timer.liveActivityID.isEmpty else {
            return
        }

        let contentState = DrugTimerActivityAttributes.ContentState(
            substanceName: timer.substanceName,
            endsAt: timer.endsAt,
            redoseNudgeActive: timer.redoseNudgeIsActive(at: now)
        )

        for activity in Activity<DrugTimerActivityAttributes>.activities where activity.id == timer.liveActivityID {
            await activity.update(ActivityContent(state: contentState, staleDate: timer.endsAt))
        }
    }

    @MainActor
    static func end(_ timer: DrugDoseTimerRecord, now: Date = .now) async {
        guard !timer.liveActivityID.isEmpty else {
            return
        }

        let contentState = DrugTimerActivityAttributes.ContentState(
            substanceName: timer.substanceName,
            endsAt: timer.endsAt,
            redoseNudgeActive: false
        )

        for activity in Activity<DrugTimerActivityAttributes>.activities where activity.id == timer.liveActivityID {
            await activity.end(
                ActivityContent(state: contentState, staleDate: now),
                dismissalPolicy: .immediate
            )
        }
    }
}

extension DrugDoseTimerRecord {
    func effectProgress(at date: Date) -> Double {
        let total = max(60, endsAt.timeIntervalSince(startedAt))
        let elapsed = max(0, date.timeIntervalSince(startedAt))
        return min(1, max(0, elapsed / total))
    }

    func redoseNudgeIsActive(at date: Date) -> Bool {
        let progress = effectProgress(at: date)
        return endsAt > date && progress >= 0.40 && progress <= 1
    }
}
