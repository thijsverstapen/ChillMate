import SwiftData
import SwiftUI
import ChillMateCore

/// The month calendar and everything you reach from a day in it.
///
/// Split out of `DashboardView.swift`, which had grown to hold four separate
/// screens. This is a move: the ranges are verbatim, and the only edit anywhere
/// is that five components shared with the dashboard are no longer `private`.

private struct CalendarOverviewButton: View {
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.chillPrimary)
                    .frame(width: 44, height: 44)
                    .glassSurface(radius: 22, tint: Color.chillPrimary.opacity(0.14))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Calendar")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)

                    Text("View logged and skipped Chills month by month")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondary)
            }
            .padding(16)
            .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.09), interactive: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Calendar"))
        .accessibilityHint(String(localized: "View logged and skipped Chills month by month"))
        .accessibilityAddTraits(.isButton)
        .buttonStyle(ChillPlainButtonStyle())
    }
}

private struct CalendarMonthData {
    let monthDays: [Date]
    let leadingBlankCount: Int
    let monthEntries: [NightEntry]
    let monthTimers: [DrugDoseTimerRecord]
    let entriesByDay: [Date: [NightEntry]]
    let journalEntriesByDay: [Date: [JournalEntry]]
    let daySummaries: [Date: CalendarDaySummary]
    let monthlySubstanceCounts: [(name: String, count: Int)]

    init(displayedMonth: Date, entries: [NightEntry], journalEntries: [JournalEntry], timers: [DrugDoseTimerRecord], calendar: Calendar) {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart

        if let range = calendar.range(of: .day, in: .month, for: monthStart) {
            monthDays = range.compactMap { day in
                calendar.date(byAdding: .day, value: day - 1, to: monthStart)
            }
        } else {
            monthDays = []
        }

        if let firstDay = monthDays.first {
            let weekday = calendar.component(.weekday, from: firstDay)
            // Was `(weekday + 5) % 7`, which hardcodes Monday as the first day of
            // the week. That is right for the Netherlands, Germany and France and
            // wrong wherever the calendar starts on Sunday or Saturday — the whole
            // month would be shifted by a day against its own column headers.
            leadingBlankCount = (weekday - calendar.firstWeekday + 7) % 7
        } else {
            leadingBlankCount = 0
        }

        monthEntries = entries.filter { entry in
            entry.date >= monthStart && entry.date < nextMonth
        }
        monthTimers = timers.filter { timer in
            timer.startedAt >= monthStart && timer.startedAt < nextMonth
        }
        let groupedEntries = Dictionary(grouping: monthEntries) { entry in
            calendar.startOfDay(for: entry.date)
        }
        entriesByDay = groupedEntries

        let monthJournalEntries = journalEntries.filter { entry in
            entry.date >= monthStart && entry.date < nextMonth
        }
        let groupedJournals = Dictionary(grouping: monthJournalEntries) { entry in
            calendar.startOfDay(for: entry.date)
        }
        journalEntriesByDay = groupedJournals

        var summaries: [Date: CalendarDaySummary] = [:]
        for day in monthDays {
            let key = calendar.startOfDay(for: day)
            summaries[key] = CalendarDaySummary(
                entries: groupedEntries[key] ?? [],
                journalCount: groupedJournals[key]?.count ?? 0
            )
        }
        daySummaries = summaries

        var substanceCounts: [String: Int] = [:]
        for entry in monthEntries {
            for substance in entry.substances {
                substanceCounts[substance, default: 0] += 1
            }
        }
        monthlySubstanceCounts = substanceCounts
            .map { (name: $0.key, count: $0.value) }
            .sorted { first, second in
                first.count == second.count ? first.name < second.name : first.count > second.count
            }
    }
}

private struct CalendarDaySummary {
    let trackedCount: Int
    let hasSkipped: Bool
    let hasSubstances: Bool
    let hasJournal: Bool

    static let empty = CalendarDaySummary(entries: [], journalCount: 0)

    init(entries: [NightEntry], journalCount: Int) {
        var trackedCount = 0
        var hasSkipped = false
        var hasSubstances = false

        for entry in entries {
            if entry.isTrackedEvent {
                trackedCount += 1
            }
            if entry.skippedNight {
                hasSkipped = true
            }
            if !entry.substances.isEmpty {
                hasSubstances = true
            }
        }

        self.trackedCount = trackedCount
        self.hasSkipped = hasSkipped
        self.hasSubstances = hasSubstances
        self.hasJournal = journalCount > 0
    }
}

struct CalendarOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(ChillMateQueries.recentEntries) private var entries: [NightEntry]
    @Query(ChillMateQueries.recentJournalEntries) private var journalEntries: [JournalEntry]
    @Query(ChillMateQueries.recentTimers) private var timers: [DrugDoseTimerRecord]
    @Query(ChillMateQueries.recentRiskChecks) private var riskChecks: [RiskCheckRecord]
    @State private var displayedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The month as a list rather than a grid, for the accessibility text sizes.
    ///
    /// A seven-column grid cannot be made to work at those sizes. A two-digit day
    /// at AX5 needs more width than a seventh of the screen, widening is not
    /// available, and dropping columns stops it being a calendar. Capping the
    /// growth was the first thing tried and it is precisely wrong: Apple's audit
    /// resizes the app and checks that text grows, so a cap is reported as
    /// "Dynamic Type font sizes are partially unsupported" — it turned 24 findings
    /// into 38 by dragging the weekday headers in with it.
    ///
    /// So the grid gives way to a list, which is what the reader needed at that
    /// size anyway: the days that actually hold something, each on its own line,
    /// with room for the date to be written out properly. The grid's job here is
    /// picking a day, and a list picks a day perfectly well.
    @ViewBuilder
    private func accessibleMonthList(_ data: CalendarMonthData) -> some View {
        let logged = data.monthDays.filter { day in
            let summary = data.daySummaries[calendar.startOfDay(for: day)] ?? .empty
            return summary.trackedCount > 0 || summary.hasSkipped
                || summary.hasSubstances || summary.hasJournal
        }

        if logged.isEmpty {
            EmptyGlassState(text: String(localized: "Nothing logged this month."))
        } else {
            VStack(spacing: 8) {
                ForEach(logged, id: \.self) { day in
                    let summary = data.daySummaries[calendar.startOfDay(for: day)] ?? .empty
                    Button {
                        selectedDay = day
                    } label: {
                        CalendarDayRow(
                            day: day,
                            summary: summary,
                            isSelected: calendar.isDate(day, inSameDayAs: selectedDay)
                        )
                    }
                    .buttonStyle(ChillPlainButtonStyle())
                }
            }
        }
    }

    /// The weekday headers, in the order this calendar actually starts the week.
    ///
    /// `shortWeekdaySymbols` is always Sunday-first, so it is rotated by
    /// `firstWeekday`, which is 1-based.
    private var localizedWeekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.shortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }
    private let calendar = Calendar.current
    let showsBackButton: Bool

    init(showsBackButton: Bool = true) {
        self.showsBackButton = showsBackButton
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var monthData: CalendarMonthData {
        CalendarMonthData(
            displayedMonth: displayedMonth,
            entries: entries,
            journalEntries: journalEntries,
            timers: timers,
            calendar: calendar
        )
    }

    var body: some View {
        if showsBackButton {
            // Presented as a modal cover (e.g. from the dashboard): keep an owned
            // NavigationStack so the back chevron has a toolbar to live in. The
            // cover never pushes, so the edge swipe acts as a dismiss, not a pop.
            NavigationStack {
                calendarContent
                    .navigationTitle(Text(verbatim: ""))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            BackChevronButton {
                                dismiss()
                            }
                        }
                    }
                    .edgeSwipeToDismiss()
            }
        } else {
            // Used as a tab root: render WITHOUT a NavigationStack so there is no
            // interactive pop gesture that can slide the screen to a blank state.
            calendarContent
        }
    }

    @ViewBuilder
    private var calendarContent: some View {
        let data = monthData
        let selectedKey = calendar.startOfDay(for: selectedDay)
        let selectedEntries = data.entriesByDay[selectedKey] ?? []
        let selectedJournalEntries = data.journalEntriesByDay[selectedKey] ?? []
        // Linked by id where the night was already logged when the check was run,
        // and by date where it was not — a check made on the way out, before
        // anything is written down, still belongs to that night.
        let selectedEntryIDs = Set(selectedEntries.map(\.id))
        let selectedRiskChecks = riskChecks.filter { check in
            if let linked = check.nightEntryID { return selectedEntryIDs.contains(linked) }
            return calendar.isDate(check.createdAt, inSameDayAs: selectedDay)
        }

        ZStack {
            DashboardBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(
                        title: String(localized: "Calendar"),
                        subtitle: String(localized: "Tap a day to see logs, skipped Chills, substances, and notes in one place."),
                        symbol: "calendar",
                        tint: Color.chillPrimary
                    )
                    .disablesRootSwipeBack()

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Button {
                                changeMonth(by: -1)
                            } label: {
                                Image(systemName: "chevron.left")
                                    .frame(width: 38, height: 38)
                            }
                            .buttonStyle(.bordered)
                            .tint(Color.chillPrimary)
                            .accessibilityLabel(String(localized: "Previous month"))

                            Spacer()

                            Text(monthTitle)
                                .font(.title3.bold())
                                .foregroundStyle(Color.chillText)

                            Spacer()

                            Button {
                                changeMonth(by: 1)
                            } label: {
                                Image(systemName: "chevron.right")
                                    .frame(width: 38, height: 38)
                            }
                            .buttonStyle(.bordered)
                            .tint(Color.chillPrimary)
                            .accessibilityLabel(String(localized: "Next month"))
                        }

                        if dynamicTypeSize.isAccessibilitySize {
                            accessibleMonthList(data)
                        } else {
                            LazyVGrid(columns: columns, spacing: 8) {
                                // These were the English literals "Mon" ... "Sun",
                                // which reached every non-English user untranslated
                                // and in an order the locale may not use. The
                                // calendar already knows both, so ask it.
                                ForEach(Array(localizedWeekdaySymbols.enumerated()), id: \.offset) { _, label in
                                    Text(label)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.chillSecondary)
                                        .frame(maxWidth: .infinity)
                                        .accessibilityHidden(true)
                                }

                                ForEach(0..<data.leadingBlankCount, id: \.self) { _ in
                                    Color.clear
                                        .frame(height: 48)
                                }

                                ForEach(data.monthDays, id: \.self) { day in
                                    let dayKey = calendar.startOfDay(for: day)
                                    CalendarDayCell(
                                        day: day,
                                        summary: data.daySummaries[dayKey] ?? .empty,
                                        isSelected: calendar.isDate(day, inSameDayAs: selectedDay)
                                    ) {
                                        selectedDay = day
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(
                            title: selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                            symbol: "calendar.badge.clock"
                        )

                        if selectedEntries.isEmpty {
                            EmptyGlassState(text: String(localized: "No entries for this day."))
                        } else {
                            ForEach(selectedEntries) { entry in
                                TimelineRow(entry: entry, delete: delete)
                            }
                        }

                        if !selectedJournalEntries.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionTitle(title: String(localized: "Journal"), symbol: "book.closed.fill")

                                ForEach(selectedJournalEntries) { entry in
                                    CalendarJournalCard(entry: entry)
                                }
                            }
                        }

                        // A risk check used to be findable only in a flat list on
                        // the risk checker screen, which is the one place you are
                        // not looking when you want to remember what you checked
                        // before a particular night.
                        if !selectedRiskChecks.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionTitle(title: String(localized: "Risk checks"), symbol: "exclamationmark.shield.fill")

                                ForEach(selectedRiskChecks) { check in
                                    CalendarRiskCheckCard(record: check)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "Substance tags in \(monthTitle)", symbol: "pills.fill")

                        if data.monthlySubstanceCounts.isEmpty {
                            EmptyGlassState(text: String(localized: "No substance tags in this month."))
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(data.monthlySubstanceCounts.prefix(8), id: \.name) { item in
                                    SubstanceBar(name: item.name, count: item.count, maxCount: data.monthlySubstanceCounts.first?.count ?? 1)
                                }
                            }
                            .padding(16)
                            .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08))
                        }
                    }

                    DrugDoseHistoryGraph(timers: data.monthTimers, entries: data.monthEntries, monthDays: data.monthDays)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: String(localized: "Month timeline"), symbol: "list.bullet.rectangle")

                        if data.monthEntries.isEmpty {
                            EmptyGlassState(text: String(localized: "No entries in this month."))
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(data.monthEntries) { entry in
                                    TimelineRow(entry: entry, delete: delete)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func changeMonth(by value: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
        selectedDay = displayedMonth
    }

    private func delete(_ entry: NightEntry) {
        RecentlyDeletedStore.record(
            kind: "Chill log",
            title: entry.skippedNight ? "Skipped Chill check" : "Chill log",
            detail: entry.date.formatted(date: .abbreviated, time: .shortened)
        )
        modelContext.delete(entry)
        modelContext.saveChanges()
    }
}

private struct CalendarDayCell: View {
    let day: Date
    let summary: CalendarDaySummary
    let isSelected: Bool
    let select: () -> Void

    /// The activity dots and the row that holds them were fixed at 6 and 8 points,
    /// so the day number grew with Dynamic Type and its indicators did not — which
    /// is what the audit means by "font sizes are partially unsupported". Scaling
    /// them keeps the cell proportional instead of leaving specks under large text.
    @ScaledMetric(relativeTo: .caption) private var dotSize: CGFloat = 6
    @ScaledMetric(relativeTo: .caption) private var dotRowHeight: CGFloat = 8

    private var calendar: Calendar { .current }

    private var tint: Color {
        if summary.trackedCount > 0 {
            return Color.chillAccentTeal
        }
        if summary.hasSkipped {
            return .indigo
        }
        if summary.hasJournal {
            return Color.chillSecondaryBlue
        }
        return .clear
    }

    var body: some View {
        Button(action: select) {
            VStack(spacing: 5) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? .white : Color.chillText)

                HStack(spacing: 3) {
                    if summary.trackedCount > 0 {
                        Circle()
                            .fill(isSelected ? .white : Color.chillAccentTeal)
                            .frame(width: dotSize, height: dotSize)
                    }

                    if summary.hasSkipped {
                        Circle()
                            .fill(isSelected ? .white.opacity(0.72) : .indigo)
                            .frame(width: dotSize, height: dotSize)
                    }

                    if summary.hasSubstances {
                        Circle()
                            .fill(isSelected ? .white.opacity(0.54) : Color.chillSecondaryBlue)
                            .frame(width: dotSize, height: dotSize)
                    }

                    if summary.hasJournal {
                        Circle()
                            .fill(isSelected ? .white.opacity(0.42) : Color.chillSecondaryBlue)
                            .frame(width: dotSize, height: dotSize)
                    }
                }
                .frame(height: dotRowHeight)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                isSelected ? Color.chillPrimary : tint.opacity(summary.trackedCount == 0 && !summary.hasSkipped && !summary.hasSubstances && !summary.hasJournal ? 0.04 : 0.12),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(ChillPlainButtonStyle())
        // Without this a cell read out as a bare number — "28", with no month, no
        // year, and nothing at all about the coloured dots, which are the only
        // thing that distinguishes one day from another here. The whole point of
        // the grid is invisible to VoiceOver until the dots are put into words.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityLabel: Text {
        var parts = [day.formatted(.dateTime.weekday(.wide).day().month(.wide))]

        if summary.trackedCount > 0 {
            parts.append(String(localized: "\(summary.trackedCount) logged"))
        }
        if summary.hasSkipped {
            parts.append(String(localized: "skipped night"))
        }
        if summary.hasSubstances {
            parts.append(String(localized: "substances logged"))
        }
        if summary.hasJournal {
            parts.append(String(localized: "journal entry"))
        }
        if parts.count == 1 {
            parts.append(String(localized: "nothing logged"))
        }

        return Text(parts.joined(separator: ", "))
    }
}

/// One day of the month, written out, for the accessibility text sizes.
///
/// The grid cell it replaces had to fit a number into a seventh of the screen.
/// This has the whole width, so the date can be spelled out and the dots can be
/// words — which is what they always were to VoiceOver, and there is no reason
/// they should not be words on screen too at a size someone chose because
/// reading is hard.
private struct CalendarDayRow: View {
    let day: Date
    let summary: CalendarDaySummary
    let isSelected: Bool

    private var marks: [String] {
        var parts: [String] = []
        if summary.trackedCount > 0 { parts.append(String(localized: "\(summary.trackedCount) logged")) }
        if summary.hasSkipped { parts.append(String(localized: "skipped night")) }
        if summary.hasSubstances { parts.append(String(localized: "substances logged")) }
        if summary.hasJournal { parts.append(String(localized: "journal entry")) }
        return parts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.headline)
                .foregroundStyle(isSelected ? .white : Color.chillText)
                .fixedSize(horizontal: false, vertical: true)

            if !marks.isEmpty {
                Text(marks.joined(separator: ", "))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            isSelected ? Color.chillPrimary : Color.chillAccentTeal.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct CalendarJournalCard: View {
    let entry: JournalEntry

    private var lines: [(String, String)] {
        [
            ("Clear memory", entry.rememberClearly),
            ("Uncomfortable", entry.uncomfortableMoments),
            ("Consent", entry.consentConcerns),
            ("Regrets", entry.regrets),
            ("Good", entry.feelsGoodAbout)
        ].filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.chillSecondaryBlue)
                    .frame(width: 34, height: 34)
                    .glassSurface(radius: 17, tint: Color.chillSecondaryBlue.opacity(0.12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                    Text(entry.photos.isEmpty ? String(localized: "Journal entry") : String(localized: "\(entry.photos.count) picture\(entry.photos.count == 1 ? "" : "s") attached"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                }

                Spacer(minLength: 0)
            }

            ForEach(lines.prefix(3), id: \.0) { line in
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.0)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.chillSecondary)
                    Text(line.1)
                        .font(.caption)
                        .foregroundStyle(Color.chillText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: 22, tint: Color.chillSecondaryBlue.opacity(0.07))
    }
}

/// A saved risk check, shown on the night it was run for.
///
/// Deliberately a summary rather than the full record: the substances, the time,
/// and how many warnings came back. Tapping through to the risk checker is where
/// the detail lives, and reproducing it here would mean two places to keep the
/// same safety text correct.
private struct CalendarRiskCheckCard: View {
    let record: RiskCheckRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(record.substanceNames.isEmpty
                     ? String(localized: "Medication only")
                     : record.substanceNames.joined(separator: ", "))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.chillText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text(record.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
            }

            if record.warnings.isEmpty {
                Text("No warnings were returned. That is not the same as safe.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("\(record.warnings.count) warnings")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassSurface(radius: 18, tint: .orange.opacity(0.08))
        .accessibilityElement(children: .combine)
    }
}
