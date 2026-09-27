import ActivityKit
import Foundation

struct DrugTimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let substanceName: String
        let endsAt: Date
        let redoseNudgeActive: Bool
        /// Optional so an activity started by an older build still decodes across
        /// an app update. Without it the view falls back to a plain countdown.
        var startedAt: Date?
        /// Say "Timer" rather than the substance. In the state rather than the
        /// attributes because attributes are fixed for the activity's life, and
        /// switching discreet mode has to reach a timer that is already running.
        /// Optional for the same reason as `startedAt`: an activity started by an
        /// older build decodes as not discreet.
        var discreet: Bool?
    }

    let timerID: UUID
    let substanceName: String
}
