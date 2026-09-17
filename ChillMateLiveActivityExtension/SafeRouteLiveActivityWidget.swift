import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The journey home on the Lock Screen: a time, a state, and one button.
///
/// No destination anywhere in here. `SafeRouteActivityAttributes` does not carry
/// one and this view could not draw it if it wanted to — the Lock Screen is
/// readable by whoever is standing next to you, and where somebody lives is not
/// something this app puts there.
struct SafeRouteLiveActivityWidget: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SafeRouteActivityAttributes.self) { context in
            SafeRouteLiveActivityView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.86))
                .activitySystemActionForegroundColor(.mint)
        } dynamicIsland: { context in
            let overdue = context.state.isOverdue(at: .now)
            let accent: Color = context.state.arrivedAt != nil ? .mint : (overdue ? .orange : .cyan)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text("Getting home")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    } icon: {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(accent)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.expectedArrival, style: .time)
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(accent)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.arrivedAt == nil {
                        Button(intent: SafeRouteArrivedIntent()) {
                            Label("I'm home", systemImage: "house.fill")
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.mint)
                    } else {
                        Label("Home", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.mint)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.arrivedAt != nil ? "house.fill" : "figure.walk")
                    .foregroundStyle(accent)
            } compactTrailing: {
                Text(context.state.expectedArrival, style: .time)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent)
            } minimal: {
                Image(systemName: context.state.arrivedAt != nil ? "house.fill" : "figure.walk")
                    .foregroundStyle(accent)
            }
        }
    }
}

private struct SafeRouteLiveActivityView: View {
    let state: SafeRouteActivityAttributes.ContentState

    private var hasArrived: Bool { state.arrivedAt != nil }

    var body: some View {
        // Re-evaluated every minute so "expected" becomes "overdue" on its own.
        // Nothing pushes an update at that moment: the app may well be closed and
        // the phone in a pocket, which is the situation this whole thing is for.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let overdue = state.isOverdue(at: context.date)
            let accent: Color = hasArrived ? .mint : (overdue ? .orange : .cyan)

            HStack(alignment: .center, spacing: 12) {
                Image(systemName: hasArrived ? "house.fill" : (overdue ? "exclamationmark.circle.fill" : "figure.walk"))
                    .font(.title3.bold())
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(hasArrived ? "Home" : (overdue ? "Still out" : "Getting home"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)

                    if hasArrived {
                        Text("Marked home")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.66))
                    } else {
                        Text("Expected \(state.expectedArrival, style: .time)")
                            .font(.caption2)
                            .foregroundStyle(overdue ? .orange : .white.opacity(0.66))
                    }
                }

                Spacer(minLength: 8)

                if !hasArrived {
                    Button(intent: SafeRouteArrivedIntent()) {
                        Label("I'm home", systemImage: "house.fill")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.mint)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}
