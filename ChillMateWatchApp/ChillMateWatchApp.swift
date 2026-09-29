import SwiftUI
import WatchConnectivity

@main
struct ChillMateWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
                .onAppear {
                    WatchConnectivityReceiver.shared.activate()
                }
        }
        // The phone wakes the app in the background when something the face
        // shows has changed. The system keeps the app awake while this runs, so
        // it stays until what was delivered has reached the receiver and the
        // complications have been told. Bounded, so a transfer that never
        // finishes cannot hold the app awake.
        .backgroundTask(.watchConnectivity) {
            await MainActor.run { WatchConnectivityReceiver.shared.activate() }
            var waited = 0
            while WCSession.default.hasContentPending, waited < 50 {
                try? await Task.sleep(for: .milliseconds(200))
                waited += 1
            }
            // Lets the delivery work the delegate queued on the main actor run
            // before the system suspends the app again.
            await MainActor.run {}
        }
    }
}
