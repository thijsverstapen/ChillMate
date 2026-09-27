import CryptoKit
import Foundation
import OSLog
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
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: DefaultsKey.lastOnDeviceRecoverySnapshotTimestamp)
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
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: DefaultsKey.lastOnDeviceRecoveryRestoreTimestamp)
        return archive.importSummary
    }

    func deleteOnDeviceRecoverySnapshot() throws {
        try EncryptedBackupKeychain.shared.deleteRecoverySnapshot()
        UserDefaults.standard.removeObject(forKey: DefaultsKey.lastOnDeviceRecoverySnapshotTimestamp)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.lastOnDeviceRecoveryRestoreTimestamp)
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

/// What is left of the encrypted iCloud Drive backup, which 5.1.0 removed.
///
/// It saved a snapshot to iCloud Drive under a key that never leaves the phone,
/// so only the iPhone that made it could open it: no help on a new phone, which
/// is what iCloud sync is for, and the on-device recovery snapshot already covers
/// mistakes on this one. Two iCloud switches that sounded alike and did
/// different things were one too many.
///
/// The files it wrote are removed once, so nothing that nothing can use is left
/// in somebody's iCloud Drive. They are ChillMate's own, in ChillMate's own
/// folder, and only ChillMate's `.cmbak` files are touched.
enum LegacyICloudBackupFiles {
    /// Deletes every backup file earlier versions saved, and returns how many.
    /// Throws when iCloud Drive cannot be reached, so the caller can try again.
    ///
    /// Not on the main thread: finding the iCloud container can block.
    nonisolated static func removeAll() throws -> Int {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let directory = container
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("ChillMate", isDirectory: true)
        guard FileManager.default.fileExists(atPath: directory.path) else { return 0 }

        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "cmbak" }
        for file in files {
            try FileManager.default.removeItem(at: file)
        }
        return files.count
    }

    /// Once per install, and only for somebody who ever turned the backup on.
    @MainActor
    static func removeIfNeeded(defaults: UserDefaults = .standard) async {
        guard !defaults.bool(forKey: DefaultsKey.legacyICloudBackupsRemoved) else { return }

        let everUsed = defaults.object(forKey: DefaultsKey.legacyICloudBackupEnabled) != nil
            || defaults.double(forKey: DefaultsKey.legacyLastICloudBackupTimestamp) > 0
        if everUsed {
            do {
                let removed = try await Task.detached(priority: .utility) { try removeAll() }.value
                Logger.data.info("Removed \(removed, privacy: .public) legacy iCloud backup files")
            } catch {
                // Signed out of iCloud, or iCloud Drive off. The files are
                // unreadable without this phone's key either way; try again later.
                return
            }
        }

        for key in DefaultsKey.legacyICloudBackupKeys {
            defaults.removeObject(forKey: key)
        }
        defaults.set(true, forKey: DefaultsKey.legacyICloudBackupsRemoved)
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

    /// One line describing what an import or restore brought back.
    ///
    /// Assembled from seven separately localized fragments and joined by
    /// `ListFormatStyle` rather than written as one English sentence with commas
    /// and a hard-coded "and". Each noun can then take its own plural form, and
    /// languages that build lists differently ("A, B und C") stay correct without
    /// a translator having to reproduce English punctuation.
    ///
    /// This text is shown in the restore confirmation and, before the Settings
    /// call sites stopped duplicating it, was persisted as the iCloud status line
    /// too. It is user-facing either way, so it cannot stay an English literal in
    /// an app that ships five languages.
    var displayText: String {
        let breakdown = [
            String(localized: "\(profiles) profiles", comment: "Restore summary fragment: number of user profiles"),
            String(localized: "\(nightEntries) logs", comment: "Restore summary fragment: number of logged nights"),
            String(localized: "\(stdTests) STI tests", comment: "Restore summary fragment: number of STI test records"),
            String(localized: "\(drugTimers) timers", comment: "Restore summary fragment: number of dose timers"),
            String(localized: "\(saferPlans) plans", comment: "Restore summary fragment: number of safer session plans"),
            String(localized: "\(riskChecks) risk checks", comment: "Restore summary fragment: number of combination risk checks"),
            String(localized: "\(journals) journal entries", comment: "Restore summary fragment: number of journal entries")
        ].formatted(.list(type: .and))

        return String(localized: "Imported \(totalItems) items: \(breakdown).")
    }
}

enum EncryptedBackupError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            String(localized: "Could not seal the encrypted backup archive.")
        case .decryptionFailed:
            String(localized: "Could not unlock this backup. Use a ChillMate backup made on this device with the same protected backup key.")
        case .keychainFailure(let status):
            "Keychain failed with status \(status)."
        }
    }
}

@MainActor
/// Where the backup key lives, and for how long.
///
/// The whole lifecycle, written down because the consequences are not obvious
/// from the call sites and one of them is user-visible.
///
/// **Minting.** One 32-byte key from `SecRandomCopyBytes`, made the first time
/// anything is encrypted and never rotated. There is no passphrase and nothing
/// is derived from user input, so there is no password to forget and no
/// weak-passphrase attack to worry about.
///
/// **Storage.** The system Keychain, under
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Two things follow from that
/// attribute and both are deliberate:
///
/// * The key is unreadable while the device is locked, so a backup cannot be
///   written or read from the background on a locked phone.
/// * `ThisDeviceOnly` excludes it from iCloud Keychain, so the key never leaves
///   this device and no copy of it exists anywhere else. That is the property
///   that lets ChillMate describe itself as holding nothing.
///
/// **Use.** AES-GCM via CryptoKit, sealing the encoded archive. The same key
/// encrypts the on-device recovery snapshot and any file somebody exports.
///
/// **The consequence worth knowing.** Because the key is device-only, an
/// encrypted backup can only be opened by the device that made it. An exported
/// file does not move your history to a *new* phone, because the key does not go
/// with it; iCloud sync is what does that. The export card says so. Making the
/// file portable means introducing a passphrase, which means a key derived from
/// something a person can forget — that is a product decision, not a refactor.
///
/// Until 5.1.0 there was also an encrypted iCloud Drive backup under this key,
/// with the same limit and no word about it. It is gone; see
/// `LegacyICloudBackupFiles`.
///
/// **End of life.** The key is destroyed with the Keychain item, which happens
/// when the app is deleted. Deleting the app therefore makes every existing
/// encrypted backup permanently unreadable.
/// `deleteOnDeviceRecoverySnapshot()` removes the snapshot but deliberately
/// leaves the key, so a snapshot taken afterwards is still readable.
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
        let status = keyBytes.withUnsafeMutableBytes { buffer in
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

/// Conformance declared here rather than beside the protocol: `EncryptedBackups`
/// inherits `Sendable`, and Swift treats a Sendable conformance in another
/// file as retroactive — a warning today and an error in a future language
/// mode.
extension EncryptedBackupService: EncryptedBackups {}
