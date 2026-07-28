import Foundation
import SwiftData
import SwiftUI

// Private insights views extracted from CareToolsView.swift as part of splitting that file.

struct PrivateInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(ChillMateQueries.recentEntries) private var entries: [NightEntry]
    @Query(ChillMateQueries.recentTimers) private var timers: [DrugDoseTimerRecord]
    @Query(ChillMateQueries.recentJournalEntries) private var journals: [JournalEntry]

    @State private var windowDays = 90

    private var recentEntries: [NightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -windowDays, to: .now) ?? .distantPast
        return entries.filter { $0.date >= cutoff }
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Private insights"),
                            subtitle: String(localized: "Patterns are shown as neutral signals, never as judgment. Everything here is calculated locally from your logs."),
                            symbol: "chart.xyaxis.line",
                            tint: Color.chillSecondaryBlue
                        )

                        Picker(String(localized: "Time window"), selection: $windowDays) {
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                        }
                        .pickerStyle(.segmented)

                        InsightMetricGrid(entries: recentEntries, timers: timers, journals: journals)
                        InsightMilestoneCard(
                            currentStreak: ChillInsightCalculator.recoveryStreakDays(entries: entries),
                            longestStreak: ChillInsightCalculator.longestClearStreak(entries: entries)
                        )
                        InsightHeatmapCard(levels: ChillInsightCalculator.heatmap(entries: entries, days: 35))
                        TrendListCard(title: String(localized: "What led to it?"), emptyText: String(localized: "Add trigger tags in logs to build this map."), counts: ChillInsightCalculator.triggerCounts(entries: recentEntries), tint: Color.chillSecondaryBlue)
                        TrendListCard(title: String(localized: "What changed?"), emptyText: String(localized: "When risky logs increase, reasons you tag will appear here."), counts: ChillInsightCalculator.changeReasonCounts(entries: recentEntries), tint: .orange)
                        TrendListCard(title: String(localized: "Substances"), emptyText: String(localized: "No substances logged in the selected window."), counts: ChillInsightCalculator.substanceCounts(entries: recentEntries), tint: Color.chillPrimary)
                        InsightSleepCorrelationCard(
                            substanceAvg: ChillInsightCalculator.averageSleep(entries: recentEntries, substanceNights: true),
                            clearAvg: ChillInsightCalculator.averageSleep(entries: recentEntries, substanceNights: false)
                        )
                        PersonalBaselineCard(entries: recentEntries, timers: timers)
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
        }
    }
}

private struct InsightMetricGrid: View {
    let entries: [NightEntry]
    let timers: [DrugDoseTimerRecord]
    let journals: [JournalEntry]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            InsightMetric(title: String(localized: "Chills"), value: "\(entries.filter { !$0.skippedNight }.count)", symbol: "moon.stars.fill", tint: Color.chillSecondaryBlue)
            InsightMetric(title: String(localized: "Risky logs"), value: "\(ChillInsightCalculator.riskyLogTrend(entries: entries).recent)", symbol: "exclamationmark.triangle.fill", tint: .orange)
            InsightMetric(title: String(localized: "Continued"), value: "\(timers.filter { $0.redoseDecision == RedoseDecision.redosed.rawValue }.count)", symbol: "arrow.clockwise.circle.fill", tint: .red)
            InsightMetric(title: String(localized: "Journal"), value: "\(journals.count)", symbol: "book.closed.fill", tint: Color.chillMint)
        }
    }
}

private struct InsightMetric: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title.bold())
                .foregroundStyle(Color.chillText)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        .padding(14)
        .glassSurface(radius: 24, tint: tint.opacity(0.08))
    }
}

private struct PersonalBaselineCard: View {
    let entries: [NightEntry]
    let timers: [DrugDoseTimerRecord]

    private var averageSleep: Double {
        let values = entries.filter(\.sleptYet).map(\.sleepHours)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private var lateTimers: Int {
        timers.filter { Calendar.current.component(.hour, from: $0.startedAt) >= 2 && Calendar.current.component(.hour, from: $0.startedAt) <= 6 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CareSectionTitle(title: String(localized: "Your baseline"), symbol: "person.text.rectangle.fill")
            InsightLine(title: String(localized: "Average logged sleep"), value: averageSleep == 0 ? "Not enough data" : "\(averageSleep.formatted(.number.precision(.fractionLength(1)))) h")
            InsightLine(title: String(localized: "Late timer starts"), value: "\(lateTimers)")
            InsightLine(title: String(localized: "Memory gaps"), value: "\(entries.filter(\.reportedMemoryGap).count)")
            Text("Baseline means “usual for you,” not “good” or “bad.” The app uses this to show when something changes.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08))
    }
}

private struct InsightLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.chillSecondary)
        }
    }
}

struct TrendListCard: View {
    let title: String
    let emptyText: String
    let counts: [TrendCount]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CareSectionTitle(title: title, symbol: "chart.bar.fill")

            if counts.isEmpty {
                CareEmptyState(text: emptyText)
            } else {
                ForEach(counts.prefix(6)) { item in
                    HStack(spacing: 10) {
                        Text(item.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.chillText)
                        Spacer()
                        Text("\(item.count)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(tint)
                    }
                    .padding(12)
                    .glassSurface(radius: 18, tint: tint.opacity(0.06))
                }
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: tint.opacity(0.08))
    }
}

struct TrendCount: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
}

enum ChillInsightCalculator {
    static func recoveryStreakDays(entries: [NightEntry], now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let latestUse = entries
            .filter({ !$0.substances.isEmpty })
            .map(\.date)
            .max()
        else {
            return 0
        }

        return max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: latestUse), to: calendar.startOfDay(for: now)).day ?? 0)
    }

    static func riskyLogTrend(entries: [NightEntry], now: Date = .now, calendar: Calendar = .current) -> (recent: Int, previous: Int) {
        let recentCutoff = calendar.date(byAdding: .day, value: -21, to: now) ?? now
        let previousCutoff = calendar.date(byAdding: .day, value: -42, to: now) ?? now
        var recent = 0
        var previous = 0

        for entry in entries where !entry.skippedNight && entry.hadSex && !entry.substances.isEmpty {
            if entry.date >= recentCutoff {
                recent += 1
            } else if entry.date >= previousCutoff {
                previous += 1
            }
        }

        return (recent, previous)
    }

    static func triggerCounts(entries: [NightEntry]) -> [TrendCount] {
        sortedCounts(entries.flatMap { $0.triggerTags.map(\.rawValue) })
    }

    static func changeReasonCounts(entries: [NightEntry]) -> [TrendCount] {
        sortedCounts(entries.flatMap { $0.changeReasons.map(\.rawValue) })
    }

    static func substanceCounts(entries: [NightEntry]) -> [TrendCount] {
        sortedCounts(entries.flatMap(\.substances))
    }

    private static func sortedCounts(_ values: [String]) -> [TrendCount] {
        Dictionary(grouping: values, by: { $0 })
            .map { TrendCount(label: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.label < $1.label
                }
                return $0.count > $1.count
            }
    }
}

extension ChillInsightCalculator {
    enum DayLevel {
        case none, clear, substance, risky
    }

    /// A day-by-day activity map for the last `days` days (oldest first).
    static func heatmap(entries: [NightEntry], days: Int, now: Date = .now, calendar: Calendar = .current) -> [DayLevel] {
        let start = calendar.startOfDay(for: now)
        var byDay: [Date: DayLevel] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            let level: DayLevel
            if !entry.substances.isEmpty {
                level = (entry.hadSex && !entry.skippedNight) ? .risky : .substance
            } else {
                level = .clear
            }
            byDay[day] = higher(byDay[day], level)
        }
        return (0..<max(1, days)).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: start) ?? start
            return byDay[day] ?? .none
        }
    }

    private static func higher(_ a: DayLevel?, _ b: DayLevel) -> DayLevel {
        func rank(_ level: DayLevel) -> Int {
            switch level {
            case .none: 0
            case .clear: 1
            case .substance: 2
            case .risky: 3
            }
        }
        guard let a else { return b }
        return rank(a) >= rank(b) ? a : b
    }

    /// Longest run of consecutive substance-free days ("personal best").
    static func longestClearStreak(entries: [NightEntry], now: Date = .now, calendar: Calendar = .current) -> Int {
        let substanceDays = entries
            .filter { !$0.substances.isEmpty }
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()
        guard let last = substanceDays.last else { return 0 }

        var longest = 0
        for index in 1..<max(1, substanceDays.count) {
            let gap = calendar.dateComponents([.day], from: substanceDays[index - 1], to: substanceDays[index]).day ?? 0
            longest = max(longest, max(0, gap - 1))
        }
        let sinceLast = calendar.dateComponents([.day], from: last, to: calendar.startOfDay(for: now)).day ?? 0
        return max(longest, max(0, sinceLast))
    }

    /// Average recorded sleep after substance nights vs clear nights.
    static func averageSleep(entries: [NightEntry], substanceNights: Bool) -> Double? {
        let matching = entries.filter {
            $0.sleptYet && $0.sleepHours > 0 && (substanceNights ? !$0.substances.isEmpty : $0.substances.isEmpty)
        }
        guard !matching.isEmpty else { return nil }
        return matching.map(\.sleepHours).reduce(0, +) / Double(matching.count)
    }
}

private struct InsightMilestoneCard: View {
    let currentStreak: Int
    let longestStreak: Int

    var body: some View {
        HStack(spacing: 10) {
            milestone(value: currentStreak, label: String(localized: "Current clear streak"), symbol: "flame.fill", tint: Color.chillMint)
            milestone(value: longestStreak, label: String(localized: "Personal best"), symbol: "trophy.fill", tint: Color.chillIconAmber)
        }
    }

    private func milestone(value: Int, label: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.title.bold())
                .foregroundStyle(Color.chillText)
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .padding(14)
        .glassSurface(radius: 20, tint: tint.opacity(0.08))
    }
}

private struct InsightHeatmapCard: View {
    let levels: [ChillInsightCalculator.DayLevel]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CareSectionTitle(title: String(localized: "Recent nights"), symbol: "square.grid.3x3.fill")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(levels.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(color(for: levels[index]))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Recent nights"))

            HStack(spacing: 14) {
                legend(.clear, String(localized: "Clear"))
                legend(.substance, String(localized: "Used"))
                legend(.risky, String(localized: "Sex + substances"))
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.chillSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: 24, tint: Color.chillSecondaryBlue.opacity(0.08))
    }

    private func color(for level: ChillInsightCalculator.DayLevel) -> Color {
        switch level {
        case .none: Color.white.opacity(0.10)
        case .clear: Color.chillMint.opacity(0.85)
        case .substance: Color.orange.opacity(0.85)
        case .risky: Color.red.opacity(0.85)
        }
    }

    private func legend(_ level: ChillInsightCalculator.DayLevel, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color(for: level))
                .frame(width: 11, height: 11)
            Text(label)
        }
    }
}

private struct InsightSleepCorrelationCard: View {
    let substanceAvg: Double?
    let clearAvg: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CareSectionTitle(title: String(localized: "Sleep patterns"), symbol: "bed.double.fill")

            row(label: String(localized: "After substance nights"), hours: substanceAvg, tint: .orange)
            row(label: String(localized: "After clear nights"), hours: clearAvg, tint: Color.chillMint)

            if let substanceAvg, let clearAvg, clearAvg - substanceAvg >= 0.5 {
                Text("You tend to sleep about \((clearAvg - substanceAvg).formatted(.number.precision(.fractionLength(0...1)))) hours more after a clear night.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: 24, tint: Color.chillPrimary.opacity(0.08))
    }

    private func row(label: String, hours: Double?, tint: Color) -> some View {
        HStack {
            Circle().fill(tint).frame(width: 10, height: 10)
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)
            Spacer()
            Text(hours.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) h" } ?? "—")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(Color.chillSecondary)
        }
    }
}
