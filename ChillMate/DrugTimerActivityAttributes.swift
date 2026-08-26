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
    }

    let timerID: UUID
    let substanceName: String
}
