import Foundation
import OSLog
import UIKit

/// File-backed storage for the custom dashboard background photo.
///
/// The photo used to live in UserDefaults as a base64 `String`, read through
/// `@AppStorage(DefaultsKey.appBackgroundPhotoData)`. UserDefaults is a preferences plist:
/// it is loaded into memory in full at launch and rewritten synchronously, so a
/// multi-megabyte base64 image sat in memory for the life of the process and cost a
/// full plist rewrite on every change. Worse, `DashboardBackdrop` derived its cache
/// key with `.count` and `.prefix(32)` over that base64 string on *every* body
/// evaluation, and the backdrop sits behind nearly every screen.
///
/// The image now goes to a file with complete file protection, matching how the
/// profile photo already uses `@Attribute(.externalStorage)`. UserDefaults keeps
/// only a short fingerprint, which is what the view actually needs to decide
/// whether to reload.
enum BackgroundPhotoStore {
    private static let fileName = "dashboard-background.jpg"

    private static var fileURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(fileName)
    }

    /// Whether the image file is really on disk.
    ///
    /// Used to confirm a write landed before anything throws away the last other copy
    /// of the image, so a "saved" photo is never taken on trust.
    private static var storedFileExists: Bool {
        guard let fileURL else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Cheap identity for the stored photo: changes whenever the photo changes,
    /// costs nothing to read, and holds no image bytes.
    static var fingerprint: String {
        UserDefaults.standard.string(forKey: DefaultsKey.appBackgroundPhotoFingerprint) ?? ""
    }

    static var hasPhoto: Bool { !fingerprint.isEmpty }

    /// Writes the image and returns its new fingerprint, or an empty string if the
    /// write did not land.
    ///
    /// Deliberately not `@discardableResult`: every failure path here is silent to the
    /// user, so a caller that ignores the result cannot tell a stored photo from a lost
    /// one. Letting the compiler insist on the check is what stops the migration below
    /// from deleting its source on a write that never happened.
    static func save(_ data: Data) -> String {
        guard let fileURL else {
            Logger.data.error("Background photo not written: Application Support is unresolvable")
            return ""
        }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            // Atomic so a failed write leaves any previous photo intact instead of
            // truncating it, and complete protection so the bytes are unreadable while
            // the device is locked, which is the guarantee the rest of the on-device
            // data carries.
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            let stamp = "\(data.count)-\(Date.now.timeIntervalSince1970)"
            UserDefaults.standard.set(stamp, forKey: DefaultsKey.appBackgroundPhotoFingerprint)
            return stamp
        } catch {
            Logger.data.error("Background photo write failed: \(error.localizedDescription, privacy: .public)")
            return ""
        }
    }

    static func load() -> Data? {
        guard storedFileExists, let fileURL else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    /// Erases the stored photo, its fingerprint and its decoded copy.
    ///
    /// The fingerprint goes even if the file removal fails, because removal is what the
    /// user asked for and a surviving fingerprint would keep the backdrop pointing at a
    /// photo they wanted gone. A failed removal is logged rather than swallowed: image
    /// bytes left on disk after "delete" are exactly what this app promises not to keep.
    static func delete() {
        if storedFileExists, let fileURL {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                Logger.data.error("Background photo delete failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        UserDefaults.standard.removeObject(forKey: DefaultsKey.appBackgroundPhotoFingerprint)

        // The decoded copy has to go too. Nothing reads it again once the fingerprint is
        // cleared (the cache key is derived from it), but NSCache would otherwise hold
        // the image in memory until the next memory-pressure eviction. Hops to the main
        // actor because the cache is isolated to it, and `delete()` is also called from
        // the nonisolated "delete all data" path.
        Task { @MainActor in
            ChillBackgroundImageCache.removeAll()
        }
    }

    /// Moves an existing base64 photo out of UserDefaults into the file store.
    ///
    /// Idempotent and safe to call on every launch: it does nothing once the legacy
    /// key is gone, and it retries on the next launch if the move did not complete.
    ///
    /// Until the file write lands, the defaults key holds the only copy of the user's
    /// image, so it is cleared only against a confirmed new copy. The write can fail for
    /// reasons the app cannot control (Application Support unresolvable, a full disk, a
    /// launch that happens before first unlock while complete file protection is in
    /// force); dropping the source on any of those would destroy the image on a failure
    /// the code had already detected.
    static func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        guard let legacy = defaults.string(forKey: DefaultsKey.appBackgroundPhotoData),
              !legacy.isEmpty else { return }

        guard let data = Data(base64Encoded: legacy) else {
            // Not decodable base64, so there is no image in there to preserve and the key
            // is only dead weight in the preferences plist. Dropping it is correct, but it
            // is logged apart from a real migration so the two are not confused in the
            // console: this one means a photo was lost before this code ever ran.
            defaults.removeObject(forKey: DefaultsKey.appBackgroundPhotoData)
            Logger.data.error("Discarded legacy dashboard background photo: stored value was not valid base64")
            return
        }

        guard !save(data).isEmpty, storedFileExists else {
            Logger.data.error("Dashboard background photo migration failed; keeping the legacy copy to retry next launch")
            return
        }

        defaults.removeObject(forKey: DefaultsKey.appBackgroundPhotoData)
        Logger.data.info("Migrated dashboard background photo out of UserDefaults")
    }
}

/// Bounded in-memory cache for decoded background images.
///
/// Replaces a plain `[String: UIImage]` dictionary that evicted `images.keys.first`,
/// an arbitrary key given that Swift dictionaries have no meaningful ordering, so it
/// could evict the entry just inserted. `NSCache` also releases its contents under
/// memory pressure, which a dictionary never does.
@MainActor
enum ChillBackgroundImageCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 4
        return cache
    }()

    static func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    static func store(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    static func removeAll() {
        cache.removeAllObjects()
    }
}
