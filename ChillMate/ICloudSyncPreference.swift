import Foundation

/// Whether ChillMate keeps a copy of its store in the person's private iCloud.
///
/// Until 5.1.0 this was not a choice. The store was configured with
/// `cloudKitDatabase: .private(...)` unconditionally, so anyone signed into
/// iCloud had every night, substance, partner, journal entry and STI result
/// mirrored to CloudKit from their first launch — while onboarding said "Your
/// profile lives on this device and nowhere else", the privacy screen showed
/// iCloud backup as off, and the public privacy page said sync happened "only if
/// you turn iCloud on". It was the person's own private database and the
/// developer could never read it, but it was opt-out where every word in and
/// about the app described opt-in.
///
/// Now it is opt-in, and each kind of install is handled on its own terms:
///
/// - **A new install** has nothing in iCloud to lose, so it starts off and is
///   never asked. That makes the promise true instead of rewording it.
/// - **An existing install** has been syncing, possibly for months, and is
///   possibly the only thing that would carry its history to a new phone — the
///   encrypted backup cannot, because its key is `ThisDeviceOnly`. Switching it
///   off silently could strand that history; leaving it on silently would carry
///   on doing the undisclosed thing. So it is asked, once, before its store opens.
///
/// The decision is read when the container is built and cannot change a
/// container that is already running, which is why a change in Settings says it
/// applies after ChillMate restarts.
enum ICloudSyncPreference {

    enum Choice: String, CaseIterable, Sendable {
        /// A copy of the store is mirrored to the private CloudKit database.
        case on
        /// Nothing is mirrored. Whatever is already in iCloud stays there until the
        /// person deletes it; turning mirroring off does not remove it, and the UI
        /// says so rather than implying otherwise.
        case off
    }

    // MARK: - Reading and writing

    /// The recorded choice, or nil for an existing install nobody has asked yet.
    static func choice(in defaults: UserDefaults = .standard) -> Choice? {
        defaults.string(forKey: DefaultsKey.iCloudSyncChoice).flatMap(Choice.init(rawValue:))
    }

    static func record(_ choice: Choice, in defaults: UserDefaults = .standard) {
        defaults.set(choice.rawValue, forKey: DefaultsKey.iCloudSyncChoice)
    }

    /// What the running container was actually built with.
    ///
    /// A container cannot change its CloudKit setting once it exists, so a change
    /// made in Settings does nothing until ChillMate restarts. Recording what this
    /// session opened with lets Settings say so only when it is true, rather than
    /// always hedging or never saying it at all.
    @MainActor static var appliedThisSession: Choice?

    // MARK: - The rules

    /// Settles a first launch before anything reads the choice.
    ///
    /// A store already on disk with no choice recorded is an install from before
    /// 5.1.0, and is left undecided so it can be asked. No store is a fresh
    /// install, which is off and decided.
    ///
    /// Pure apart from the defaults it is handed, so the rule can be tested
    /// without touching the filesystem or CloudKit.
    static func resolveAtLaunch(storeExists: Bool, defaults: UserDefaults = .standard) {
        guard choice(in: defaults) == nil else { return }
        if !storeExists {
            record(.off, in: defaults)
        }
    }

    /// Whether the store should mirror to CloudKit right now.
    ///
    /// An undecided install mirrors, because that is what its store has been
    /// doing and the question is asked before the app's own container is built.
    /// The only way to reach this with no answer is something that opens the
    /// store without the app's UI — a Siri intent run before the first launch
    /// after updating — and pausing mirroring for that one call is a riskier
    /// change to an existing store than leaving it as it was.
    static func mirrorsToCloudKit(choice: Choice?) -> Bool {
        switch choice {
        case .on, nil: true
        case .off: false
        }
    }

    /// Whether the store is mirroring right now, for any screen that says so.
    ///
    /// The running session's value first, because a screen describing where data
    /// goes must describe what is happening, not what Settings will do after a
    /// restart. Falls back to the stored choice before any container exists.
    @MainActor
    static func isMirroringNow(storedChoice: String?) -> Bool {
        if let applied = appliedThisSession { return applied == .on }
        return mirrorsToCloudKit(choice: storedChoice.flatMap(Choice.init(rawValue:)))
    }

    /// True when the person has to be asked before the app's store opens.
    static func needsDecision(in defaults: UserDefaults = .standard) -> Bool {
        choice(in: defaults) == nil
    }

    // MARK: - Where the store lives

    /// Whether SwiftData's default store already exists.
    ///
    /// SwiftData puts it at `Application Support/default.store` when the
    /// configuration names no URL, which is how `ChillMateModelContainer` builds
    /// it. Checked by path rather than by opening a container, because opening
    /// one is exactly what must not happen before the answer.
    static var defaultStoreExists: Bool {
        guard let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return false
        }
        return FileManager.default.fileExists(
            atPath: support.appendingPathComponent("default.store").path
        )
    }
}
