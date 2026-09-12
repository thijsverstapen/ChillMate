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

/// The Shortcuts gallery's hard limits, as tests rather than as a build failure
/// three minutes into a compile.
@Suite("App Shortcuts gallery")
struct AppShortcutsGalleryTests {

    /// Apple refuses to build the target at eleven. The build does say so, but it
    /// says so from the App Intents metadata processor after everything else has
    /// compiled, and the message does not mention that the fix is to spend a slot
    /// rather than to write less code.
    @Test("The gallery fits inside Apple's limit of ten")
    func atMostTenShortcuts() {
        #expect(ChillMateShortcuts.appShortcuts.count <= 10)
    }

    /// There is no second test here for the *order*, which also matters — the
    /// first entry is what Spotlight and the gallery lead with, and that slot
    /// belongs to panic support. `AppShortcut` exposes neither its intent nor its
    /// phrases once it is in the array, so that one is enforced by reading the
    /// file and by the comment above the list saying so.
}
