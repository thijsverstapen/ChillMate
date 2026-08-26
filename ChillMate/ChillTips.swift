import SwiftUI
import TipKit

/// In-context tips. The alternative is teaching everything during setup, which
/// makes setup longer and lands the explanation days before it is useful.
enum ChillTips {
    /// Called once at launch. A failure here is not worth interrupting anyone
    /// over: the app behaves identically without tips.
    static func configure() {
        try? Tips.configure()
    }
}

/// Shown on the risk checker. The parameterised intent behind this is new in
/// 4.3.0 and invisible until someone knows to ask for it.
struct SiriCombinationTip: Tip {
    var title: Text { Text("Ask without opening the app") }
    var message: Text? { Text("Say “Check a mix with ChillMate” and Siri reads the verdict straight back to you.") }
    var image: Image? { Image(systemName: "mic.fill") }
    var options: [any TipOption] { [Tips.MaxDisplayCount(3)] }
}

/// Shown on panic support, which is exactly where someone realises they would
/// rather not have had to unlock the phone first.
struct ControlCentreTip: Tip {
    var title: Text { Text("Reach this without unlocking") }
    var message: Text? { Text("Add ChillMate help to Control Centre. Breathing, grounding, and emergency contacts become one swipe from the Lock Screen.") }
    var image: Image? { Image(systemName: "switch.2") }
    var options: [any TipOption] { [Tips.MaxDisplayCount(3)] }
}

/// Shown on the account data page, next to the retention window itself.
struct AutomaticRetentionTip: Tip {
    var title: Text { Text("Let ChillMate tidy up") }
    var message: Text? { Text("Pick how long to keep logs, turn on automatic deletion, and it applies itself once a day.") }
    var image: Image? { Image(systemName: "calendar.badge.minus") }
    var options: [any TipOption] { [Tips.MaxDisplayCount(2)] }
}
