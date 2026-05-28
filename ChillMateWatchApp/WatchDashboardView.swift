import SwiftUI
import WatchKit

struct WatchDashboardView: View {
    @State private var hydrationLogged = false
    @State private var checkInActive = true
    @State private var breathingActive = false
    @State private var timerStartedAt = Date.now
    @State private var timerDuration: TimeInterval = 90 * 60
    @State private var hapticTick = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    WatchStatusCard(
                        title: "Discreet check-in",
                        subtitle: checkInActive ? "Haptic nudges are on" : "Paused",
                        symbol: checkInActive ? "hand.tap.fill" : "hand.raised.fill"
                    ) {
                        checkInActive.toggle()
                        WKInterfaceDevice.current().play(.click)
                    }

                    WatchTimerCard(startedAt: timerStartedAt, duration: timerDuration) {
                        timerStartedAt = .now
                        timerDuration = 90 * 60
                        WKInterfaceDevice.current().play(.start)
                    }

                    WatchStatusCard(
                        title: "Hydration",
                        subtitle: hydrationLogged ? "Water logged" : "Tap after water",
                        symbol: hydrationLogged ? "checkmark.circle.fill" : "drop.fill"
                    ) {
                        hydrationLogged.toggle()
                        WKInterfaceDevice.current().play(hydrationLogged ? .success : .click)
                    }

                    BreathingExerciseCard(isActive: $breathingActive, hapticTick: $hapticTick)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Body signals", systemImage: "heart.text.square.fill")
                            .font(.headline)
                        Text("Heart-rate, stress, and temperature warnings are ready for the iPhone Health permissions and future sensor rules.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .watchCard()
                }
                .padding(.horizontal, 6)
            }
            .navigationTitle("ChillMate")
            .task(id: breathingActive) {
                guard breathingActive else {
                    return
                }

                while breathingActive {
                    hapticTick += 1
                    WKInterfaceDevice.current().play(.click)
                    try? await Task.sleep(for: .seconds(4))
                }
            }
        }
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
                    Label("Timer", systemImage: "timer")
                        .font(.headline)
                    Spacer()
                    Text(remaining.formattedRemaining)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Gauge(value: progress) {
                    Text("Effect window")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(progress > 0.7 ? .orange : .mint)

                Button("Restart 90 min", action: restart)
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
    @Binding var hapticTick: Int

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
                    .fill(.mint.opacity(0.18))
                    .frame(width: isActive ? 58 : 38, height: isActive ? 58 : 38)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: isActive)

                Text(isActive ? "Breathe" : "Ready")
                    .font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
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
