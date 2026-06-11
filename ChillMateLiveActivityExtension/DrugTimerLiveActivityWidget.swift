import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct WidgetLogHydrationIntent: AppIntent {
    static let title: LocalizedStringResource = "Log hydration"
    static let description = IntentDescription("Marks that you drank water.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let defaults = UserDefaults(suiteName: "group.com.codex.ChillMate") ?? .standard
        defaults.set(true, forKey: "widgetHydrationLogged")
        return .result(value: "Logged.")
    }
}

@main
struct ChillMateLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        DrugTimerLiveActivityWidget()
        ChillMateWidgetDescriptor()
    }
}

struct ChillMateWidgetDescriptor: Widget {
    let kind = "ChillMateWidgetDescriptor"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChillMateWidgetTimelineProvider()) { entry in
            ChillMateWidgetDescriptorView(entry: entry)
        }
        .configurationDisplayName("ChillMate")
        .description("Shows your recovery streak and daily score.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct ChillMateWidgetEntry: TimelineEntry {
    let date: Date
    let recoveryStreakDays: Int
    let dailyScore: Int
    let scoreIsActive: Bool
}

private struct ChillMateWidgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChillMateWidgetEntry {
        ChillMateWidgetEntry(date: Date(), recoveryStreakDays: 7, dailyScore: 72, scoreIsActive: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (ChillMateWidgetEntry) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.codex.ChillMate") ?? .standard
        let streak = defaults.integer(forKey: "widgetRecoveryStreak")
        let score = defaults.integer(forKey: "lastDailyRecoveryScore")
        let isActive = defaults.bool(forKey: "widgetScoreIsActive")
        completion(ChillMateWidgetEntry(date: Date(), recoveryStreakDays: streak, dailyScore: score, scoreIsActive: isActive))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChillMateWidgetEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.codex.ChillMate") ?? .standard
        let streak = defaults.integer(forKey: "widgetRecoveryStreak")
        let score = defaults.integer(forKey: "lastDailyRecoveryScore")
        let isActive = defaults.bool(forKey: "widgetScoreIsActive")
        let entry = ChillMateWidgetEntry(date: Date(), recoveryStreakDays: streak, dailyScore: score, scoreIsActive: isActive)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

private struct ChillMateWidgetDescriptorView: View {
    let entry: ChillMateWidgetEntry

    @Environment(\.widgetFamily) private var family

    private var streakText: String {
        entry.recoveryStreakDays == 1 ? "1 day" : "\(entry.recoveryStreakDays) days"
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: entry.scoreIsActive ? CGFloat(min(entry.dailyScore, 100)) / 100 : 0.6)
                    .stroke(.cyan, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(entry.scoreIsActive ? "\(entry.dailyScore)" : "—")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .containerBackground(.black, for: .widget)

        case .accessoryInline:
            Label("\(streakText) clear", systemImage: "checkmark.circle")
                .containerBackground(.black, for: .widget)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("ChillMate", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.cyan)
                Text("\(streakText) without logged use")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if entry.scoreIsActive {
                    Text("Score: \(entry.dailyScore)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .containerBackground(.black, for: .widget)

        case .systemMedium:
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: entry.scoreIsActive ? CGFloat(min(entry.dailyScore, 100)) / 100 : 0.6)
                        .stroke(.cyan, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(entry.scoreIsActive ? "\(entry.dailyScore)" : "—")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 6) {
                    Text("ChillMate")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                    Text("\(streakText)")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("without logged use")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(intent: WidgetLogHydrationIntent()) {
                        Label("Log water", systemImage: "drop.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.cyan)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(12)
            .containerBackground(.black, for: .widget)

        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                    Text("ChillMate")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(streakText)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)

                Text("without logged use")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if entry.scoreIsActive {
                    Text("Score: \(entry.dailyScore)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                }
            }
            .padding(10)
            .containerBackground(.black, for: .widget)
        }
    }
}

struct DrugTimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DrugTimerActivityAttributes.self) { context in
            DrugTimerLiveActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.86))
                .activitySystemActionForegroundColor(.cyan)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.redoseNudgeActive ? "hand.raised.fill" : "timer")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(context.state.redoseNudgeActive ? .orange : .cyan)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    TimerText(endDate: context.state.endsAt)
                        .font(.caption.weight(.bold))
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.redoseNudgeActive {
                        Text("Consider waiting")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                // Show the (fixed) end time rather than a ticking H:MM:SS countdown.
                // The countdown reserves a wide area and stretches the Dynamic Island
                // pill; the end time is content-sized and always correct without ticking.
                Text(context.state.endsAt, style: .time)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.cyan)
            } minimal: {
                Image(systemName: context.state.redoseNudgeActive ? "hand.raised.fill" : "timer")
                    .foregroundStyle(context.state.redoseNudgeActive ? .orange : .cyan)
            }
        }
    }
}

private struct DrugTimerLiveActivityView: View {
    let context: ActivityViewContext<DrugTimerActivityAttributes>

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: context.state.redoseNudgeActive ? "hand.raised.fill" : "timer")
                .font(.headline.bold())
                .foregroundStyle(context.state.redoseNudgeActive ? .orange : .cyan)

            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.substanceName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(context.state.redoseNudgeActive ? "Pause and check in" : "Wellbeing check-in")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(context.state.redoseNudgeActive ? .orange : .white.opacity(0.76))
            }

            Spacer()

            TimerText(endDate: context.state.endsAt)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal)
        .padding(.vertical, 7)
    }
}

private struct TimerText: View {
    let endDate: Date

    var body: some View {
        Text(timerInterval: Date.now...max(Date.now.addingTimeInterval(1), endDate), countsDown: true)
    }
}
