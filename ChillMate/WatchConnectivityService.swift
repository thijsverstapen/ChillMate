import Foundation
import OSLog
import WatchConnectivity

extension Logger {
    /// Shared logger for phone↔watch connectivity.
    static let watch = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.codex.ChillMate",
        category: "watch"
    )
}

@MainActor
final class WatchConnectivityService: NSObject {
    static let shared = WatchConnectivityService()

    /// Single latest-wins application context. Every `send*` merges into this
    /// and pushes the whole dictionary, so senders never clobber each other
    /// (updateApplicationContext keeps only the most recent dict per direction).
    private var context: [String: Any] = [:]

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        guard WCSession.default.activationState == .notActivated else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Outbound state

    private func push(_ updates: [String: Any]) {
        context.merge(updates) { _, new in new }
        guard WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(updates, replyHandler: nil, errorHandler: { error in
                Logger.watch.error("Watch sendMessage failed: \(error.localizedDescription, privacy: .public)")
            })
        }

        // Errors were swallowed by `try?` and an empty errorHandler. Since `context`
        // only ever merges and never shrinks, it can grow past
        // updateApplicationContext's payload limit — at which point the watch
        // silently stops receiving updates, including the emergency number.
        do {
            try WCSession.default.updateApplicationContext(context)
        } catch {
            Logger.watch.error("Watch context update failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func sendActiveTimers(_ timers: [DrugDoseTimerRecord]) {
        let now = Date.now
        let payload = timers.filter { $0.endsAt > now }.map { timer in
            [
                "id": timer.id.uuidString,
                "substance": timer.substanceName,
                "startedAt": timer.startedAt.timeIntervalSince1970,
                "endsAt": timer.endsAt.timeIntervalSince1970,
                "durationHours": timer.durationHours
            ] as [String: Any]
        }
        push(["timers": payload])
    }

    func sendSettings() {
        let d = UserDefaults.standard
        // The app defaults these toggles to `true`; `object(forKey:) as? Bool`
        // preserves that until the user changes them (plain `bool(forKey:)`
        // would report false for an unset key).
        func flag(_ key: String) -> Bool { d.object(forKey: key) as? Bool ?? true }
        push([
            "watchHydrationReminders": flag("watchHydrationReminders"),
            "watchBreathingHaptics": flag("watchBreathingHaptics"),
            "watchDiscreetCheckIns": flag("watchDiscreetCheckIns"),
            "watchVisibleTimers": flag("watchVisibleTimers"),
            "watchHeartRateWarnings": flag("watchHeartRateWarnings")
        ])
    }

    func sendMetrics(recoveryStreakDays: Int, dailyScore: Int, dailyScoreActive: Bool) {
        push([
            "recoveryStreakDays": recoveryStreakDays,
            "dailyScore": dailyScore,
            "dailyScoreActive": dailyScoreActive
        ])
    }

    func sendTrustedContactAndEmergency() {
        let d = UserDefaults.standard
        let name = d.string(forKey: DefaultsKey.trustedContactName) ?? ""
        let phone = d.string(forKey: DefaultsKey.trustedContactPhone) ?? ""
        // Resolved through EmergencyContactInfo, not re-derived here. The previous
        // inline copy only special-cased the United Kingdom, so the watch relayed
        // 112 to users in the United States and Australia — a number that does not
        // reach emergency services there — on the device most likely to be in reach
        // during an actual emergency.
        let emergency = EmergencyContactInfo.resolvedNumber(in: d)
        push([
            "trustedContactName": name,
            "trustedContactPhone": phone,
            "emergencyNumber": emergency
        ])
    }

    func sendLatestHeartRate(_ bpm: Double?) {
        push(["hasBPM": bpm != nil, "latestBPM": bpm ?? 0])
    }

    /// Push everything the watch needs that lives outside SwiftData. Called on
    /// activation and whenever the app becomes active.
    func syncStandaloneState() {
        sendSettings()
        sendTrustedContactAndEmergency()
    }

    // MARK: - Inbound events

    func logHydrationFromWatch() {
        NotificationCenter.default.post(name: .watchDidLogHydration, object: nil)
    }

    func requestQuickSkipFromWatch() {
        NotificationCenter.default.post(name: .watchDidRequestQuickSkip, object: nil)
    }

    private func handleInbound(_ payload: [String: Any]) {
        if payload["hydrationLogged"] as? Bool == true { logHydrationFromWatch() }
        if payload["quickSkipRequested"] as? Bool == true { requestQuickSkipFromWatch() }
        if payload["sosRequested"] as? Bool == true {
            NotificationCenter.default.post(name: .watchDidRequestSOS, object: nil)
        }
        if let value = payload["setDiscreetCheckIns"] as? Bool {
            UserDefaults.standard.set(value, forKey: "watchDiscreetCheckIns")
            sendSettings() // echo the change back so both sides agree
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            WatchConnectivityService.shared.syncStandaloneState()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let box = WCInboundBox(dict: message)
        Task { @MainActor in WatchConnectivityService.shared.handleInbound(box.dict) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let box = WCInboundBox(dict: applicationContext)
        Task { @MainActor in WatchConnectivityService.shared.handleInbound(box.dict) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let box = WCInboundBox(dict: userInfo)
        Task { @MainActor in WatchConnectivityService.shared.handleInbound(box.dict) }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        guard WCSession.default.isPaired else { return }
        WCSession.default.activate()
    }
}

private struct WCInboundBox: @unchecked Sendable {
    let dict: [String: Any]
}

extension Notification.Name {
    static let watchDidLogHydration = Notification.Name("ChillMate.watchDidLogHydration")
    static let chillMateRefreshTimers = Notification.Name("ChillMate.refreshTimers")
    static let watchDidRequestQuickSkip = Notification.Name("ChillMate.watchDidRequestQuickSkip")
    static let watchDidRequestSOS = Notification.Name("ChillMate.watchDidRequestSOS")
}
