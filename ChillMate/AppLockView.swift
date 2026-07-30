import CommonCrypto
import CryptoKit
import LocalAuthentication
import SwiftUI
import UIKit

struct AppLockView<Content: View>: View {
    @AppStorage(DefaultsKey.requiresFaceID) private var requiresFaceID = false
    @AppStorage(DefaultsKey.requiresPIN) private var requiresPIN = false
    @AppStorage(DefaultsKey.localEncryptionEnabled) private var localEncryptionEnabled = true
    @AppStorage(DefaultsKey.autoLockMinutes) private var autoLockMinutes = 0
    @AppStorage(DefaultsKey.screenPrivacyEnabled) private var screenPrivacyEnabled = true
    @Environment(\.scenePhase) private var scenePhase

    @State private var isUnlocked = false
    @State private var message: String?
    @State private var isAuthenticating = false
    @State private var pinCode = ""
    @State private var backgroundedAt: Date?
    @State private var showAppSwitcherCover = false
    @State private var isScreenCaptured = false
    @State private var lockoutRemaining: Int?
    @State private var lockoutTask: Task<Void, Never>?

    private var showPrivacyCover: Bool {
        screenPrivacyEnabled && (showAppSwitcherCover || isScreenCaptured)
    }

    private func screenIsCaptured() -> Bool {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        return scene?.screen.isCaptured ?? false
    }

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
                    isLockedOut: (lockoutRemaining ?? 0) > 0,
                    unlockWithFaceID: unlockWithFaceID,
                    unlockWithPIN: unlockWithPIN
                )
            }

            if showPrivacyCover {
                PrivacyCoverView(isRecording: isScreenCaptured)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showPrivacyCover)
        .task {
            if localEncryptionEnabled {
                LocalSecurityService.applyFileProtection()
            }

            isScreenCaptured = screenIsCaptured()

            // A lockout persists across launches, so pick it up again here rather
            // than presenting a fresh-looking PIN field that silently refuses.
            if PINThrottle.isLockedOut {
                startLockoutCountdown()
            }

            if requiresFaceID {
                await unlockWithFaceID()
            }
        }
        .onDisappear { lockoutTask?.cancel() }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            isScreenCaptured = screenIsCaptured()
        }
        // One observer, not two. Two .onChange(of: scenePhase) modifiers on the same
        // view both fire with no defined relative order, which is a poor way to
        // sequence "cover the screen" against "decide whether to re-lock".
        .onChange(of: scenePhase) { _, newPhase in
            updatePrivacyCover(for: newPhase)
            updateLockState(for: newPhase)
        }
        .onChange(of: requiresFaceID) { _, isRequired in
            isUnlocked = !(isRequired || requiresPIN)
        }
        .onChange(of: requiresPIN) { _, isRequired in
            isUnlocked = !(requiresFaceID || isRequired)
        }
    }

    /// Covers the App Switcher snapshot and any backgrounded state so a glance at
    /// open apps never reveals the log. Skipped while the system auth sheet is up
    /// (it briefly makes the scene .inactive).
    private func updatePrivacyCover(for phase: ScenePhase) {
        switch phase {
        case .active:
            showAppSwitcherCover = false
        default:
            if !isAuthenticating { showAppSwitcherCover = true }
        }
    }

    /// While the Face ID / system auth dialog is on screen the scene briefly turns
    /// .inactive. Ignoring phase changes during authentication, and only treating a
    /// real .background as "the user left the app", prevents the endless
    /// lock → prompt → lock loop behind the Face ID wall.
    private func updateLockState(for phase: ScenePhase) {
        guard lockRequired, !isAuthenticating else { return }

        switch phase {
        case .background:
            if backgroundedAt == nil { backgroundedAt = .now }
        case .active:
            guard let leftAt = backgroundedAt else { return }
            backgroundedAt = nil
            let elapsed = Date.now.timeIntervalSince(leftAt)
            let threshold = Double(autoLockMinutes) * 60
            if autoLockMinutes == 0 || elapsed >= threshold {
                isUnlocked = false
                pinCode = ""
                if PINThrottle.isLockedOut { startLockoutCountdown() }
                if requiresFaceID {
                    Task { await unlockWithFaceID() }
                }
            }
        default:
            break
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
            let success = try await AppAuthenticator.authenticate(reason: String(localized: "Unlock ChillMate"))
            isUnlocked = success
            message = success ? nil : String(localized: "Could not unlock ChillMate.")
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func unlockWithPIN() {
        guard requiresPIN else {
            return
        }

        // Refuse while locked out, so the throttle cannot be bypassed by tapping
        // faster than the countdown redraws.
        if let remaining = lockoutRemaining, remaining > 0 {
            pinCode = ""
            message = lockoutMessage(remaining)
            return
        }

        if LocalSecurityService.verifyPINFromKeychain(pinCode) {
            PINThrottle.recordSuccess()
            lockoutRemaining = nil
            isUnlocked = true
            pinCode = ""
            message = nil
        } else {
            pinCode = ""
            if PINThrottle.recordFailure() != nil {
                startLockoutCountdown()
                message = lockoutMessage(PINThrottle.remainingLockout)
            } else {
                let left = PINThrottle.freeAttempts - PINThrottle.failedAttempts
                message = left > 0
                    ? String(localized: "That PIN did not match. \(left) attempts left.")
                    : String(localized: "That PIN did not match.")
            }
        }
    }

    private func lockoutMessage(_ seconds: Int) -> String {
        // Rounds up. Integer division reported "1 minute" with 119 seconds still to
        // go, so the countdown sat on the same number for a full extra minute and
        // read as a stuck screen.
        seconds >= 60
            ? String(localized: "Too many attempts. Try again in \((seconds + 59) / 60) minutes.")
            : String(localized: "Too many attempts. Try again in \(seconds) seconds.")
    }

    /// Ticks the visible countdown once a second while a lockout is running.
    private func startLockoutCountdown() {
        lockoutTask?.cancel()
        lockoutRemaining = PINThrottle.remainingLockout
        lockoutTask = Task {
            while !Task.isCancelled, PINThrottle.isLockedOut {
                lockoutRemaining = PINThrottle.remainingLockout
                message = lockoutMessage(PINThrottle.remainingLockout)
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            lockoutRemaining = nil
            message = nil
        }
    }
}

struct LockScreen: View {
    let requiresFaceID: Bool
    let requiresPIN: Bool
    @Binding var pinCode: String
    let message: String?
    let isAuthenticating: Bool
    var isLockedOut: Bool = false
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
                    .disabled(pinCode.count < 4 || isLockedOut)
                    .opacity(pinCode.count >= 4 && !isLockedOut ? 1 : 0.55)
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

/// Full-screen branded cover that hides log content from the App Switcher snapshot
/// and from active screen recording / mirroring. No sensitive data is drawn.
struct PrivacyCoverView: View {
    let isRecording: Bool

    var body: some View {
        ZStack {
            DashboardBackdrop()

            VStack(spacing: 16) {
                ChillMateBrandMark(size: 76)

                Text("ChillMate")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                if isRecording {
                    Label("Hidden while your screen is being recorded", systemImage: "record.circle")
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 32)
                }
            }
            .padding(28)
        }
        .ignoresSafeArea()
    }
}

enum AppAuthenticator {
    /// Authenticates with biometrics, falling back to the device passcode.
    ///
    /// This used to evaluate `.deviceOwnerAuthenticationWithBiometrics` only. Five
    /// failed Face ID attempts lock biometrics out at the system level, so a user
    /// with Face ID but no app PIN was then shut out of their own health data with
    /// no way back in. `.deviceOwnerAuthentication` tries biometrics first and
    /// offers the device passcode when they fail or are unavailable: the same
    /// guarantee, with a recovery path.
    static func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Cancel")

        let policy: LAPolicy = .deviceOwnerAuthentication
        guard unsafe context.canEvaluatePolicy(policy, error: nil) else {
            throw AppAuthenticationError.unavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { success, error in
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
        // Covers the passcode fallback too, so no longer names Face ID alone.
        String(localized: "This device has no Face ID, Touch ID, or passcode set up.")
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
        UserDefaults.standard.removeObject(forKey: DefaultsKey.legacyAppPINHash)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.legacyAppPINSalt)
    }

    static func verifyPINFromKeychain(_ pin: String) -> Bool {
        guard !pin.isEmpty else { return false }

        // Try Keychain PBKDF2 hash first (v2)
        if let storedHash = keychainRead(account: keychainHashAccount),
           let storedSalt = keychainRead(account: keychainSaltAccount) {
            let inputHash = pbkdf2Hash(pin: pin, salt: storedSalt)
            if constantTimeEquals(inputHash, storedHash) {
                return true
            }
        }

        // Fall back to legacy SHA256 UserDefaults credentials and migrate on success
        let legacyHash = UserDefaults.standard.string(forKey: DefaultsKey.legacyAppPINHash) ?? ""
        let legacySalt = UserDefaults.standard.string(forKey: DefaultsKey.legacyAppPINSalt) ?? ""
        if !legacyHash.isEmpty, sha256Hash(pin: pin, salt: legacySalt) == legacyHash {
            savePINToKeychain(pin: pin)
            return true
        }

        return false
    }

    static func hasPINCredentials() -> Bool {
        keychainRead(account: keychainHashAccount) != nil ||
        !(UserDefaults.standard.string(forKey: DefaultsKey.legacyAppPINHash) ?? "").isEmpty
    }

    static func isValidPIN(_ pin: String) -> Bool {
        pin.count >= 4 && pin.count <= 8 && pin.allSatisfy(\.isNumber)
    }

    static func clearPIN() {
        UserDefaults.standard.removeObject(forKey: DefaultsKey.requiresPIN)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.legacyAppPINHash)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.legacyAppPINSalt)
        keychainDelete(account: keychainHashAccount)
        keychainDelete(account: keychainSaltAccount)
    }

    static func applyFileProtection() {
        Task(priority: .utility) {
            await FileProtectionScheduler.shared.schedule()
        }
    }

    // PBKDF2 with 200,000 iterations, brute-force resistant
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

    /// Walks the app's data directories and marks everything complete-protected.
    ///
    /// The previous version enumerated Application Support, Documents, Caches,
    /// Library *and* tmp. Caches and tmp both live inside Library, so their contents
    /// were visited twice, once via Library's recursive walk and once via their
    /// own, doubling an already file-system-heavy pass that grows with the store
    /// and runs on every launch and foreground.
    ///
    /// Enumerating Library alone covers Application Support and Caches. Documents
    /// and tmp sit outside it and are still walked. Roots are pruned so no
    /// directory nested inside another root is enumerated twice.
    fileprivate static func applyFileProtectionNow() {
        let fileManager = FileManager.default
        let directories: [FileManager.SearchPathDirectory] = [
            .libraryDirectory,
            .documentDirectory
        ]

        var roots: [URL] = []
        for directory in directories {
            guard let root = try? fileManager.url(
                for: directory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ) else {
                continue
            }
            roots.append(root.resolvingSymlinksInPath())
        }
        roots.append(fileManager.temporaryDirectory.resolvingSymlinksInPath())

        // Drop any root contained in another, so nothing is enumerated twice.
        let deduped = roots.filter { candidate in
            !roots.contains { other in
                other != candidate && candidate.path.hasPrefix(other.path + "/")
            }
        }

        for root in deduped {
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

    /// Compares two digests without an early exit.
    ///
    /// `Data`'s `==` is free to return as soon as it finds a differing byte, so how
    /// long a rejection takes leaks how much of the digest matched. The window is
    /// small next to a 200,000-iteration PBKDF2, but the fix is three lines.
    private static func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (left, right) in zip(lhs, rhs) {
            difference |= left ^ right
        }
        return difference == 0
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
