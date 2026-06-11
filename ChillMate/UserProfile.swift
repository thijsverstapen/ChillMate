import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID = UUID()
    var name: String = ""
    var age: Int = 18
    var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -18, to: .now) ?? .now
    var sex: String = ProfileSex.preferNotToSay.rawValue
    var sexualOrientation: String = SexualOrientation.preferNotToSay.rawValue
    var sexualRole: String = SexualRole.preferNotToSay.rawValue
    var isOnPrEP: Bool = false
    var prepStartDate: Date = Date.now
    var prepSchedule: String = PrEPSchedule.daily.rawValue
    var weightKg: Double = 75
    var heightCm: Double = 175
    var homeAddress: String = ""
    var medicationsData: Data = Data("[]".utf8)
    var profileImageData: Data?
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        name: String,
        age: Int,
        dateOfBirth: Date? = nil,
        sex: ProfileSex,
        sexualOrientation: SexualOrientation,
        sexualRole: SexualRole = .preferNotToSay,
        isOnPrEP: Bool,
        prepStartDate: Date = .now,
        prepSchedule: PrEPSchedule = .daily,
        weightKg: Double = 75,
        heightCm: Double = 175,
        homeAddress: String = "",
        medications: [ProfileMedication] = [],
        profileImageData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.dateOfBirth = dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -age, to: .now) ?? .now
        self.sex = sex.rawValue
        self.sexualOrientation = sexualOrientation.rawValue
        self.sexualRole = sexualRole.rawValue
        self.isOnPrEP = isOnPrEP
        self.prepStartDate = prepStartDate
        self.prepSchedule = prepSchedule.rawValue
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.homeAddress = homeAddress
        self.medicationsData = Self.encode(medications)
        self.profileImageData = profileImageData
        self.createdAt = createdAt
    }

    var calculatedAge: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: .now).year ?? age
    }

    var medications: [ProfileMedication] {
        get { Self.decode(medicationsData) }
        set { medicationsData = Self.encode(newValue) }
    }

    private static func encode(_ values: [ProfileMedication]) -> Data {
        (try? JSONEncoder().encode(values)) ?? Data("[]".utf8)
    }

    private static func decode(_ data: Data) -> [ProfileMedication] {
        (try? JSONDecoder().decode([ProfileMedication].self, from: data)) ?? []
    }
}

struct ProfileMedication: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var dosage: String
    var takenAt: Date
    var effectiveHours: Double

    var timingSummary: String {
        "\(dosage.isEmpty ? "No amount saved" : dosage) • \(takenAt.formatted(date: .omitted, time: .shortened)) • \(effectiveHours.formatted(.number.precision(.fractionLength(0...1)))) h"
    }
}

enum PrEPSchedule: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case aroundSex = "Around sex"

    var id: String { rawValue }
}

enum ProfileSex: String, CaseIterable, Identifiable {
    case preferNotToSay = "Prefer not to say"
    case male = "Male"
    case female = "Female"
    case nonBinary = "Non-binary"
    case other = "Other"

    var id: String { rawValue }
}

enum SexualOrientation: String, CaseIterable, Identifiable {
    case preferNotToSay = "Prefer not to say"
    case gay = "Gay"
    case bisexual = "Bisexual"
    case straight = "Straight"
    case queer = "Queer"
    case questioning = "Questioning"
    case other = "Other"

    var id: String { rawValue }
}

enum SexualRole: String, CaseIterable, Identifiable {
    case preferNotToSay = "Prefer not to say"
    case top = "Top"
    case versatile = "Versatile"
    case bottom = "Bottom"
    case side = "Side"
    case notApplicable = "Not applicable"

    var id: String { rawValue }
}
