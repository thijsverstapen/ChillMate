import CoreSpotlight
import Foundation

@MainActor
final class SpotlightService {
    static let shared = SpotlightService()
    private let domainIdentifier = "com.codex.ChillMate.journal"
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

    func indexJournalEntry(_ entry: JournalEntry) {
        let contentHash = (entry.rememberClearly + entry.feelsGoodAbout + entry.regrets).hashValue
        let key = "spotlightHash-\(entry.id.uuidString)"
        guard UserDefaults.standard.integer(forKey: key) != contentHash else { return }
        UserDefaults.standard.set(contentHash, forKey: key)

        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = "Journal: \(entry.date.formatted(date: .abbreviated, time: .shortened))"

        var parts: [String] = []
        if !entry.rememberClearly.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(entry.rememberClearly)
        }
        if !entry.feelsGoodAbout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(entry.feelsGoodAbout)
        }
        if !entry.regrets.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(entry.regrets)
        }
        attributeSet.contentDescription = parts.isEmpty ? "Private journal entry" : parts.joined(separator: " · ")
        attributeSet.keywords = ["journal", "ChillMate", "private", "reflection"]

        let item = CSSearchableItem(
            uniqueIdentifier: "journal-\(entry.id.uuidString)",
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
        item.expirationDate = .distantFuture

        CSSearchableIndex.default().indexSearchableItems([item])
    }

    func removeJournalEntry(_ entry: JournalEntry) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: ["journal-\(entry.id.uuidString)"]
        )
    }

    func removeAllJournalEntries() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier])
    }
}
