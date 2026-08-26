import SwiftUI
import WatchConnectivity
import WatchKit
import WidgetKit

// MARK: - Root dashboard

struct WatchDashboardView: View {
    @StateObject private var connectivity = WatchConnectivityReceiver.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    WatchStreakHeader(
                        streakDays: connectivity.recoveryStreakDays,
                        score: connectivity.dailyScore,
                        scoreActive: connectivity.dailyScoreActive
                    )

                    if connectivity.visibleTimersEnabled {
                        if connectivity.activeTimers.isEmpty {
                            WatchStatusCard(
                                title: String(localized: "No active timer"),
                                subtitle: String(localized: "Start a dose timer on iPhone"),
                                symbol: "timer"
                            ) {}
                        } else {
                            ForEach(connectivity.activeTimers) { timer in
                                WatchActiveTimerCard(timer: timer)
                            }
                        }
                    }

                    WatchHydrationCard(
                        count: connectivity.hydrationCount,
                        add: {
                            connectivity.logHydration()
                            WKInterfaceDevice.current().play(.success)
                        }
                    )

                    WatchStatusCard(
                        title: String(localized: "Discreet check-ins"),
                        subtitle: connectivity.discreetCheckInsEnabled ? String(localized: "Gentle nudges on") : String(localized: "Paused"),
                        symbol: connectivity.discreetCheckInsEnabled ? "hand.tap.fill" : "hand.raised.fill"
                    ) {
                        connectivity.toggleDiscreetCheckIns()
                        WKInterfaceDevice.current().play(.click)
                    }

                    if connectivity.heartRateWarningsEnabled, let bpm = connectivity.latestBPM {
                        WatchHeartRateCard(bpm: bpm)
                    }

                    NavigationLink {
                        BreathingScreen(hapticsEnabled: connectivity.breathingHapticsEnabled)
                    } label: {
                        WatchLinkRow(title: String(localized: "Breathing"), subtitle: String(localized: "Calm in 4-4"), symbol: "wind", tint: .mint)
                    }
                    .buttonStyle(.plain)

                    WatchStatusCard(
                        title: String(localized: "Nothing happened"),
                        subtitle: connectivity.quickSkipSentToday ? String(localized: "Logged on iPhone") : String(localized: "Log a clear night"),
                        symbol: connectivity.quickSkipSentToday ? "checkmark.circle.fill" : "moon.zzz.fill"
                    ) {
                        guard !connectivity.quickSkipSentToday else { return }
                        connectivity.logQuickSkip()
                        WKInterfaceDevice.current().play(.success)
                    }

                    NavigationLink {
                        SafetyScreen(connectivity: connectivity)
                    } label: {
                        WatchLinkRow(title: String(localized: "Safety"), subtitle: String(localized: "Reach help fast"), symbol: "shield.lefthalf.filled", tint: .red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }
            .navigationTitle("ChillMate")
        }
        .tint(.mint)
    }
}

// MARK: - Header

private struct WatchStreakHeader: View {
    let streakDays: Int
    let score: Int
    let scoreActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(streakDays)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.mint)
                Text(streakDays == 1 ? String(localized: "day clear") : String(localized: "days clear"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if scoreActive {
                Gauge(value: Double(min(max(score, 0), 100)), in: 0...100) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(score)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(scoreTint)
                .scaleEffect(0.9)
            }
        }
        .padding(12)
        .watchCard()
    }

    private var scoreTint: Color {
        switch score {
        case ..<40: return .orange
        case 40..<70: return .yellow
        default: return .mint
        }
    }
}

// MARK: - Timer card

private struct WatchActiveTimerCard: View {
    let timer: WatchTimerInfo
    @State private var didWarn = false

    /// Two timelines with different cadences instead of one at 1 Hz.
    ///
    /// The whole card (label, Gauge, and the card background) used to be rebuilt
    /// every second for the entire length of a dose window, which on a watch is a
    /// real battery cost. The countdown text genuinely needs 1 Hz because it shows
    /// seconds; the gauge does not. Across a multi-hour window one second moves the
    /// bar by well under a hundredth of a percent, so it ticks every 15s.
    ///
    /// Neither timeline is gated behind Reduce Motion. That preference asks for
    /// less motion, not for frozen content, and these views redraw a countdown and
    /// a fill level rather than moving anything across the screen. Stalling a dose
    /// window countdown would be a safety regression dressed up as an
    /// accommodation.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(timer.substanceName, systemImage: "timer")
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 4)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, timer.endsAt.timeIntervalSince(context.date))
                    Text(remaining <= 0 ? String(localized: "Window ended") : remaining.formattedRemaining)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(remaining <= 0 ? .orange : .secondary)
                }
            }

            TimelineView(.periodic(from: .now, by: 15)) { context in
                let total = max(timer.durationSeconds, 1)
                let elapsed = max(0, context.date.timeIntervalSince(timer.startedAt))
                let remaining = max(0, timer.endsAt.timeIntervalSince(context.date))
                let progress = min(1, elapsed / total)
                let ended = remaining <= 0

                VStack(alignment: .leading, spacing: 8) {
                    Gauge(value: progress) {
                        Text("Effect window")
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(ended ? .orange : (progress > 0.75 ? .yellow : .mint))

                    if ended {
                        Text("Take it slow before any redose.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .watchCard()
        // Fire one haptic when the effect window ends (foreground); the phone
        // covers the background case with a scheduled notification.
        .task(id: timer.id) {
            didWarn = false
            let wait = timer.endsAt.timeIntervalSinceNow
            guard wait > 0 else { return }
            try? await Task.sleep(for: .seconds(wait))
            guard !didWarn else { return }
            didWarn = true
            WKInterfaceDevice.current().play(.notification)
        }
    }
}

// MARK: - Hydration

private struct WatchHydrationCard: View {
    let count: Int
    let add: () -> Void

    var body: some View {
        Button(action: add) {
            HStack(spacing: 10) {
                Image(systemName: count > 0 ? "drop.fill" : "drop")
                    .font(.title3)
                    .foregroundStyle(.mint)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hydration")
                        .font(.headline)
                    Text(count == 0 ? String(localized: "Tap after water") : String(localized: "\(count) logged today"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.mint)
            }
            .padding(12)
            .watchCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Heart rate

private struct WatchHeartRateCard: View {
    let bpm: Double

    private var elevated: Bool { bpm > 110 }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundStyle(elevated ? .red : .mint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Heart rate")
                    .font(.headline)
                Text(elevated ? String(localized: "\(Int(bpm)) bpm, slow down") : String(localized: "\(Int(bpm)) bpm"))
                    .font(.caption2)
                    .foregroundStyle(elevated ? .red : .secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .watchCard()
    }
}

// MARK: - Generic rows

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

private struct WatchLinkRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.forward")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .watchCard()
    }
}

// MARK: - Breathing screen

/// The only continuous animation in the watch app, and so the only place where
/// Reduce Motion has to change the design instead of just switching an animation
/// off. A breathing pacer with the motion removed and nothing put in its place is
/// a dead circle: the user loses the one signal that tells them how long to keep
/// inhaling. So the rhythm is carried by state that is not motion, the phase label
/// and a per-second countdown driven by the same clock in every mode, and the
/// circle simply holds its resting size when motion is suppressed.
///
/// The preference is read straight from SwiftUI's own environment rather than
/// through the phone app's combined `chillReduceMotion`: MotionPreference.swift is
/// compiled into the iOS target only, and the in-app toggle it folds in is not
/// mirrored over WatchConnectivity. The system switch is per device anyway, so the
/// user who set it on the watch gets exactly what they asked for here.
private struct BreathingScreen: View {
    let hapticsEnabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var active = false
    @State private var scale: CGFloat = 1.0
    @State private var phaseLabel = String(localized: "Ready")
    @State private var secondsLeft = 0

    /// Seconds per phase. The entry row advertises this screen as "Calm in 4-4",
    /// so breathe in and breathe out share one value.
    private static let phaseSeconds = 4

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.mint.opacity(0.10))
                    .frame(width: 150, height: 150)
                Circle()
                    .fill(.mint.opacity(0.22))
                    .frame(width: 96 * scale, height: 96 * scale)
                VStack(spacing: 2) {
                    Text(phaseLabel)
                        .font(.headline)
                    // Kept in the layout while idle so starting a session does not
                    // shove the phase label upward. Formatted rather than
                    // interpolated into the Text so the count stays out of the
                    // string catalog and still uses localized digits.
                    Text(secondsLeft, format: .number)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .opacity(active ? 1 : 0)
                        .accessibilityHidden(!active)
                }
            }
            .frame(maxWidth: .infinity)
            // The gate is repeated here, not just at the mutation, because a nil
            // animation also blocks any transaction inherited from an ancestor.
            // Nothing can animate the circle behind Reduce Motion's back.
            .animation(reduceMotion ? nil : .easeInOut(duration: Double(Self.phaseSeconds)), value: scale)

            Button(active ? String(localized: "Stop") : String(localized: "Start")) {
                active.toggle()
                if hapticsEnabled {
                    WKInterfaceDevice.current().play(active ? .start : .stop)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.mint)
        }
        .padding()
        .navigationTitle("Breathing")
        .task(id: active) {
            guard active else {
                scale = 1.0
                phaseLabel = String(localized: "Ready")
                secondsLeft = 0
                return
            }
            await runSession()
        }
    }

    /// Repeats the 4-4 cycle until the user stops or the task is cancelled.
    ///
    /// Cancellation is checked explicitly instead of being inferred from `active`.
    /// Navigating away mid session cancels the task without flipping `active`, and
    /// sleeping inside a cancelled task returns immediately, so a loop keyed on
    /// `active` alone would spin at full speed and keep firing haptics.
    @MainActor
    private func runSession() async {
        while active && !Task.isCancelled {
            await runPhase(label: String(localized: "Breathe in"), expanded: true)
            await runPhase(label: String(localized: "Breathe out"), expanded: false)
        }
    }

    /// Runs one phase, then counts it down a second at a time.
    ///
    /// The countdown is what makes the pacer survive Reduce Motion, so it runs in
    /// both modes: suppressing motion should cost the animation, not the exercise.
    @MainActor
    private func runPhase(label: String, expanded: Bool) async {
        guard active, !Task.isCancelled else { return }

        phaseLabel = label
        secondsLeft = Self.phaseSeconds

        if reduceMotion {
            // Hold the resting size. Assigning it, rather than leaving `scale`
            // alone, also recovers the layout if Reduce Motion is switched on
            // partway through a session while the circle happens to be expanded.
            scale = 1.0
        } else {
            withAnimation(.easeInOut(duration: Double(Self.phaseSeconds))) {
                scale = expanded ? 1.5 : 1.0
            }
        }

        if hapticsEnabled { WKInterfaceDevice.current().play(.click) }

        for _ in 0..<Self.phaseSeconds {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            guard active else { return }
            secondsLeft -= 1
        }
    }
}

// MARK: - Safety screen

private struct SafetyScreen: View {
    @ObservedObject var connectivity: WatchConnectivityReceiver
    @State private var pinged = false
    @State private var homeSafe = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("If something feels wrong, get help. You are not in trouble.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                if !connectivity.trustedContactPhone.isEmpty {
                    SafetyActionButton(
                        title: connectivity.trustedContactName.isEmpty
                            ? String(localized: "Call trusted contact")
                            : String(localized: "Call \(connectivity.trustedContactName)"),
                        symbol: "phone.fill",
                        tint: .mint
                    ) {
                        connectivity.call(connectivity.trustedContactPhone)
                    }
                }

                SafetyActionButton(
                    title: String(localized: "Emergency \(connectivity.emergencyNumber)"),
                    symbol: "cross.case.fill",
                    tint: .red
                ) {
                    connectivity.call(connectivity.emergencyNumber)
                }

                SafetyActionButton(
                    title: homeSafe ? String(localized: "Marked home safe") : String(localized: "I'm home safe"),
                    symbol: homeSafe ? "checkmark.circle.fill" : "house.fill",
                    tint: .green
                ) {
                    guard !homeSafe else { return }
                    connectivity.sendHomeSafe()
                    homeSafe = true
                    WKInterfaceDevice.current().play(.success)
                }

                SafetyActionButton(
                    title: pinged ? String(localized: "Phone alerted") : String(localized: "Ping my phone"),
                    symbol: pinged ? "checkmark.circle.fill" : "iphone.radiowaves.left.and.right",
                    tint: .orange
                ) {
                    guard !pinged else { return }
                    connectivity.sendSOS()
                    pinged = true
                    WKInterfaceDevice.current().play(.notification)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
        .navigationTitle("Safety")
    }
}

private struct SafetyActionButton: View {
    let title: String
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.title3)
                    .frame(width: 26)
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(tint)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .watchCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Styling helpers

private extension View {
    func watchCard() -> some View {
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private extension TimeInterval {
    var formattedRemaining: String {
        let total = Int(self)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return "\(hours):\(minutes.twoDigitPadded):\(seconds.twoDigitPadded)"
        }
        return "\(minutes):\(seconds.twoDigitPadded)"
    }
}

private extension Int {
    var twoDigitPadded: String { self < 10 ? "0\(self)" : "\(self)" }
}

// MARK: - Model

struct WatchTimerInfo: Identifiable, Equatable {
    let id: UUID
    let substanceName: String
    let startedAt: Date
    let durationSeconds: TimeInterval

    var endsAt: Date { startedAt.addingTimeInterval(durationSeconds) }
}

// MARK: - Connectivity (watch side)

@MainActor
final class WatchConnectivityReceiver: NSObject, ObservableObject {
    static let shared = WatchConnectivityReceiver()

    // Synced state from the phone
    @Published var activeTimers: [WatchTimerInfo] = []
    @Published var recoveryStreakDays = 0
    @Published var dailyScore = 0
    @Published var dailyScoreActive = false
    @Published var latestBPM: Double? = nil
    @Published var trustedContactName = ""
    @Published var trustedContactPhone = ""
    /// Last number relayed by the phone. Persisted (see `emergencyNumberKey`) so a
    /// cold watch launch out of range of the phone still dials the user's real
    /// emergency number instead of falling back to the 112 default, which does not
    /// reach emergency services in the US or Australia.
    @Published var emergencyNumber = "112"

    // Settings mirrored from the phone
    @Published var hydrationRemindersEnabled = true
    @Published var heartRateWarningsEnabled = true
    @Published var breathingHapticsEnabled = true
    @Published var discreetCheckInsEnabled = true
    @Published var visibleTimersEnabled = true

    // Local, persisted state
    @Published var hydrationCount = 0
    @Published var quickSkipSentToday = false

    private let defaults = UserDefaults.standard
    private let hydrationCountKey = WidgetSharedKey.watchHydrationCount
    private let hydrationDayKey = WidgetSharedKey.watchHydrationDay
    private let quickSkipDayKey = WidgetSharedKey.watchQuickSkipDay
    private let emergencyNumberKey = WidgetSharedKey.watchEmergencyNumber

    private override init() {
        super.init()
        rolloverIfNeeded()
        hydrationCount = defaults.integer(forKey: hydrationCountKey)
        quickSkipSentToday = defaults.integer(forKey: quickSkipDayKey) == Self.todayKey
        if let stored = defaults.string(forKey: emergencyNumberKey), !stored.isEmpty {
            emergencyNumber = stored
        }
        activate()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: Local day rollover

    private static var todayKey: Int {
        Int(Calendar.current.startOfDay(for: .now).timeIntervalSinceReferenceDate / 86_400)
    }

    private func rolloverIfNeeded() {
        let today = Self.todayKey
        if defaults.integer(forKey: hydrationDayKey) != today {
            defaults.set(today, forKey: hydrationDayKey)
            defaults.set(0, forKey: hydrationCountKey)
        }
    }

    // MARK: Outbound events (reliable one-shot delivery)

    func logHydration() {
        rolloverIfNeeded()
        hydrationCount += 1
        defaults.set(hydrationCount, forKey: hydrationCountKey)
        sendEvent(["hydrationLogged": true])
    }

    func logQuickSkip() {
        guard !quickSkipSentToday else { return }
        quickSkipSentToday = true
        defaults.set(Self.todayKey, forKey: quickSkipDayKey)
        sendEvent(["quickSkipRequested": true])
    }

    func toggleDiscreetCheckIns() {
        discreetCheckInsEnabled.toggle()
        sendEvent(["setDiscreetCheckIns": discreetCheckInsEnabled])
    }

    func sendSOS() {
        sendEvent(["sosRequested": true])
    }

    /// "I got home." The phone stops the tonight-only safety check-ins, because
    /// the question they were asking has been answered.
    func sendHomeSafe() {
        sendEvent(["homeSafeReported": true])
    }

    func call(_ number: String) {
        let digits = number.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty, let url = URL(string: "tel:\(digits)") else { return }
        WKApplication.shared().openSystemURL(url)
    }

    private func sendEvent(_ payload: [String: Any]) {
        // transferUserInfo / sendMessage require an activated session. In the rare
        // cold-start race where we're not activated yet, kick activation and drop
        // this one event rather than risk a WCSession exception. State re-syncs on
        // the next interaction.
        guard WCSession.default.activationState == .activated else {
            WCSession.default.activate()
            return
        }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { [payload] _ in
                // Delivery failed while "reachable"; fall back to the guaranteed queue.
                WCSession.default.transferUserInfo(payload)
            }
        } else {
            WCSession.default.transferUserInfo(payload)
        }
    }

    // MARK: Inbound state

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
            .filter { $0.endsAt > .now }
            .sorted { $0.endsAt < $1.endsAt }
        }

        if let value = context["recoveryStreakDays"] as? Int { recoveryStreakDays = value }
        if let value = context["dailyScore"] as? Int { dailyScore = value }
        if let value = context["dailyScoreActive"] as? Bool { dailyScoreActive = value }
        if let value = context["trustedContactName"] as? String { trustedContactName = value }
        if let value = context["trustedContactPhone"] as? String { trustedContactPhone = value }
        if let value = context["emergencyNumber"] as? String, !value.isEmpty {
            emergencyNumber = value
            defaults.set(value, forKey: emergencyNumberKey)
        }

        if let value = context["hasBPM"] as? Bool {
            latestBPM = value ? (context["latestBPM"] as? Double) : nil
        }

        if let value = context["watchHydrationReminders"] as? Bool { hydrationRemindersEnabled = value }
        if let value = context["watchHeartRateWarnings"] as? Bool { heartRateWarningsEnabled = value }
        if let value = context["watchBreathingHaptics"] as? Bool { breathingHapticsEnabled = value }
        if let value = context["watchDiscreetCheckIns"] as? Bool { discreetCheckInsEnabled = value }
        if let value = context["watchVisibleTimers"] as? Bool { visibleTimersEnabled = value }

        publishWidgetSnapshot()
    }

    /// Mirrors the synced state into the shared App Group so the watch-face
    /// complications (ChillMateWatchAppWidget) can render it. Key strings are
    /// duplicated in the widget's WidgetStore by design. Keep them in sync.
    private func publishWidgetSnapshot() {
        guard let shared = UserDefaults(suiteName: WidgetSharedKey.suiteName) else { return }
        shared.set(recoveryStreakDays, forKey: WidgetSharedKey.watchStreakDays)
        shared.set(dailyScore, forKey: WidgetSharedKey.watchScore)
        shared.set(dailyScoreActive, forKey: WidgetSharedKey.watchScoreActive)

        let active = activeTimers.first
        shared.set(active?.substanceName ?? "", forKey: WidgetSharedKey.watchTimerSubstance)
        shared.set(active?.startedAt.timeIntervalSince1970 ?? 0, forKey: WidgetSharedKey.watchTimerStart)
        shared.set(active.map { $0.endsAt.timeIntervalSince1970 } ?? 0, forKey: WidgetSharedKey.watchTimerEnd)

        WidgetCenter.shared.reloadAllTimelines()
    }
}

private struct WCContextBox: @unchecked Sendable {
    let dict: [String: Any]
}

extension WatchConnectivityReceiver: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        guard activationState == .activated else { return }
        let box = WCContextBox(dict: session.receivedApplicationContext)
        Task { @MainActor in self.applyContext(box.dict) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let box = WCContextBox(dict: message)
        Task { @MainActor in self.applyContext(box.dict) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let box = WCContextBox(dict: applicationContext)
        Task { @MainActor in self.applyContext(box.dict) }
    }
}
