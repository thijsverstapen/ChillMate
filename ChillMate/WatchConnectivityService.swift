import Foundation
import WatchConnectivity

@MainActor
final class WatchConnectivityService: NSObject {
    static let shared = WatchConnectivityService()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendActiveTimers(_ timers: [DrugDoseTimerRecord]) {
        guard WCSession.default.isReachable || WCSession.default.activationState == .activated else { return }

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

        let message: [String: Any] = ["timers": payload]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(message)
        }
    }

    func sendSettings() {
        guard WCSession.default.activationState == .activated else { return }

        let settings: [String: Any] = [
            "watchHydrationReminders": UserDefaults.standard.bool(forKey: "watchHydrationReminders"),
            "watchBreathingHaptics": UserDefaults.standard.bool(forKey: "watchBreathingHaptics"),
            "watchDiscreetCheckIns": UserDefaults.standard.bool(forKey: "watchDiscreetCheckIns"),
            "watchVisibleTimers": UserDefaults.standard.bool(forKey: "watchVisibleTimers"),
            "watchHeartRateWarnings": UserDefaults.standard.bool(forKey: "watchHeartRateWarnings")
        ]

        try? WCSession.default.updateApplicationContext(settings)
    }

    func logHydrationFromWatch() {
        NotificationCenter.default.post(name: .watchDidLogHydration, object: nil)
    }

    func requestQuickSkipFromWatch() {
        NotificationCenter.default.post(name: .watchDidRequestQuickSkip, object: nil)
    }
}

private struct WCPhoneContextBox: @unchecked Sendable {
    let dict: [String: Any]
}

extension WatchConnectivityService: @preconcurrency WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            WatchConnectivityService.shared.sendSettings()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let box = WCPhoneContextBox(dict: message)
        Task { @MainActor in
            if box.dict["hydrationLogged"] as? Bool == true {
                WatchConnectivityService.shared.logHydrationFromWatch()
            }
            if box.dict["quickSkipRequested"] as? Bool == true {
                WatchConnectivityService.shared.requestQuickSkipFromWatch()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let box = WCPhoneContextBox(dict: applicationContext)
        Task { @MainActor in
            if box.dict["hydrationLogged"] as? Bool == true {
                WatchConnectivityService.shared.logHydrationFromWatch()
            }
            if box.dict["quickSkipRequested"] as? Bool == true {
                WatchConnectivityService.shared.requestQuickSkipFromWatch()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}

extension Notification.Name {
    static let watchDidLogHydration = Notification.Name("ChillMate.watchDidLogHydration")
    static let chillMateRefreshTimers = Notification.Name("ChillMate.refreshTimers")
    static let watchDidRequestQuickSkip = Notification.Name("ChillMate.watchDidRequestQuickSkip")
}
