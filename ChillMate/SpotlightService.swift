import CoreSpotlight
import Foundation

@MainActor
final class SpotlightService {
    static let shared = SpotlightService()
    private let journalDomainIdentifier = "com.codex.ChillMate.journal"
    private let toolDomainIdentifier = "com.codex.ChillMate.tools"

    /// Identifier used both as the Spotlight uniqueIdentifier and as the routing key
    /// handled in the app scene (see `onContinueUserActivity` in ChillMateApp).
    static let riskCheckerItemID = "tool-combinationRisk"

    private init() {}

    /// Index the always-available tools so they surface in Spotlight search.
    func indexTools() {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = String(localized: "Risk checker")
        attributeSet.contentDescription = String(localized: "Check how substances and medication combine before you mix.")
        attributeSet.keywords = ["risk", "combination", "mix", "interaction", "medication", "safety", "ChillMate"]

        let item = CSSearchableItem(
            uniqueIdentifier: Self.riskCheckerItemID,
            domainIdentifier: toolDomainIdentifier,
            attributeSet: attributeSet
        )
        item.expirationDate = .distantFuture
        CSSearchableIndex.default().indexSearchableItems([item])
    }

    /// Takes every journal entry back out of Spotlight, once per install.
    ///
    /// Until 5.1.0 saving a journal entry put its text — what somebody remembered,
    /// what felt good, what they regretted — into the system search index. Anyone
    /// holding the unlocked phone could read it from the Home Screen's search
    /// without passing ChillMate's Face ID or PIN, in duress mode too, and deleting
    /// all data in the app left it there. Nothing is indexed from the journal now;
    /// the journal's own search, behind the lock, replaces it.
    ///
    /// The flag is set only once Spotlight confirms the removal, so a failure is
    /// retried on the next launch.
    func removeJournalIndexIfNeeded(defaults: UserDefaults = .standard) async {
        guard !defaults.bool(forKey: DefaultsKey.spotlightJournalRemoved) else { return }

        // Each indexed entry also left a key behind, named after the entry.
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.legacyJournalHashPrefix) {
            defaults.removeObject(forKey: key)
        }

        do {
            try await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [journalDomainIdentifier])
            defaults.set(true, forKey: DefaultsKey.spotlightJournalRemoved)
        } catch {
            // Left unset, so the next launch tries again.
        }
    }

    /// Prefix of the per-entry keys the journal indexing wrote. Not a key itself.
    static let legacyJournalHashPrefix = "spotlightHash-"
}

/// Conformance declared here rather than beside the protocol: `SpotlightIndexing`
/// inherits `Sendable`, and Swift treats a Sendable conformance in another
/// file as retroactive — a warning today and an error in a future language
/// mode.
extension SpotlightService: SpotlightIndexing {}
