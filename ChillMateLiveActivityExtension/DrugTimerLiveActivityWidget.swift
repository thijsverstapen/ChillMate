import ActivityKit
import SwiftUI
import WidgetKit

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
        .description("Shows ChillMate timer support for Live Activities.")
        .supportedFamilies([.systemSmall])
    }
}

private struct ChillMateWidgetEntry: TimelineEntry {
    let date: Date
}

private struct ChillMateWidgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChillMateWidgetEntry {
        ChillMateWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (ChillMateWidgetEntry) -> Void) {
        completion(ChillMateWidgetEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChillMateWidgetEntry>) -> Void) {
        let entry = ChillMateWidgetEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

private struct ChillMateWidgetDescriptorView: View {
    let entry: ChillMateWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "timer")
                .font(.title3.weight(.bold))
                .foregroundStyle(.cyan)

            Text("ChillMate")
                .font(.headline.weight(.bold))

            Text("Timer ready")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.black, for: .widget)
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
                        Text("Avoid redosing")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                TimerText(endDate: context.state.endsAt)
                    .font(.caption2.weight(.bold))
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

                Text(context.state.redoseNudgeActive ? "Avoid redosing now" : "Effect window")
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
