import Foundation

/// One thing to tell people about an update, in the words they would use.
///
/// Not a changelog line. The release notes on the App Store and the site's
/// changelog say what changed; this says what it means for the person holding
/// the phone, in a sentence or two, with nothing they would have to look up.
struct WhatsNewItem: Identifiable, Equatable {
    /// Stable across languages, so nothing keys on translated text.
    let id: String
    let symbol: String
    let title: String
    let detail: String
}

/// What a release brings, shown once after updating to it.
struct WhatsNewRelease: Identifiable, Equatable {
    let version: String
    let items: [WhatsNewItem]

    var id: String { version }
}

/// The page shown once after an update, and when to show it.
///
/// Every release gets an entry here, written for people rather than as a
/// changelog; `WhatsNewTests` fails while the app's version has none. A release
/// with nothing to say still needs the entry, so skipping it is a decision
/// rather than an oversight.
enum WhatsNew {

    /// The entry for a version, if it has one.
    static func release(for version: String) -> WhatsNewRelease? {
        releases.first { $0.version == version }
    }

    /// Whether to show the page for `currentVersion`.
    ///
    /// Only for somebody who used an earlier version: a new install marks its
    /// first version as seen when setup finishes, because a page of news about
    /// changes to an app somebody has never used is noise. Nobody sees it twice,
    /// and a version without an entry shows nothing.
    ///
    /// - Parameters:
    ///   - lastSeenVersion: the version whose page was last shown or skipped;
    ///     nil for somebody who updated from a build before this page existed.
    static func shouldShow(currentVersion: String, lastSeenVersion: String?) -> Bool {
        guard release(for: currentVersion) != nil else { return false }
        guard let lastSeenVersion else { return true }
        return lastSeenVersion.compare(currentVersion, options: .numeric) == .orderedAscending
    }

    /// The version this build is, as the App Store shows it.
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    // MARK: - Releases

    static var releases: [WhatsNewRelease] {
        [release510]
    }

    private static var release510: WhatsNewRelease {
        WhatsNewRelease(version: "5.1.0", items: [
            WhatsNewItem(
                id: "icloud-choice",
                symbol: "icloud.fill",
                title: String(localized: "Your iCloud, your choice"),
                detail: String(localized: "ChillMate now asks before it keeps a copy of your data in your iCloud. You can change your mind any time in Settings.")
            ),
            WhatsNewItem(
                id: "less-to-health",
                symbol: "heart.text.square.fill",
                title: String(localized: "Less goes to Apple Health"),
                detail: String(localized: "Only when a night happened and how long you slept are saved to Apple Health. Nothing else about your night.")
            ),
            WhatsNewItem(
                id: "privacy-one-place",
                symbol: "lock.shield.fill",
                title: String(localized: "Privacy in one place"),
                detail: String(localized: "One screen shows what protects your data and where it goes. A running timer can now just say “Timer” on your Lock Screen.")
            ),
            WhatsNewItem(
                id: "sleep-filled-in",
                symbol: "bed.double.fill",
                title: String(localized: "Your sleep, filled in"),
                detail: String(localized: "After you wake up, ChillMate adds how long you slept from Apple Health. It never changes a number you typed.")
            ),
            WhatsNewItem(
                id: "journal-search",
                symbol: "magnifyingglass",
                title: String(localized: "Search your journal"),
                detail: String(localized: "Find what you wrote by what you meant, not only the exact words.")
            ),
            WhatsNewItem(
                id: "better-watch",
                symbol: "applewatch",
                title: String(localized: "A better Apple Watch app"),
                detail: String(localized: "Your watch shows your heart rate from its own sensor, keeps what you tap when your phone is out of reach, and updates its face by itself.")
            ),
        ])
    }
}
