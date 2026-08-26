import Testing
@testable import ChillMate

/// The Control Center controls live in the Live Activity extension, which cannot
/// see `NotificationDestination`. They hand a destination over as a bare string
/// in the shared App Group, so the two ends can drift without any compiler
/// complaint: the control would open the app and land it nowhere.
struct ControlDestinationTests {
    @Test("The control's destination string matches the app's enum")
    func panicDestinationMatches() {
        #expect(WidgetSharedKey.destinationPanic == NotificationDestination.panic.rawValue)
    }

    @Test("The handoff key is in the shared suite, not the app's own defaults")
    func handoffKeyIsNamespaced() {
        #expect(WidgetSharedKey.suiteName == "group.com.codex.ChillMate")
        #expect(WidgetSharedKey.pendingDestination.isEmpty == false)
    }
}
