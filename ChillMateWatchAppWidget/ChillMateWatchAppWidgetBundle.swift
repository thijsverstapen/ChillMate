import SwiftUI
import WidgetKit

@main
struct ChillMateWatchAppWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChillMateStreakWidget()
        ChillMateTimerWidget()
    }
}
