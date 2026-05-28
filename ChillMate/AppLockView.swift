import CryptoKit
import LocalAuthentication
import SwiftUI

struct AppLockView<Content: View>: View {
    @AppStorage("requiresFaceID") private var requiresFaceID = false
    @AppStorage("requiresPIN") private var requiresPIN = false
    @AppStorage("appPINHash") private var appPINHash = ""
    @AppStorage("appPINSalt") private var appPINSalt = ""
    @AppStorage("localEncryptionEnabled") private var localEncryptionEnabled = true
    @Environment(\.scenePhase) private var scenePhase

    @State private var isUnlocked = false
    @State private var message: String?
    @State private var isAuthenticating = false
    @State private var pinCode = ""

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
                isUnlocked = false
                pinCode = ""
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

        if LocalSecurityService.verifyPIN(pinCode, hash: appPINHash, salt: appPINSalt) {
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
    static func makePINCredentials(pin: String) -> (hash: String, salt: String) {
        let saltBytes = (0..<16).map { _ in UInt8.random(in: UInt8.min...UInt8.max) }
        let salt = Data(saltBytes).base64EncodedString()
        return (hashPIN(pin, salt: salt), salt)
    }

    static func verifyPIN(_ pin: String, hash: String, salt: String) -> Bool {
        guard !pin.isEmpty, !hash.isEmpty, !salt.isEmpty else {
            return false
        }

        return hashPIN(pin, salt: salt) == hash
    }

    static func isValidPIN(_ pin: String) -> Bool {
        pin.count >= 4 && pin.count <= 8 && pin.allSatisfy(\.isNumber)
    }

    static func clearPIN() {
        UserDefaults.standard.removeObject(forKey: "requiresPIN")
        UserDefaults.standard.removeObject(forKey: "appPINHash")
        UserDefaults.standard.removeObject(forKey: "appPINSalt")
    }

    static func applyFileProtection() {
        Task(priority: .utility) {
            await FileProtectionScheduler.shared.schedule()
        }
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
