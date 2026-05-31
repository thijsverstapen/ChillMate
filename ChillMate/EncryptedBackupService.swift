import CryptoKit
import Foundation
import Security
import SwiftData

@MainActor
final class EncryptedBackupService {
    static let shared = EncryptedBackupService()

    private init() {}

    func encryptedBackupData(localContext: ModelContext) throws -> Data {
        let archive = try ChillMateBackupArchive.make(from: localContext)
        let payload = try archive.encoded()
        let key = try EncryptedBackupKeychain.shared.archiveKey()
        return try encrypt(payload, with: key.data)
    }

    func importEncryptedBackupData(_ data: Data, into context: ModelContext) throws -> ChillMateBackupImportSummary {
        let key = try EncryptedBackupKeychain.shared.archiveKey()
        let payload = try decrypt(data, with: key.data)
        let archive = try ChillMateBackupArchive.decode(from: payload)
        try archive.merge(into: context)
        try context.save()
        return archive.importSummary
    }

    func refreshOnDeviceRecoverySnapshot(localContext: ModelContext) throws -> Bool {
        let archive = try ChillMateBackupArchive.make(from: localContext)
        guard !archive.isEmpty else {
            return false
        }

        let payload = try archive.encoded()
        let key = try EncryptedBackupKeychain.shared.archiveKey()
        let encryptedData = try encrypt(payload, with: key.data)
        try EncryptedBackupKeychain.shared.saveRecoverySnapshot(encryptedData)
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "lastOnDeviceRecoverySnapshotTimestamp")
        return true
    }

    func restoreOnDeviceRecoverySnapshotIfNeeded(into context: ModelContext) throws -> ChillMateBackupImportSummary? {
        guard try ChillMateBackupArchive.storeIsEmpty(in: context) else {
            return nil
        }

        guard let snapshot = try EncryptedBackupKeychain.shared.recoverySnapshot() else {
            return nil
        }

        let key = try EncryptedBackupKeychain.shared.archiveKey()
        let payload = try decrypt(snapshot, with: key.data)
        let archive = try ChillMateBackupArchive.decode(from: payload)
        guard !archive.isEmpty else {
            return nil
        }

        try archive.merge(into: context)
        try context.save()
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "lastOnDeviceRecoveryRestoreTimestamp")
        return archive.importSummary
    }

    func deleteOnDeviceRecoverySnapshot() throws {
        try EncryptedBackupKeychain.shared.deleteRecoverySnapshot()
        UserDefaults.standard.removeObject(forKey: "lastOnDeviceRecoverySnapshotTimestamp")
        UserDefaults.standard.removeObject(forKey: "lastOnDeviceRecoveryRestoreTimestamp")
    }

    private func encrypt(_ payload: Data, with keyData: Data) throws -> Data {
        let key = SymmetricKey(data: keyData)
        let sealedBox = try AES.GCM.seal(payload, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptedBackupError.encryptionFailed
        }
        return combined
    }

    private func decrypt(_ payload: Data, with keyData: Data) throws -> Data {
        do {
            let key = SymmetricKey(data: keyData)
            let sealedBox = try AES.GCM.SealedBox(combined: payload)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw EncryptedBackupError.decryptionFailed
        }
    }
}

@MainActor
final class ICloudBackupService {
    static let shared = ICloudBackupService()

    private let folderName = "ChillMate"
    private let latestFileName = "ChillMate-iCloud-Encrypted-Backup.cmbak"

    private init() {}

    var isAvailable: Bool {
        FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
    }

    var statusLine: String {
        guard isAvailable else {
            return "iCloud Drive is not available on this device."
        }

        if let latest = try? latestBackupDate() {
            return "Latest encrypted iCloud backup: \(latest.formatted(date: .abbreviated, time: .shortened))."
        }

        return "iCloud is ready. No ChillMate backup has been saved yet."
    }

    func saveLatestBackup(localContext: ModelContext) throws -> Date {
        let directory = try backupDirectory()
        let data = try EncryptedBackupService.shared.encryptedBackupData(localContext: localContext)
        let latestURL = directory.appendingPathComponent(latestFileName)
        try data.write(to: latestURL, options: [.atomic, .completeFileProtection])

        let archiveURL = directory.appendingPathComponent(timestampedFileName())
        try data.write(to: archiveURL, options: [.atomic, .completeFileProtection])

        let date = Date.now
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "lastICloudBackupTimestamp")
        UserDefaults.standard.set("Encrypted iCloud backup saved.", forKey: "lastICloudBackupStatus")
        return date
    }

    func restoreLatestBackup(into context: ModelContext) throws -> ChillMateBackupImportSummary {
        let url = try latestBackupURL()
        let data = try Data(contentsOf: url)
        let summary = try EncryptedBackupService.shared.importEncryptedBackupData(data, into: context)
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "lastICloudRestoreTimestamp")
        UserDefaults.standard.set("Restored \(summary.totalItems) items from iCloud.", forKey: "lastICloudBackupStatus")
        return summary
    }

    func latestBackupDate() throws -> Date? {
        let url = try latestBackupURL()
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
        return values.contentModificationDate
    }

    func deleteBackups() throws {
        guard let directory = try? backupDirectory() else {
            return
        }

        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in contents where url.pathExtension == "cmbak" {
            try FileManager.default.removeItem(at: url)
        }

        UserDefaults.standard.removeObject(forKey: "lastICloudBackupTimestamp")
        UserDefaults.standard.removeObject(forKey: "lastICloudRestoreTimestamp")
        UserDefaults.standard.set("iCloud backups deleted.", forKey: "lastICloudBackupStatus")
    }

    private func latestBackupURL() throws -> URL {
        let url = try backupDirectory().appendingPathComponent(latestFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ICloudBackupError.noBackupFound
        }
        return url
    }

    private func backupDirectory() throws -> URL {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            throw ICloudBackupError.iCloudUnavailable
        }

        let directory = containerURL
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func timestampedFileName() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let stamp = formatter.string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        return "ChillMate-iCloud-Encrypted-Backup-\(stamp).cmbak"
    }
}

struct ChillMateBackupImportSummary {
    let profiles: Int
    let nightEntries: Int
    let stdTests: Int
    let drugTimers: Int
    let saferPlans: Int
    let riskChecks: Int
    let journals: Int

    var totalItems: Int {
        profiles + nightEntries + stdTests + drugTimers + saferPlans + riskChecks + journals
    }

    var displayText: String {
        "Imported \(totalItems) items: \(profiles) profiles, \(nightEntries) logs, \(stdTests) STI tests, \(drugTimers) timers, \(saferPlans) plans, \(riskChecks) risk checks, and \(journals) journal entries."
    }
}

enum ICloudBackupError: LocalizedError {
    case iCloudUnavailable
    case noBackupFound

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            "iCloud Drive is not available. Sign in to iCloud and make sure iCloud Drive is on."
        case .noBackupFound:
            "No ChillMate iCloud backup was found yet."
        }
    }
}

enum EncryptedBackupError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            "Could not seal the encrypted backup archive."
        case .decryptionFailed:
            "Could not unlock this backup. Use a ChillMate backup made on this device with the same protected backup key."
        case .keychainFailure(let status):
            "Keychain failed with status \(status)."
        }
    }
}

@MainActor
private final class EncryptedBackupKeychain {
    static let shared = EncryptedBackupKeychain()

    private let service = "com.BIJTHIJS.ChillMate.encrypted-backup"
    private let account = "primary-backup-key-v1"
    private let recoverySnapshotAccount = "on-device-recovery-snapshot-v1"

    private init() {}

    func archiveKey() throws -> (data: Data, id: String) {
        if let keyData = try readData(account: account) {
            return (keyData, keyID(for: keyData))
        }

        var keyBytes = [UInt8](repeating: 0, count: 32)
        let status = unsafe keyBytes.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return errSecParam
            }

            return unsafe SecRandomCopyBytes(kSecRandomDefault, buffer.count, baseAddress)
        }
        guard status == errSecSuccess else {
            throw EncryptedBackupError.keychainFailure(status)
        }

        let keyData = Data(keyBytes)
        try saveData(keyData, account: account)
        return (keyData, keyID(for: keyData))
    }

    func recoverySnapshot() throws -> Data? {
        try readData(account: recoverySnapshotAccount)
    }

    func saveRecoverySnapshot(_ data: Data) throws {
        try saveData(data, account: recoverySnapshotAccount)
    }

    func deleteRecoverySnapshot() throws {
        try deleteData(account: recoverySnapshotAccount)
    }

    private func readData(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = unsafe SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw EncryptedBackupError.keychainFailure(status)
        }

        return result as? Data
    }

    private func saveData(_ data: Data, account: String) throws {
        var item = baseQuery(account: account)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(item as CFDictionary, nil)
        if status == errSecDuplicateItem {
            SecItemDelete(baseQuery(account: account) as CFDictionary)
            let retryStatus = SecItemAdd(item as CFDictionary, nil)
            guard retryStatus == errSecSuccess else {
                throw EncryptedBackupError.keychainFailure(retryStatus)
            }
            return
        }

        guard status == errSecSuccess else {
            throw EncryptedBackupError.keychainFailure(status)
        }
    }

    private func deleteData(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw EncryptedBackupError.keychainFailure(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func keyID(for keyData: Data) -> String {
        String(SHA256.hash(data: keyData).map(\.twoDigitHex).joined().prefix(16))
    }
}

private extension UInt8 {
    var twoDigitHex: String {
        let digits = Array("0123456789abcdef")
        return String([digits[Int(self >> 4)], digits[Int(self & 0x0F)]])
    }
}

private struct ChillMateBackupArchive: Codable {
    var schemaVersion: Int = 1
    var exportedAt: Date = .now
    var deviceID: String = EncryptedBackupDevice.identity
    var nightEntries: [NightEntryDTO]
    var profiles: [UserProfileDTO]
    var stdTests: [STDTestDTO]
    var drugTimers: [DrugDoseTimerDTO]
    var saferPlans: [SaferSessionPlanDTO]
    var riskChecks: [RiskCheckDTO]
    var journals: [JournalDTO]

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
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<NightEntry>()).map { ($0.id, $0) })
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
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<UserProfile>()).map { ($0.id, $0) })
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
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<STDTestRecord>()).map { ($0.id, $0) })
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
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<DrugDoseTimerRecord>()).map { ($0.id, $0) })
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
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<SaferSessionPlan>()).map { ($0.id, $0) })
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
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<RiskCheckRecord>()).map { ($0.id, $0) })
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
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<JournalEntry>()).map { ($0.id, $0) })
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

    init(_ record: STDTestRecord) {
        id = record.id
        testDate = record.testDate
        oralResult = record.oralResult
        genitalResult = record.genitalResult
        analResult = record.analResult
        foundSTIs = record.foundSTIs
        notes = record.notes
        createdAt = record.createdAt
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
            createdAt: createdAt
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
