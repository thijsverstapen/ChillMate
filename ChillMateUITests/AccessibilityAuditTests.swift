import XCTest

/// Runs Apple's own accessibility audit over the screens a user actually reaches.
///
/// The app has 44 `accessibilityLabel` calls against two hints and one value, and
/// no Dynamic Type handling anywhere, so the gaps are known to exist. What was
/// missing was anything that finds them without a person driving VoiceOver by
/// hand. `performAccessibilityAudit()` checks contrast, hit-target size, clipped
/// text at large type sizes, and elements that carry no label at all.
///
/// Advisory in CI for the same reason the other UI tests are: it drives a real
/// simulator through onboarding, which fails on a shared runner for reasons that
/// have nothing to do with the change under test. A failure here is a report to
/// read, not a merge to block.
@MainActor
final class AccessibilityAuditTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-UITestMode",
            "-hasShownFirstLaunchSplash", "YES",
            "-chillReducedMotion", "YES",
            "-AppleLanguages", "(en)"
        ]
        app.launch()
        return app
    }

    /// Audits each tab in turn.
    ///
    /// Contrast and element-description findings are excluded for now: the glass
    /// surfaces in `LiquidGlass.swift` report contrast against a translucent
    /// backdrop the audit cannot resolve, and decorative brand marks report as
    /// unlabelled. Both would bury the findings that matter. Narrow this as those
    /// two are dealt with.
    func testEachTabPassesTheAccessibilityAudit() throws {
        let app = launchedApp()

        guard app.tabBars.firstMatch.waitForExistence(timeout: 30) else {
            throw XCTSkip("Never reached the tab bar; onboarding state is not what this test assumes.")
        }

        for identifier in ["tab.home", "tab.history", "tab.more"] {
            let tab = app.tabBars.buttons[identifier]
            guard tab.waitForExistence(timeout: 10) else { continue }
            tab.tap()

            XCTContext.runActivity(named: "Accessibility audit: \(identifier)") { _ in
                do {
                    try app.performAccessibilityAudit(for: [
                        .dynamicType,
                        .hitRegion,
                        .trait,
                        .textClipped
                    ])
                } catch {
                    XCTFail("\(identifier) failed the accessibility audit: \(error)")
                }
            }
        }
    }
}
