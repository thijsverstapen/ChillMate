import SwiftUI
import ChillMateCore

// Dose history and timeline rows, shown in the calendar.

struct DrugDoseHistoryGraph: View {
    let rows: [DoseHistoryRow]
    let monthDays: [Date]

    init(timers: [DrugDoseTimerRecord], entries: [NightEntry], monthDays: [Date]) {
        self.monthDays = monthDays
        rows = DoseHistoryRow.make(timers: timers, entries: entries, monthDays: monthDays)
    }

    private var maxCount: Int {
        max(1, rows.flatMap(\.dayCounts).max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: String(localized: "Substance pattern history"), symbol: "chart.xyaxis.line")

            if rows.isEmpty {
                EmptyGlassState(text: String(localized: "Start a check-in or log substances to see private patterns here."))
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text(String(localized: "A private month view for spotting changes over time. It does not label anything as good or bad."))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(rows.prefix(6)) { row in
                        DoseHistoryRowView(row: row, maxCount: maxCount)
                    }
                }
                .padding(16)
                .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08), interactive: true)
            }
        }
    }
}

// Internal alongside the graph that publishes it: `DrugDoseHistoryGraph` is used
// from the calendar now, and a public-facing type cannot expose a private one.
struct DoseHistoryRow: Identifiable {
    let id: String
    let substance: String
    let dayCounts: [Int]
    let routeSummary: String
    let doseNotesCount: Int
    let redoseDays: Int

    static func make(timers: [DrugDoseTimerRecord], entries: [NightEntry], monthDays: [Date], calendar: Calendar = .current) -> [DoseHistoryRow] {
        let dayKeys = monthDays.map { calendar.startOfDay(for: $0) }
        var countsBySubstance: [String: [Date: Int]] = [:]
        var routeCounts: [String: [String: Int]] = [:]
        var doseNotes: [String: Int] = [:]

        for timer in timers {
            let substance = timer.substanceName
            let day = calendar.startOfDay(for: timer.startedAt)
            countsBySubstance[substance, default: [:]][day, default: 0] += 1
            let routeLabel = AdministrationRoute(rawValue: timer.administrationRoute)?.displayName ?? timer.administrationRoute
            routeCounts[substance, default: [:]][routeLabel, default: 0] += 1
            if !timer.doseNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                doseNotes[substance, default: 0] += 1
            }
        }

        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            for substance in entry.substances {
                countsBySubstance[substance, default: [:]][day, default: 0] += 1
                if routeCounts[substance] == nil {
                    routeCounts[substance] = ["Logged": 1]
                }
            }
        }

        return countsBySubstance.map { substance, dayMap in
            let counts = dayKeys.map { dayMap[$0] ?? 0 }
            let routes = (routeCounts[substance] ?? [:])
                .sorted { first, second in
                    first.value == second.value ? first.key < second.key : first.value > second.value
                }
                .prefix(3)
                .map { "\($0.key) \($0.value)" }
                .joined(separator: " · ")
            return DoseHistoryRow(
                id: substance,
                substance: substance,
                dayCounts: counts,
                routeSummary: routes.isEmpty ? String(localized: "No route saved") : routes,
                doseNotesCount: doseNotes[substance] ?? 0,
                redoseDays: dayMap.values.filter { $0 > 1 }.count
            )
        }
        .sorted { first, second in
            let firstTotal = first.dayCounts.reduce(0, +)
            let secondTotal = second.dayCounts.reduce(0, +)
            return firstTotal == secondTotal ? first.substance < second.substance : firstTotal > secondTotal
        }
    }
}

private struct DoseHistoryRowView: View {
    let row: DoseHistoryRow
    let maxCount: Int

    private var total: Int {
        row.dayCounts.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.substance)
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
                Spacer()
                Text(String(localized: "\(total) logged"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondaryBlue)
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(row.dayCounts.enumerated()), id: \.offset) { _, count in
                    Capsule()
                        .fill(count > 0 ? LinearGradient(colors: [Color.chillPrimary.opacity(0.90), Color.chillSecondaryBlue.opacity(0.70)], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.07)], startPoint: .top, endPoint: .bottom))
                        .frame(maxWidth: .infinity)
                        .frame(height: count > 0 ? max(8, CGFloat(count) / CGFloat(maxCount) * 42) : 6)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 46)

            Text("\(row.routeSummary) · \(row.redoseDays) continued day\(row.redoseDays == 1 ? "" : "s") · \(row.doseNotesCount) private note\(row.doseNotesCount == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct SubstanceBar: View {
    let name: String
    let count: Int
    let maxCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.chillText)
                Spacer()
                Text("\(count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.chillSecondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.black.opacity(0.10))
                    Capsule()
                        .fill(.linearGradient(colors: [Color.chillMint, Color.chillSecondaryBlue, Color.chillAccentTeal], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(12, proxy.size.width * CGFloat(count) / CGFloat(max(maxCount, 1))))
                }
                .scrollIndicators(.hidden)
            }
            .frame(height: 9)
        }
    }
}

struct TimelineRow: View {
    let entry: NightEntry
    let delete: (NightEntry) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 4) {
                Text(entry.date.formatted(.dateTime.day()))
                    .font(.title3.bold())
                    .foregroundStyle(Color.chillText)
                Text(entry.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
            }
            .frame(width: 48)
            .padding(.vertical, 8)
            .glassSurface(radius: 18, tint: entry.skippedNight ? .indigo.opacity(0.14) : Color.chillAccentTeal.opacity(0.14))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(entry.skippedNight ? String(localized: "Skipped Chill") : String(localized: "Sex + substances"))
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                    Spacer()
                    Button(role: .destructive) {
                        delete(entry)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.chillSecondary)
                    }
                    .buttonStyle(ChillPlainButtonStyle())
                    .accessibilityLabel("Delete entry")
                }

                Label(entry.timeFrameSummary, systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)

                if entry.hasLocation {
                    Label(entry.locationSummary, systemImage: "location.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .lineLimit(2)
                }

                if entry.hadSex, !entry.skippedNight {
                    Label(entry.partnerSummary, systemImage: "person.2.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)

                    Label(entry.saferSexSummary, systemImage: "shield")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                }

                if entry.substances.isEmpty {
                    Text(String(localized: "No substances recorded."))
                        .font(.subheadline)
                        .foregroundStyle(Color.chillSecondary)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(Array(entry.substances.enumerated()), id: \.offset) { _, substance in
                            Text(substance)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.chillText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .glassSurface(radius: 14, tint: .black.opacity(0.04))
                        }
                    }
                }

                if !entry.injectionSubstances.isEmpty {
                    Label("Injection context: \(entry.injectionSubstances.joined(separator: ", "))", systemImage: "syringe.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillMint)
                        .lineLimit(2)
                }

                Text(entry.sleepSummary)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.chillSecondary)
                    .lineLimit(2)

                if !entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(entry.note)
                        .font(.footnote)
                        .foregroundStyle(Color.chillSecondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(14)
        .glassSurface(radius: 28, tint: .black.opacity(0.04))
    }
}
