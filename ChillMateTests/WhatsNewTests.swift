import Foundation
import Testing
import UIKit
@testable import ChillMate

/// The page shown once after an update, and the rule for when.
@Suite("What's New")
struct WhatsNewTests {

    /// Every release says what it brings. A version without an entry would
    /// update silently, so this fails until one is written.
    @Test("The app's own version has a What's New entry")
    func currentVersionHasAnEntry() {
        let version = WhatsNew.currentVersion
        #expect(!version.isEmpty)
        #expect(WhatsNew.release(for: version) != nil, "Write the What's New entry for \(version) in WhatsNew.swift")
    }

    @Test("Somebody updating from an older version sees it")
    func olderVersionSeesIt() {
        #expect(WhatsNew.shouldShow(currentVersion: "5.1.0", lastSeenVersion: "5.0.0"))
    }

    /// Updated from a build before this page existed, so nothing was recorded.
    @Test("Somebody updating from before this page existed sees it")
    func noRecordSeesIt() {
        #expect(WhatsNew.shouldShow(currentVersion: "5.1.0", lastSeenVersion: nil))
    }

    @Test("Nobody sees it twice")
    func seenOnce() {
        #expect(!WhatsNew.shouldShow(currentVersion: "5.1.0", lastSeenVersion: "5.1.0"))
    }

    /// A downgrade, or a new install that recorded a later version, is not news.
    @Test("A later version already seen does not bring it back")
    func laterVersionSeen() {
        #expect(!WhatsNew.shouldShow(currentVersion: "5.1.0", lastSeenVersion: "5.2.0"))
    }

    @Test("A version without an entry shows nothing")
    func noEntryNoPage() {
        #expect(!WhatsNew.shouldShow(currentVersion: "99.0.0", lastSeenVersion: "5.0.0"))
    }

    /// Compared as numbers: as text, "5.10.0" sorts before "5.9.0".
    @Test("Versions are compared as numbers, not as text")
    func numericComparison() {
        #expect("5.9.0".compare("5.10.0", options: .numeric) == .orderedAscending)
    }

    /// Summarised, not a changelog: a handful of items, each with something to
    /// say and a symbol that exists.
    @Test("Each release is short, and every item is complete", arguments: WhatsNew.releases)
    func releasesAreComplete(release: WhatsNewRelease) {
        #expect((1...6).contains(release.items.count), "\(release.version) has \(release.items.count) items")
        #expect(Set(release.items.map(\.id)).count == release.items.count, "\(release.version) repeats an id")
        for item in release.items {
            #expect(!item.title.isEmpty && !item.detail.isEmpty, "\(item.id) is missing text")
            #expect(UIImage(systemName: item.symbol) != nil, "\(item.id) uses a symbol that does not exist: \(item.symbol)")
        }
    }
}
