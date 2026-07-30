import SwiftUI
import WidgetKit

// MARK: - Shared snapshot

/// Reads the snapshot the watch app writes into the shared App Group after every
/// WatchConnectivity sync (see WatchConnectivityReceiver.publishWidgetSnapshot).
/// Both ends now read their key strings from `WidgetSharedKey`, so they cannot drift.
enum WidgetStore {
    /// Computed rather than a stored static: `UserDefaults?` is not `Sendable`, and
    /// this target builds with Swift 6 strict concurrency.
    static var suite: UserDefaults? { WidgetSharedKey.suite }

    static var streakDays: Int { suite?.integer(forKey: WidgetSharedKey.watchStreakDays) ?? 0 }
    static var score: Int { suite?.integer(forKey: WidgetSharedKey.watchScore) ?? 0 }
    static var scoreActive: Bool { suite?.bool(forKey: WidgetSharedKey.watchScoreActive) ?? false }

    static var activeTimer: (substance: String, start: Date, end: Date)? {
        guard let suite,
              let substance = suite.string(forKey: WidgetSharedKey.watchTimerSubstance),
              !substance.isEmpty else { return nil }
        let end = suite.double(forKey: WidgetSharedKey.watchTimerEnd)
        guard end > Date.now.timeIntervalSince1970 else { return nil }
        let start = suite.double(forKey: WidgetSharedKey.watchTimerStart)
        return (substance, Date(timeIntervalSince1970: start), Date(timeIntervalSince1970: end))
    }
}

// MARK: - Recovery streak complication

struct StreakEntry: TimelineEntry {
    let date: Date
    let streakDays: Int
    let score: Int
    let scoreActive: Bool
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, streakDays: 7, score: 72, scoreActive: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        // The watch app reloads timelines whenever synced data changes; the
        // midnight refresh keeps the day count honest in between.
        let nextMidnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400)
        completion(Timeline(entries: [currentEntry()], policy: .after(nextMidnight)))
    }

    private func currentEntry() -> StreakEntry {
        StreakEntry(
            date: .now,
            streakDays: WidgetStore.streakDays,
            score: WidgetStore.score,
            scoreActive: WidgetStore.scoreActive
        )
    }
}

struct ChillMateStreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ChillMateStreak", provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Recovery streak")
        .description("Days without logged use, at a glance.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

private struct StreakWidgetView: View {
    let entry: StreakEntry
    @Environment(\.widgetFamily) private var family

    private var daysClearText: String {
        entry.streakDays == 1 ? String(localized: "day clear") : String(localized: "days clear")
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("\(entry.streakDays)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 9))
                }
            }
            .widgetAccentable()

        case .accessoryCorner:
            Text("\(entry.streakDays)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .widgetAccentable()
                .widgetLabel {
                    Text(daysClearText)
                }

        case .accessoryInline:
            Text("\(entry.streakDays) \(daysClearText)")

        default:
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text("Recovery streak")
                        .font(.caption2.weight(.semibold))
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.mint)
                }
                Text("\(entry.streakDays) \(daysClearText)")
                    .font(.headline.weight(.bold))
                if entry.scoreActive {
                    Text("Score \(entry.score)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetAccentable()
        }
    }
}

// MARK: - Dose timer complication

struct TimerEntry: TimelineEntry {
    let date: Date
    let substance: String?
    let start: Date
    let end: Date
}

struct TimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimerEntry {
        TimerEntry(date: .now, substance: "Timer", start: .now, end: .now.addingTimeInterval(3 * 3600))
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerEntry>) -> Void) {
        let entry = currentEntry()
        if entry.substance != nil {
            // Refresh right when the effect window ends so the idle state shows.
            completion(Timeline(entries: [entry], policy: .after(entry.end)))
        } else {
            // The watch app reloads timelines when a timer starts.
            completion(Timeline(entries: [entry], policy: .never))
        }
    }

    private func currentEntry() -> TimerEntry {
        if let active = WidgetStore.activeTimer {
            return TimerEntry(date: .now, substance: active.substance, start: active.start, end: active.end)
        }
        return TimerEntry(date: .now, substance: nil, start: .now, end: .now)
    }
}

struct ChillMateTimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ChillMateDoseTimer", provider: TimerProvider()) { entry in
            TimerWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Dose timer")
        .description("Live countdown of the current effect window.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}

private struct TimerWidgetView: View {
    let entry: TimerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let substance = entry.substance {
            switch family {
            case .accessoryCircular:
                ProgressView(timerInterval: entry.start...entry.end, countsDown: true) {
                    Text(substance)
                } currentValueLabel: {
                    Image(systemName: "timer")
                        .font(.system(size: 15, weight: .semibold))
                }
                .progressViewStyle(.circular)
                .widgetAccentable()

            case .accessoryInline:
                Text("\(substance) \(Text(timerInterval: entry.start...entry.end, countsDown: true))")

            default:
                VStack(alignment: .leading, spacing: 2) {
                    Label {
                        Text(substance)
                            .font(.caption2.weight(.semibold))
                    } icon: {
                        Image(systemName: "timer")
                            .foregroundStyle(.mint)
                    }
                    Text(timerInterval: entry.start...entry.end, countsDown: true)
                        .font(.headline.weight(.bold).monospacedDigit())
                    Text("Effect window")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetAccentable()
            }
        } else {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

            case .accessoryInline:
                Text("No active timer")

            default:
                VStack(alignment: .leading, spacing: 2) {
                    Label {
                        Text("Dose timer")
                            .font(.caption2.weight(.semibold))
                    } icon: {
                        Image(systemName: "timer")
                            .foregroundStyle(.secondary)
                    }
                    Text("No active timer")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
