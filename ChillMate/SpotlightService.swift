import CoreSpotlight
import Foundation

@MainActor
final class SpotlightService {
    static let shared = SpotlightService()
    private let domainIdentifier = "com.codex.ChillMate.journal"

    private init() {}

    func indexJournalEntry(_ entry: JournalEntry) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = "Journal — \(entry.date.formatted(date: .abbreviated, time: .shortened))"

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
