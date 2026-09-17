import SwiftUI
import WidgetKit

/// The running dose, on the Lock Screen, without unlocking anything.
///
/// There is already a Live Activity for this, and it is better while it lasts.
/// It also goes away: dismissed by a swipe, ended by the system after eight
/// hours, and gone entirely after a restart. The window this widget is for
/// outlives all of that — an MDMA dose has a published after-effects window of up
/// to 48 hours, and the useful question at hour twenty is not "how long is left
/// on my reminder" but "is this still the thing making me feel like this".
///
/// It shows nothing at all when nothing is running, rather than an invitation.
/// This is not a surface that should ever advertise.
struct DoseTimerWidget: Widget {
    let kind = "ChillMateDoseTimer"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DoseTimerTimelineProvider()) { entry in
            DoseTimerWidgetView(entry: entry)
        }
        .configurationDisplayName("Dose timer")
        .description("Shows a running check-in timer and how long the published effects run for.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct DoseTimerEntry: TimelineEntry {
    let date: Date
    let snapshot: DoseTimerSnapshot?

    /// Which half of the curve this entry sits in.
    var isComedown: Bool {
        guard let snapshot else { return false }
        return snapshot.isInComedown(at: date)
    }
}

/// Entries at the phase boundaries and nowhere else.
///
/// The countdown itself is drawn with `Text(timerInterval:)`, which ticks on its
/// own without the widget being reloaded, so the only moments that need a new
/// entry are the ones where the *wording* changes: the check-in window ending,
/// and the published window running out. A fifteen-minute schedule across a
/// 48-hour after-effects window would be 192 entries to say the same sentence.
struct DoseTimerTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> DoseTimerEntry {
        DoseTimerEntry(
            date: .now,
            snapshot: DoseTimerSnapshot(
                substanceName: "MDMA",
                startedAt: .now.addingTimeInterval(-3600),
                endsAt: .now.addingTimeInterval(3600),
                comedownEndsAt: .now.addingTimeInterval(12 * 3600)
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DoseTimerEntry) -> Void) {
        completion(DoseTimerEntry(date: .now, snapshot: DoseTimerSnapshot.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoseTimerEntry>) -> Void) {
        let now = Date.now
        guard let snapshot = DoseTimerSnapshot.read(now: now) else {
            // Nothing running. One empty entry, and no policy that would have the
            // system wake this up again for no reason — the app reloads timelines
            // itself the moment a timer starts.
            completion(Timeline(entries: [DoseTimerEntry(date: now, snapshot: nil)], policy: .never))
            return
        }

        var entries = [DoseTimerEntry(date: now, snapshot: snapshot)]
        if snapshot.endsAt > now {
            entries.append(DoseTimerEntry(date: snapshot.endsAt, snapshot: snapshot))
        }
        entries.append(DoseTimerEntry(date: snapshot.lastMoment, snapshot: nil))

        completion(Timeline(entries: entries, policy: .after(snapshot.lastMoment)))
    }
}

struct DoseTimerWidgetView: View {
    let entry: DoseTimerEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            inline.containerBackground(.clear, for: .widget)
        case .accessoryCircular:
            circular.containerBackground(.clear, for: .widget)
        default:
            rectangular.containerBackground(.clear, for: .widget)
        }
    }

    @ViewBuilder
    private var inline: some View {
        if let snapshot = entry.snapshot {
            if entry.isComedown {
                Label("\(snapshot.substanceName) · after effects", systemImage: "moon.zzz.fill")
            } else {
                Label {
                    Text(timerInterval: entry.date...max(entry.date.addingTimeInterval(1), snapshot.endsAt), countsDown: true)
                } icon: {
                    Image(systemName: "timer")
                }
            }
        } else {
            Text(verbatim: "")
        }
    }

    @ViewBuilder
    private var circular: some View {
        if let snapshot = entry.snapshot {
            ZStack {
                AccessoryWidgetBackground()
                if entry.isComedown {
                    Image(systemName: "moon.zzz.fill")
                        .font(.headline)
                } else {
                    ProgressView(
                        timerInterval: snapshot.startedAt...max(snapshot.startedAt.addingTimeInterval(1), snapshot.endsAt),
                        countsDown: true
                    ) {
                        EmptyView()
                    } currentValueLabel: {
                        Image(systemName: "timer")
                            .font(.caption2)
                    }
                    .progressViewStyle(.circular)
                }
            }
            .accessibilityLabel(accessibilityLabel(snapshot))
        } else {
            Text(verbatim: "")
        }
    }

    @ViewBuilder
    private var rectangular: some View {
        if let snapshot = entry.snapshot {
            VStack(alignment: .leading, spacing: 1) {
                Label(snapshot.substanceName, systemImage: entry.isComedown ? "moon.zzz.fill" : "timer")
                    .font(.caption.weight(.bold))
                    .lineLimit(1)

                if entry.isComedown {
                    Text("After effects")
                        .font(.caption2.weight(.semibold))
                    if let end = snapshot.comedownEndsAt {
                        Text("until \(end.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(timerInterval: entry.date...max(entry.date.addingTimeInterval(1), snapshot.endsAt), countsDown: true)
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                    if snapshot.comedownEndsAt != nil {
                        Text("After effects follow")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else {
            Text(verbatim: "")
        }
    }

    private func accessibilityLabel(_ snapshot: DoseTimerSnapshot) -> Text {
        entry.isComedown
            ? Text("\(snapshot.substanceName), after effects")
            : Text("\(snapshot.substanceName), check-in timer running")
    }
}
