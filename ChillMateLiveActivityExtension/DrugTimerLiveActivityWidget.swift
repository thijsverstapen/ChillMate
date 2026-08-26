import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct WidgetLogHydrationIntent: AppIntent {
    static let title: LocalizedStringResource = "Log hydration"
    static let description = IntentDescription("Marks that you drank water.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Shared contract with the app's `HydrationLog` (ChillMate/AppIntents.swift):
        // a date-stamped daily flag in the App Group suite under "lastHydrationLogDate".
        // Previously this wrote a dead "widgetHydrationLogged" boolean that nothing read.
        //
        // The key is still spelled out at both ends because this file is compiled into
        // the Live Activity extension only and `HydrationLog` into the app only, so
        // neither can see the other's constant. Suite and spelling have to match exactly
        // or a tap on Log water records into a store the app never reads, with no error.
        // The one fix is a constant in `WidgetSharedKey`, which every target compiles.
        let defaults = UserDefaults(suiteName: WidgetSharedKey.suiteName) ?? .standard
        defaults.set(Date.now.timeIntervalSince1970, forKey: WidgetSharedKey.hydrationLogDate)
        return .result(value: "Logged.")
    }
}

/// Opens ChillMate on panic support. A control runs in this extension's process,
/// so it cannot write the app's own `UserDefaults`; it leaves the destination in
/// the shared App Group and `adoptControlDestination()` picks it up on foreground.
struct OpenPanicSupportControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Open panic support"
    static let description = IntentDescription("Opens breathing, grounding, and emergency contacts in ChillMate.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: WidgetSharedKey.suiteName) ?? .standard
        defaults.set(WidgetSharedKey.destinationPanic, forKey: WidgetSharedKey.pendingDestination)
        return .result()
    }
}

/// Panic support from the Lock Screen without unlocking first, which is the
/// point: at 4am the phone is locked and the person needing it is not at their best.
struct PanicSupportControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.BIJTHIJS.ChillMate.control.panic") {
            ControlWidgetButton(action: OpenPanicSupportControlIntent()) {
                Label("Get help", systemImage: "cross.case.fill")
            }
        }
        .displayName("ChillMate help")
        .description("Opens breathing, grounding, and emergency contacts.")
    }
}

/// Logs water without opening anything at all.
struct LogWaterControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.BIJTHIJS.ChillMate.control.water") {
            ControlWidgetButton(action: WidgetLogHydrationIntent()) {
                Label("Log water", systemImage: "drop.fill")
            }
        }
        .displayName("Log water")
        .description("Records that you drank water, without opening ChillMate.")
    }
}

@main
struct ChillMateLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        DrugTimerLiveActivityWidget()
        ChillMateWidgetDescriptor()
        PanicSupportControl()
        LogWaterControl()
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
        let defaults = UserDefaults(suiteName: WidgetSharedKey.suiteName) ?? .standard
        let streak = defaults.integer(forKey: WidgetSharedKey.recoveryStreak)
        let score = defaults.integer(forKey: WidgetSharedKey.dailyScore)
        let isActive = defaults.bool(forKey: WidgetSharedKey.scoreIsActive)
        completion(ChillMateWidgetEntry(date: Date(), recoveryStreakDays: streak, dailyScore: score, scoreIsActive: isActive))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChillMateWidgetEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: WidgetSharedKey.suiteName) ?? .standard
        let streak = defaults.integer(forKey: WidgetSharedKey.recoveryStreak)
        let score = defaults.integer(forKey: WidgetSharedKey.dailyScore)
        let isActive = defaults.bool(forKey: WidgetSharedKey.scoreIsActive)
        let entry = ChillMateWidgetEntry(date: Date(), recoveryStreakDays: streak, dailyScore: score, scoreIsActive: isActive)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

private struct ChillMateWidgetDescriptorView: View {
    let entry: ChillMateWidgetEntry

    @Environment(\.widgetFamily) private var family

    private var streakText: String {
        // Verbatim before: "1 day" / "5 days" were plain Swift strings, so the
        // widget counted in English on every device. The catalog now carries the
        // plural forms for all five languages.
        String(localized: "\(entry.recoveryStreakDays) days")
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
                Text(entry.scoreIsActive ? "\(entry.dailyScore)" : "n/a")
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
                    Text(entry.scoreIsActive ? "\(entry.dailyScore)" : "n/a")
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
            let accent: Color = context.state.redoseNudgeActive ? .orange : .cyan

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.redoseNudgeActive ? "hand.raised.fill" : "timer")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accent)

                        Text(context.attributes.substanceName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    TimerText(endDate: context.state.endsAt)
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        SessionProgressBar(state: context.state, accent: accent)

                        HStack(spacing: 10) {
                            if context.state.redoseNudgeActive {
                                Label("Consider waiting", systemImage: "hand.raised.fill")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.orange)
                                    .lineLimit(1)
                            } else {
                                Text("Ends \(context.state.endsAt, style: .time)")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.66))
                            }

                            Spacer(minLength: 0)

                            Button(intent: WidgetLogHydrationIntent()) {
                                Label("Log water", systemImage: "drop.fill")
                                    .font(.caption2.weight(.bold))
                            }
                            .buttonStyle(.bordered)
                            .tint(.cyan)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.redoseNudgeActive ? "hand.raised.fill" : "timer")
                    .foregroundStyle(accent)
            } compactTrailing: {
                // Show the (fixed) end time rather than a ticking H:MM:SS countdown.
                // The countdown reserves a wide area and stretches the Dynamic Island
                // pill; the end time is content-sized and always correct without ticking.
                Text(context.state.endsAt, style: .time)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent)
            } minimal: {
                Image(systemName: context.state.redoseNudgeActive ? "hand.raised.fill" : "timer")
                    .foregroundStyle(accent)
            }
        }
    }
}

/// Fills as the session runs. ActivityKit animates this between updates on its
/// own, so it stays accurate without the app pushing a new state every minute.
/// Draws nothing when the activity predates `startedAt`.
private struct SessionProgressBar: View {
    let state: DrugTimerActivityAttributes.ContentState
    let accent: Color

    var body: some View {
        if let startedAt = state.startedAt, startedAt < state.endsAt {
            ProgressView(timerInterval: startedAt...state.endsAt, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(accent)
        }
    }
}

private struct DrugTimerLiveActivityView: View {
    let context: ActivityViewContext<DrugTimerActivityAttributes>

    private var accent: Color { context.state.redoseNudgeActive ? .orange : .cyan }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: context.state.redoseNudgeActive ? "hand.raised.fill" : "timer")
                    .font(.headline.bold())
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.substanceName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(context.state.redoseNudgeActive ? "Pause and check in" : "Wellbeing check-in")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(context.state.redoseNudgeActive ? .orange : .white.opacity(0.76))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    TimerText(endDate: context.state.endsAt)
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white)

                    Text("Ends \(context.state.endsAt, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            SessionProgressBar(state: context.state, accent: accent)

            Button(intent: WidgetLogHydrationIntent()) {
                Label("Log water", systemImage: "drop.fill")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct TimerText: View {
    let endDate: Date

    var body: some View {
        Text(timerInterval: Date.now...max(Date.now.addingTimeInterval(1), endDate), countsDown: true)
    }
}
