import SwiftUI
import SwiftData
import ChillMateCore

extension JournalEntry {
    /// Everything the person wrote on this day, as one string.
    ///
    /// The five prompts are searched together rather than one at a time: nobody
    /// remembers which box they typed a thing into, only that they wrote it.
    var searchableText: String {
        [rememberClearly, feelsGoodAbout, consentConcerns, uncomfortableMoments, regrets]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// The first thing written on this day, for a result row.
    var searchSnippet: String {
        searchableText
            .replacingOccurrences(of: "\n", with: " · ")
    }
}

/// Finding an entry by what was written in it.
///
/// The journal is a day at a time by design — you pick a date and write — which
/// works while the history is short and stops working after a year. Nothing in
/// the app could answer "when was the night I wrote about feeling watched", and
/// that is the question people actually have about their own journal.
///
/// Matching is on lemmas, so "felt anxious" finds "feeling anxious". Everything
/// happens on device in `JournalLanguage`; nothing about the text leaves it, and
/// nothing here interprets what was written.
struct JournalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(ChillMateQueries.recentJournalEntries) private var entries: [JournalEntry]

    /// Set to the day a result belongs to, so the journal can jump there.
    @Binding var selectedDate: Date

    @State private var query = ""

    private var written: [JournalEntry] {
        entries.filter { !$0.searchableText.isEmpty }
    }

    private var results: [JournalEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let documents = written.map {
            JournalLanguage.Document(id: $0.id.uuidString, text: $0.searchableText)
        }
        let ranked = JournalLanguage.search(documents, query: trimmed)

        // Ordering comes from the ranking, so the rows are rebuilt in that order
        // rather than filtered in store order.
        let byID = Dictionary(uniqueKeysWithValues: written.map { ($0.id.uuidString, $0) })
        return ranked.compactMap { byID[$0.id] }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                Group {
                    if written.isEmpty {
                        JournalSearchMessage(
                            symbol: "book.closed",
                            text: String(localized: "Nothing written yet. Entries you write will be searchable here.")
                        )
                    } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        JournalSearchMessage(
                            symbol: "magnifyingglass",
                            text: String(localized: "Search for a word or a phrase you remember writing.")
                        )
                    } else if results.isEmpty {
                        JournalSearchMessage(
                            symbol: "questionmark.circle",
                            text: String(localized: "No entries match that.")
                        )
                    } else {
                        List(results) { entry in
                            Button {
                                selectedDate = entry.date
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.chillText)
                                    Text(entry.searchSnippet)
                                        .font(.caption)
                                        .foregroundStyle(Color.chillSecondary)
                                        .lineLimit(3)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(ChillPlainButtonStyle())
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(Text("Search your journal"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: Text("What do you remember writing?"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

/// One centred line, for the three states that are not a list of results.
private struct JournalSearchMessage: View {
    let symbol: String
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(Color.chillSecondary.opacity(0.6))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.chillSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
