import CommonCrypto
import CryptoKit
import LocalAuthentication
import SwiftUI

struct AppLockView<Content: View>: View {
    @AppStorage("requiresFaceID") private var requiresFaceID = false
    @AppStorage("requiresPIN") private var requiresPIN = false
    @AppStorage("localEncryptionEnabled") private var localEncryptionEnabled = true
    @AppStorage("autoLockMinutes") private var autoLockMinutes = 0
    @Environment(\.scenePhase) private var scenePhase

    @State private var isUnlocked = false
    @State private var message: String?
    @State private var isAuthenticating = false
    @State private var pinCode = ""
    @State private var backgroundedAt: Date?

    private let content: Content

    private var lockRequired: Bool {
        requiresFaceID || requiresPIN
    }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .opacity(!lockRequired || isUnlocked ? 1 : 0)
                .allowsHitTesting(!lockRequired || isUnlocked)
                .accessibilityHidden(lockRequired && !isUnlocked)

            if lockRequired && !isUnlocked {
                LockScreen(
                    requiresFaceID: requiresFaceID,
                    requiresPIN: requiresPIN,
                    pinCode: $pinCode,
                    message: message,
                    isAuthenticating: isAuthenticating,
                    unlockWithFaceID: unlockWithFaceID,
                    unlockWithPIN: unlockWithPIN
                )
            }
        }
        .task {
            if localEncryptionEnabled {
                LocalSecurityService.applyFileProtection()
            }

            if requiresFaceID {
                await unlockWithFaceID()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if lockRequired, newPhase != .active {
                if backgroundedAt == nil { backgroundedAt = .now }
            }

            if lockRequired, newPhase == .active {
                let elapsed = backgroundedAt.map { Date.now.timeIntervalSince($0) } ?? 0
                let threshold = Double(autoLockMinutes) * 60
                if autoLockMinutes == 0 || elapsed >= threshold {
                    isUnlocked = false
                    pinCode = ""
                }
                backgroundedAt = nil
            }

            if requiresFaceID, newPhase == .active, !isUnlocked {
                Task {
                    await unlockWithFaceID()
                }
            }
        }
        .onChange(of: requiresFaceID) { _, isRequired in
            isUnlocked = !(isRequired || requiresPIN)
        }
        .onChange(of: requiresPIN) { _, isRequired in
            isUnlocked = !(requiresFaceID || isRequired)
        }
    }

    @MainActor
    private func unlockWithFaceID() async {
        guard requiresFaceID, !isUnlocked, !isAuthenticating else {
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let success = try await AppAuthenticator.authenticate(reason: "Unlock ChillMate")
            isUnlocked = success
            message = success ? nil : "Could not unlock ChillMate."
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func unlockWithPIN() {
        guard requiresPIN else {
            return
        }

        if LocalSecurityService.verifyPINFromKeychain(pinCode) {
            isUnlocked = true
            pinCode = ""
            message = nil
        } else {
            pinCode = ""
            message = "That PIN did not match."
        }
    }
}

struct LockScreen: View {
    let requiresFaceID: Bool
    let requiresPIN: Bool
    @Binding var pinCode: String
    let message: String?
    let isAuthenticating: Bool
    let unlockWithFaceID: () async -> Void
    let unlockWithPIN: () -> Void

    var body: some View {
        ZStack {
            DashboardBackdrop()

            VStack(spacing: 22) {
                Image(systemName: requiresFaceID ? "faceid" : "lock.shield.fill")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 94, height: 94)
                    .glassSurface(radius: 47, tint: .white.opacity(0.24))

                VStack(spacing: 8) {
                    Text("ChillMate")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("Unlock your private log.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.78))
                }

                if let message {
                    Text(message)
                        .font(.footnote.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 28)
                }

                if requiresPIN {
                    SecureField("PIN code", text: $pinCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.chillText)
                        .padding(16)
                        .glassSurface(radius: 22, tint: .white.opacity(0.56), interactive: true)
                        .onSubmit(unlockWithPIN)

                    GlassActionButton(prominent: true, action: unlockWithPIN) {
                        Label("Unlock with PIN", systemImage: "number")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(pinCode.count < 4)
                    .opacity(pinCode.count >= 4 ? 1 : 0.55)
                }

                if requiresFaceID {
                    GlassActionButton(prominent: !requiresPIN) {
                        Task {
                            await unlockWithFaceID()
                        }
                    } label: {
                        if isAuthenticating {
                            ProgressView()
                        } else {
                            Label(requiresPIN ? "Use Face ID" : "Unlock", systemImage: "lock.open.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isAuthenticating)
                }
            }
            .padding(28)
            .frame(maxWidth: 360)
        }
    }
}

enum AppAuthenticator {
    static func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        guard unsafe context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            throw AppAuthenticationError.unavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
}

enum AppAuthenticationError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Face ID is not available on this device."
    }
}

enum LocalSecurityService {
    private static let keychainService = "com.BIJTHIJS.ChillMate.pin-credentials"
    private static let keychainHashAccount = "pin-hash-v2"
    private static let keychainSaltAccount = "pin-salt-v2"

    static func savePINToKeychain(pin: String) {
        let saltBytes = (0..<32).map { _ in UInt8.random(in: UInt8.min...UInt8.max) }
        let saltData = Data(saltBytes)
        let hash = pbkdf2Hash(pin: pin, salt: saltData)

        keychainSave(data: hash, account: keychainHashAccount)
        keychainSave(data: saltData, account: keychainSaltAccount)

        // Remove any legacy UserDefaults credentials
        UserDefaults.standard.removeObject(forKey: "appPINHash")
        UserDefaults.standard.removeObject(forKey: "appPINSalt")
    }

    static func verifyPINFromKeychain(_ pin: String) -> Bool {
        guard !pin.isEmpty else { return false }

        // Try Keychain PBKDF2 hash first (v2)
        if let storedHash = keychainRead(account: keychainHashAccount),
           let storedSalt = keychainRead(account: keychainSaltAccount) {
            let inputHash = pbkdf2Hash(pin: pin, salt: storedSalt)
            if inputHash == storedHash {
                return true
            }
        }

        // Fall back to legacy SHA256 UserDefaults credentials and migrate on success
        let legacyHash = UserDefaults.standard.string(forKey: "appPINHash") ?? ""
        let legacySalt = UserDefaults.standard.string(forKey: "appPINSalt") ?? ""
        if !legacyHash.isEmpty, sha256Hash(pin: pin, salt: legacySalt) == legacyHash {
            savePINToKeychain(pin: pin)
            return true
        }

        return false
    }

    static func hasPINCredentials() -> Bool {
        keychainRead(account: keychainHashAccount) != nil ||
        !(UserDefaults.standard.string(forKey: "appPINHash") ?? "").isEmpty
    }

    static func isValidPIN(_ pin: String) -> Bool {
        pin.count >= 4 && pin.count <= 8 && pin.allSatisfy(\.isNumber)
    }

    static func clearPIN() {
        UserDefaults.standard.removeObject(forKey: "requiresPIN")
        UserDefaults.standard.removeObject(forKey: "appPINHash")
        UserDefaults.standard.removeObject(forKey: "appPINSalt")
        keychainDelete(account: keychainHashAccount)
        keychainDelete(account: keychainSaltAccount)
    }

    static func applyFileProtection() {
        Task(priority: .utility) {
            await FileProtectionScheduler.shared.schedule()
        }
    }

    // PBKDF2 with 200,000 iterations — brute-force resistant
    private static func pbkdf2Hash(pin: String, salt: Data) -> Data {
        let pinData = Data(pin.utf8)
        var derivedKey = Data(repeating: 0, count: 32)
        _ = unsafe derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            unsafe pinData.withUnsafeBytes { pinBytes in
                unsafe salt.withUnsafeBytes { saltBytes in
                    unsafe CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pinBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        pinData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        200_000,
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }
        return derivedKey
    }

    // Legacy SHA256 for migration
    private static func sha256Hash(pin: String, salt: String) -> String {
        var data = Data(salt.utf8)
        data.append(Data(pin.utf8))
        let digest = SHA256.hash(data: data)
        return digest.map(\.twoDigitHex).joined()
    }

    private static func keychainSave(data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private static func keychainRead(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = unsafe SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func keychainDelete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    fileprivate static func applyFileProtectionNow() {
        let fileManager = FileManager.default
        let directories: [FileManager.SearchPathDirectory] = [
            .applicationSupportDirectory,
            .documentDirectory,
            .cachesDirectory,
            .libraryDirectory
        ]

        var protectedRoots = Set<URL>()

        for directory in directories {
            guard let root = try? fileManager.url(
                for: directory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ) else {
                continue
            }

            protectedRoots.insert(root)
        }

        protectedRoots.insert(fileManager.temporaryDirectory)

        for root in protectedRoots {
            protectItem(at: root)

            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                protectItem(at: url)
            }
        }
    }

    private static func hashPIN(_ pin: String, salt: String) -> String {
        var data = Data(salt.utf8)
        data.append(Data(pin.utf8))
        let digest = SHA256.hash(data: data)
        return digest.map(\.twoDigitHex).joined()
    }

    private static func protectItem(at url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }
}

private actor FileProtectionScheduler {
    static let shared = FileProtectionScheduler()
    private var lastRun = Date.distantPast

    func schedule() {
        let now = Date.now
        guard now.timeIntervalSince(lastRun) > 5 * 60 else {
            return
        }

        lastRun = now
        Task.detached(priority: .utility) {
            LocalSecurityService.applyFileProtectionNow()
        }
    }
}

private extension UInt8 {
    var twoDigitHex: String {
        let digits = Array("0123456789abcdef")
        return String([digits[Int(self >> 4)], digits[Int(self & 0x0F)]])
    }
}
