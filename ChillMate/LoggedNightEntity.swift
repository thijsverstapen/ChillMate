import AppIntents
import Foundation
import SwiftData
import ChillMateCore

/// A logged night, as something Siri and Shortcuts can refer to.
///
/// Every intent in this app was an action: log a thing, open a screen, start a
/// timer. None of them could answer a question *about* what is already logged,
/// because there was no entity for Shortcuts to hand around. "How many nights
/// have I logged this month" had no route into the app at all.
///
/// **Its display representation is the date and nothing else, on purpose.**
/// An entity's title shows up in the Shortcuts gallery, in Spotlight, and in
/// Siri's own UI — places that are visible over a locked screen and to whoever
/// is holding the phone. The app already has discreet wording settings for
/// exactly this reason, and a title reading "Friday — MDMA and alcohol" would
/// walk straight past them. A date is enough to pick a night out of a list, and
/// it is the most that should ever be readable from outside the app.
struct LoggedNightEntity: AppEntity {
    let id: UUID
    let date: Date

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Logged night")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(date.formatted(date: .abbreviated, time: .omitted))")
    }

    // `let`, not `var`: Swift 6 treats a mutable static as shared global state
    // and refuses it. The query holds nothing, so there is nothing to mutate.
    static let defaultQuery = LoggedNightQuery()
}

/// Finds logged nights for Shortcuts.
///
/// Reads through `ChillMateQueries` like everything else, so the bounded
/// descriptor and its row limit apply here too rather than an intent quietly
/// fetching the whole table.
struct LoggedNightQuery: EntityQuery {

    @MainActor
    private func allNights() -> [NightEntry] {
        let context = ChillMateModelContainer.container().mainContext
        return (try? context.fetch(ChillMateQueries.recentEntries)) ?? []
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [LoggedNightEntity] {
        let wanted = Set(identifiers)
        return allNights()
            .filter { wanted.contains($0.id) }
            .map { LoggedNightEntity(id: $0.id, date: $0.date) }
    }

    @MainActor
    func suggestedEntities() async throws -> [LoggedNightEntity] {
        // The most recent handful. A suggestion list is a menu, not an export.
        allNights()
            .prefix(10)
            .map { LoggedNightEntity(id: $0.id, date: $0.date) }
    }
}

/// Answers how many nights are logged in a window, out loud.
///
/// Counts only. It reports how many nights and how many of those were logged
/// without any substance recorded, which are both facts the person entered
/// themselves. It says nothing about what was logged, for the same reason the
/// entity's title does not.
struct CountLoggedNightsIntent: AppIntent {
    static let title: LocalizedStringResource = "Count my logged nights"

    static var description: IntentDescription {
        IntentDescription(
            "Counts how many nights you have logged recently. Says nothing about what was logged.",
            categoryName: "Insights"
        )
    }

    @Parameter(title: "Days to look back", default: 30)
    var days: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ChillMateModelContainer.container().mainContext
        let entries = (try? context.fetch(ChillMateQueries.recentEntries)) ?? []

        let window = max(1, min(days, 365))
        let cutoff = Calendar.current.date(byAdding: .day, value: -window, to: .now) ?? .distantPast
        let recent = entries.filter { $0.date >= cutoff && !$0.skippedNight }
        let clear = recent.filter { !$0.hasSubstances }

        let message = String(
            localized: "\(recent.count) nights logged in the last \(window) days, \(clear.count) of them with nothing recorded."
        )
        return .result(dialog: "\(message)")
    }
}
