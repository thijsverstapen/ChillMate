import SwiftUI
import WatchConnectivity
import WatchKit

struct WatchDashboardView: View {
    @StateObject private var connectivity = WatchConnectivityReceiver.shared
    @State private var breathingActive = false
    @State private var breathingScale: CGFloat = 1.0
    @State private var hapticTick = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    WatchStatusCard(
                        title: "Discreet check-in",
                        subtitle: connectivity.checkInsEnabled ? "Haptic nudges on" : "Paused",
                        symbol: connectivity.checkInsEnabled ? "hand.tap.fill" : "hand.raised.fill"
                    ) {
                        connectivity.checkInsEnabled.toggle()
                        WKInterfaceDevice.current().play(.click)
                    }

                    if let timer = connectivity.activeTimers.first {
                        WatchActiveTimerCard(timer: timer)
                    } else {
                        WatchStatusCard(
                            title: "No active timer",
                            subtitle: "Start a timer on iPhone",
                            symbol: "timer"
                        ) {}
                    }

                    WatchStatusCard(
                        title: "Hydration",
                        subtitle: connectivity.hydrationLoggedToday ? "Water logged today" : "Tap after water",
                        symbol: connectivity.hydrationLoggedToday ? "checkmark.circle.fill" : "drop.fill"
                    ) {
                        connectivity.logHydration()
                        WKInterfaceDevice.current().play(connectivity.hydrationLoggedToday ? .success : .click)
                    }

                    WatchStatusCard(
                        title: "Nothing happened",
                        subtitle: connectivity.quickSkipSentToday ? "Logged on iPhone" : "Tap to log a skip",
                        symbol: connectivity.quickSkipSentToday ? "checkmark.circle.fill" : "moon.zzz.fill"
                    ) {
                        guard !connectivity.quickSkipSentToday else { return }
                        connectivity.logQuickSkip()
                        WKInterfaceDevice.current().play(.success)
                    }

                    BreathingExerciseCard(isActive: $breathingActive, scale: breathingScale)

                    if connectivity.heartRateWarningsEnabled, let bpm = connectivity.latestBPM {
                        WatchHeartRateCard(bpm: bpm)
                    }
                }
                .padding(.horizontal, 6)
            }
            .navigationTitle("ChillMate")
            .task(id: breathingActive) {
                guard breathingActive else {
                    breathingScale = 1.0
                    return
                }

                while breathingActive {
                    withAnimation(.easeInOut(duration: 4)) {
                        breathingScale = breathingActive ? 1.5 : 1.0
                    }
                    hapticTick += 1
                    WKInterfaceDevice.current().play(.click)
                    try? await Task.sleep(for: .seconds(4))
                    withAnimation(.easeInOut(duration: 4)) {
                        breathingScale = 1.0
                    }
                    try? await Task.sleep(for: .seconds(4))
                }
            }
        }
    }
}

private struct WatchActiveTimerCard: View {
    let timer: WatchTimerInfo

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(timer.startedAt))
            let total = timer.durationSeconds
            let progress = min(1, elapsed / total)
            let remaining = max(0, total - elapsed)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(timer.substanceName, systemImage: "timer")
                        .font(.headline)
                    Spacer()
                    Text(remaining.formattedRemaining)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Gauge(value: progress) {
                    Text("Effect window")
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(progress > 0.75 ? .orange : .mint)
            }
            .padding(12)
            .watchCard()
        }
    }
}

private struct WatchHeartRateCard: View {
    let bpm: Double

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundStyle(bpm > 110 ? .red : .mint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Heart rate")
                    .font(.headline)
                Text("\(Int(bpm)) bpm")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .watchCard()
    }
}

private struct WatchTimerCard: View {
    let startedAt: Date
    let duration: TimeInterval
    let restart: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startedAt))
            let progress = min(1, elapsed / duration)
            let remaining = max(0, duration - elapsed)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Check-in", systemImage: "timer")
                        .font(.headline)
                    Spacer()
                    Text(remaining.formattedRemaining)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Gauge(value: progress) {
                    Text("Wellbeing window")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(progress > 0.7 ? .orange : .mint)

                Button("Restart check-in", action: restart)
                    .buttonStyle(.borderedProminent)
                    .font(.caption.weight(.semibold))
            }
            .padding(12)
            .watchCard()
        }
    }
}

private struct WatchStatusCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.mint)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .watchCard()
        }
        .buttonStyle(.plain)
    }
}

private struct BreathingExerciseCard: View {
    @Binding var isActive: Bool
    let scale: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Breathing", systemImage: "circle.dotted")
                    .font(.headline)
                Spacer()
                Button(isActive ? "Stop" : "Start") {
                    isActive.toggle()
                    WKInterfaceDevice.current().play(isActive ? .start : .stop)
                }
                .font(.caption.weight(.semibold))
            }

            ZStack {
                Circle()
                    .fill(.mint.opacity(0.22))
                    .frame(width: 38 * scale, height: 38 * scale)

                Circle()
                    .fill(.mint.opacity(0.12))
                    .frame(width: 58 * scale, height: 58 * scale)
                    .opacity(isActive ? 1 : 0)

                Text(isActive ? "Breathe" : "Ready")
                    .font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 4), value: scale)
        }
        .padding(12)
        .watchCard()
    }
}

private extension View {
    func watchCard() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private extension TimeInterval {
    var formattedRemaining: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return "\(minutes):\(seconds.twoDigitPadded)"
    }
}

private extension Int {
    var twoDigitPadded: String {
        self < 10 ? "0\(self)" : "\(self)"
    }
}

struct WatchTimerInfo: Identifiable {
    let id: UUID
    let substanceName: String
    let startedAt: Date
    let durationSeconds: TimeInterval
}

@MainActor
final class WatchConnectivityReceiver: NSObject, ObservableObject {
    static let shared = WatchConnectivityReceiver()

    @Published var activeTimers: [WatchTimerInfo] = []
    @Published var hydrationLoggedToday = false
    @Published var quickSkipSentToday = false
    @Published var checkInsEnabled = true
    @Published var heartRateWarningsEnabled = false
    @Published var latestBPM: Double? = nil

    private override init() {
        super.init()
        activate()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func logHydration() {
        hydrationLoggedToday = true
        let message: [String: Any] = ["hydrationLogged": true]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(message)
        }
    }

    func logQuickSkip() {
        quickSkipSentToday = true
        let message: [String: Any] = ["quickSkipRequested": true]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(message)
        }
    }

    private func applyContext(_ context: [String: Any]) {
        if let timersPayload = context["timers"] as? [[String: Any]] {
            activeTimers = timersPayload.compactMap { dict in
                guard
                    let idStr = dict["id"] as? String,
                    let id = UUID(uuidString: idStr),
                    let substance = dict["substance"] as? String,
                    let startedAt = dict["startedAt"] as? TimeInterval,
                    let durationHours = dict["durationHours"] as? Double
                else { return nil }
                return WatchTimerInfo(
                    id: id,
                    substanceName: substance,
                    startedAt: Date(timeIntervalSince1970: startedAt),
                    durationSeconds: durationHours * 3600
                )
            }
        }
        if let hydrationReminders = context["watchHydrationReminders"] as? Bool {
            _ = hydrationReminders
        }
        if let hrWarnings = context["watchHeartRateWarnings"] as? Bool {
            heartRateWarningsEnabled = hrWarnings
        }
    }
}

private struct WCContextBox: @unchecked Sendable {
    let dict: [String: Any]
}

extension WatchConnectivityReceiver: @preconcurrency WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        guard activationState == .activated else { return }
        let box = WCContextBox(dict: session.receivedApplicationContext)
        Task { @MainActor in
            self.applyContext(box.dict)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let box = WCContextBox(dict: message)
        Task { @MainActor in
            self.applyContext(box.dict)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let box = WCContextBox(dict: applicationContext)
        Task { @MainActor in
            self.applyContext(box.dict)
        }
    }
}
