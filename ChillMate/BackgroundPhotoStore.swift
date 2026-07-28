import Foundation
import OSLog
import UIKit

/// File-backed storage for the custom dashboard background photo.
///
/// The photo used to live in UserDefaults as a base64 `String`, read through
/// `@AppStorage("appBackgroundPhotoData")`. UserDefaults is a preferences plist:
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

    /// Cheap identity for the stored photo: changes whenever the photo changes,
    /// costs nothing to read, and holds no image bytes.
    static var fingerprint: String {
        UserDefaults.standard.string(forKey: DefaultsKey.appBackgroundPhotoFingerprint) ?? ""
    }

    static var hasPhoto: Bool { !fingerprint.isEmpty }

    /// Writes the image and returns its new fingerprint.
    @discardableResult
    static func save(_ data: Data) -> String {
        guard let fileURL else { return "" }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
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
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    static func delete() {
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        UserDefaults.standard.removeObject(forKey: DefaultsKey.appBackgroundPhotoFingerprint)
    }

    /// Moves an existing base64 photo out of UserDefaults into the file store.
    ///
    /// Idempotent and safe to call on every launch: it does nothing once the legacy
    /// key is gone.
    static func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        guard let legacy = defaults.string(forKey: DefaultsKey.appBackgroundPhotoData),
              !legacy.isEmpty else { return }

        if let data = Data(base64Encoded: legacy) {
            save(data)
        }
        defaults.removeObject(forKey: DefaultsKey.appBackgroundPhotoData)
        Logger.data.info("Migrated dashboard background photo out of UserDefaults")
    }
}

/// Bounded in-memory cache for decoded background images.
///
/// Replaces a plain `[String: UIImage]` dictionary that evicted `images.keys.first`
/// — an arbitrary key, since Swift dictionaries have no meaningful ordering, so it
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
