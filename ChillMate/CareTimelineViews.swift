import Foundation
import SwiftData
import SwiftUI
import ChillMateCore

struct UnifiedTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(ChillMateQueries.recentEntries) private var entries: [NightEntry]
    @Query(ChillMateQueries.recentJournalEntries) private var journalEntries: [JournalEntry]
    @Query(ChillMateQueries.recentTimers) private var timers: [DrugDoseTimerRecord]
    @Query(ChillMateQueries.recentPlansByDate) private var plans: [SaferSessionPlan]
    @Query(ChillMateQueries.recentTests) private var tests: [STDTestRecord]

    /// Every string here is one a person reads on the Full timeline. Built as
    /// plain `String`s, they were English in every language, and the timers'
    /// titles named the substance by its English raw value.
    private var events: [UnifiedTimelineEvent] {
        var result: [UnifiedTimelineEvent] = []
        result += entries.map {
            UnifiedTimelineEvent(
                date: $0.date,
                title: $0.skippedNight ? String(localized: "Skipped Chill check") : String(localized: "Chill log"),
                detail: $0.skippedNight ? String(localized: "Marked as skipped") : Self.entryDetail($0),
                symbol: $0.skippedNight ? "moon.zzz.fill" : "heart.text.square.fill",
                tint: $0.skippedNight ? Color.chillIconPurple : Color.chillIconPink
            )
        }
        result += journalEntries.map {
            UnifiedTimelineEvent(date: $0.date, title: String(localized: "Journal"), detail: $0.rememberClearly.isEmpty ? String(localized: "Saved reflection") : $0.rememberClearly, symbol: "book.closed.fill", tint: Color.chillIconPurple)
        }
        result += timers.map {
            let route = AdministrationRoute(rawValue: $0.administrationRoute)?.displayName ?? String(localized: "Saved route")
            let hours = $0.durationHours.formatted(.number.precision(.fractionLength(0...1)))
            return UnifiedTimelineEvent(date: $0.startedAt, title: String(localized: "\($0.localizedSubstanceName) check-in"), detail: String(localized: "\(route), \(hours) h reminder"), symbol: "timer", tint: Color.chillIconAmber)
        }
        result += plans.map {
            UnifiedTimelineEvent(date: $0.plannedDate, title: String(localized: "Before-Chill plan"), detail: $0.transportPlan.isEmpty ? String(localized: "Ends \($0.endingDate.formatted(date: .omitted, time: .shortened))") : $0.transportPlan, symbol: "checkmark.shield.fill", tint: Color.chillMint)
        }
        result += tests.map {
            UnifiedTimelineEvent(date: $0.testDate, title: String(localized: "STI test"), detail: $0.hasPositiveResult ? String(localized: "Positive result saved") : String(localized: "Results \($0.resultsDueDate.formatted(date: .abbreviated, time: .omitted))"), symbol: "cross.case.fill", tint: Color.chillIconTeal)
        }
        return result.sorted { $0.date > $1.date }
    }

    private static func entryDetail(_ entry: NightEntry) -> String {
        let substances = entry.substances.isEmpty
            ? String(localized: "no substances")
            : entry.substances.map { Substance(rawValue: $0)?.localizedDisplayName ?? $0 }.joined(separator: ", ")
        return "\(entry.partnerSummary), \(substances)"
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(title: String(localized: "Full timeline"), subtitle: String(localized: "One private timeline with logs, journal notes, plans, timers, and STI tests."), symbol: "timeline.selection", tint: Color.chillSecondaryBlue)
                        if events.isEmpty {
                            Text("Nothing has been saved yet.")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Color.chillSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .glassSurface(radius: 24, tint: .black.opacity(0.04))
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(Array(events.prefix(80))) { event in
                                    UnifiedTimelineEventRow(event: event)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

private struct UnifiedTimelineEvent: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
}

private struct UnifiedTimelineEventRow: View {
    let event: UnifiedTimelineEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(event.tint)
                .frame(width: 36, height: 36)
                .glassSurface(radius: 18, tint: event.tint.opacity(0.12))
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(.headline).foregroundStyle(Color.chillText)
                Text(event.detail).font(.caption.weight(.semibold)).foregroundStyle(Color.chillSecondary).lineLimit(2)
                Text(event.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2.weight(.bold)).foregroundStyle(Color.chillTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassSurface(radius: 22, tint: event.tint.opacity(0.08))
    }
}

