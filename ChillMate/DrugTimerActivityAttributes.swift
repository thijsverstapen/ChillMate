import ActivityKit
import Foundation

struct DrugTimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let substanceName: String
        let endsAt: Date
        let redoseNudgeActive: Bool
    }

    let timerID: UUID
    let substanceName: String
}
