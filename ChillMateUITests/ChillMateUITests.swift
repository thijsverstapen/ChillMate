import XCTest

@MainActor
final class ChillMateUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launching

    /// A launched app, with the first-launch splash and the intro's motion out of
    /// the way.
    ///
    /// The preference flags are real preferences, passed through the argument
    /// domain, which `UserDefaults` reads ahead of anything on disk. That is the
    /// only lever a UI test has over app state from outside the process, and the
    /// app has to read the key for it to do anything.
    ///
    /// `-UITestMode` is not a preference and does not bypass onboarding. Its one
    /// effect is that `ChillMateModelContainer` builds a local store instead of a
    /// CloudKit-backed one. CI builds with `CODE_SIGNING_ALLOWED=NO`, so the app
    /// carries no iCloud entitlement, and asking for CloudKit mirroring without it
    /// traps on Core Data's internal queue and kills the process before any test
    /// can run.
    ///
    /// `chillReducedMotion` matters more than it looks: without it the intro runs
    /// a repeating shimmer and holds a half-second pause before handing over to
    /// the wizard, both of which a UI test can only wait out.
    ///
    /// The language is always stated. The app persists a language override across
    /// launches, so after the five-language test has run, a launch that named no
    /// language would come up in Spanish.
    ///
    /// Each test launches its own instance. `setUpWithError` used to launch one and
    /// the tests then launched more, leaving several instances running against each
    /// other.
    private func launchedApp(language: String = "en") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-UITestMode",
            "-hasShownFirstLaunchSplash", "YES",
            "-chillReducedMotion", "YES",
            "-AppleLanguages", "(\(language))"
        ]
        app.launch()
        return app
    }

    /// Makes sure the simulator holds a profile, walking first-run onboarding when
    /// it does not, and leaves the app terminated.
    ///
    /// Everything past onboarding is gated on a `UserProfile` existing, and nothing
    /// outside the app can insert one: it lives in the SwiftData store, not in
    /// defaults, so no launch argument reaches it. On a clean CI runner the app
    /// therefore sits on the onboarding intro, whose paged `TabView` has no
    /// `UITabBar` in it, and every test that waited for `app.tabBars` waited until
    /// it timed out.
    ///
    /// The profile is written to the app container, so one walk-through serves the
    /// whole run and every later launch, in any language, comes up on the tab bar.
    private func ensureProfileExists() throws {
        let app = launchedApp()
        defer { app.terminate() }

        // Whichever of the two arrives first says which state this simulator is in,
        // so a warm simulator costs one quick check rather than a full timeout.
        //
        // The signal is the Home tab BUTTON, not `app.tabBars.firstMatch`. The
        // onboarding intro is itself a paged TabView, and it publishes a tabBars
        // element too, so matching on firstMatch reported "already past
        // onboarding" while the app was still sitting on the welcome slide. The
        // helper then returned without creating a profile and every later query
        // for a real tab failed. `tab.home` exists only in MainTabView.
        let tabBar = app.tabBars.buttons["tab.home"]
        let intro = app.buttons["Skip introduction"]
        guard let appeared = firstToAppear([tabBar, intro], timeout: 40) else {
            XCTFail("The app reached neither the tab bar nor the onboarding intro within 40s.")
            return
        }
        if appeared === tabBar {
            return
        }

        try completeOnboarding(app)
        XCTAssertTrue(
            tabBar.waitForExistence(timeout: 30),
            "Onboarding was completed but the Home tab never appeared."
        )
    }

    /// Walks the onboarding intro and the four-step profile wizard.
    ///
    /// Driven by English labels, which is why `launchedApp` defaults to English and
    /// why the five-language test creates its profile before it starts switching
    /// language: the wizard carries no accessibility identifiers, so there is
    /// nothing locale-independent to aim at from the test side. Every step asserts,
    /// naming the control it wanted, so a label changing in the app shows up in CI
    /// as that control rather than as a tab bar that never appeared.
    private func completeOnboarding(_ app: XCUIApplication) throws {
        let skipIntro = app.buttons["Skip introduction"]
        XCTAssertTrue(skipIntro.waitForExistence(timeout: 20), "The onboarding intro never appeared.")
        skipIntro.tap()

        // Step 1 of 4. The name is the only required field; the wizard's default
        // date of birth is exactly 18 years ago, which clears the age gate.
        XCTAssertTrue(
            app.textFields.firstMatch.waitForExistence(timeout: 20),
            "The profile wizard's first step never appeared."
        )
        guard let name = firstHittable(app.textFields, scrollingIn: app) else {
            XCTFail("The name field on step 1 of the profile wizard never came into view.")
            return
        }
        name.tap()
        // The newline dismisses the keyboard, which would otherwise sit over the
        // wizard's footer buttons.
        name.typeText("CI Tester\n")

        // Three taps carry the wizard from step 1 to step 4. Steps 2 and 3 are
        // entirely optional, so there is nothing to fill in on the way, and the
        // footer's button only becomes "Create account" once step 4 is on screen.
        for departingStep in 1...3 {
            let advance = app.buttons["Continue"]
            XCTAssertTrue(advance.waitForExistence(timeout: 10), "No Continue button on step \(departingStep).")
            advance.tap()
        }

        // Step 4 of 4 holds the disclaimer, which has to be accepted before the
        // profile can be created.
        let agreement = app.switches["I have read and agree to this."]
        guard scrollIntoView(agreement, in: app) else {
            XCTFail("The 'I have read and agree to this.' toggle never came into view on step 4.")
            return
        }
        if agreement.value as? String != "1" {
            agreement.tap()
        }

        let create = app.buttons["Create account"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), "No Create account button on step 4.")
        create.tap()

        // Shown because CI grants none of the optional permissions. It is skipped
        // outright when they are all on, so its absence is not a failure.
        let confirm = app.buttons["Yes, continue"]
        if confirm.waitForExistence(timeout: 5) {
            confirm.tap()
        }
    }

    // MARK: - Element helpers

    /// Polls until one of `elements` exists, and returns it, or nil on timeout.
    ///
    /// `waitForExistence` can only wait on one element, so waiting on two states
    /// with it means paying the full timeout for whichever one is checked first.
    private func firstToAppear(_ elements: [XCUIElement], timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let found = elements.first(where: { $0.exists }) {
                return found
            }
            _ = elements[0].waitForExistence(timeout: 0.5)
        }
        return elements.first { $0.exists }
    }

    /// Scrolls the current screen until `element` is on screen and tappable.
    ///
    /// The setup wizard and Home are scroll views taller than the screen, and a tap
    /// on an element that exists but is off screen fails rather than scrolling to
    /// it. SwiftUI renders a `ScrollView`'s children eagerly, so the element exists
    /// in the hierarchy from the start and only `isHittable` distinguishes it.
    @discardableResult
    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication, swipes: Int = 8) -> Bool {
        guard element.waitForExistence(timeout: 10) else { return false }
        for _ in 0..<swipes {
            if element.isHittable { return true }
            app.swipeUp()
        }
        return element.isHittable
    }

    /// The first element of `query` that is on screen, scrolling to find one.
    ///
    /// A paged `TabView` keeps its neighbouring page in the hierarchy, so matching
    /// on existence alone can pick up a control from the step next door.
    private func firstHittable(
        _ query: XCUIElementQuery,
        scrollingIn app: XCUIApplication,
        swipes: Int = 8
    ) -> XCUIElement? {
        for _ in 0...swipes {
            if let hittable = query.allElementsBoundByIndex.first(where: { $0.isHittable }) {
                return hittable
            }
            app.swipeUp()
        }
        return query.allElementsBoundByIndex.first { $0.isHittable }
    }

    // MARK: - Smoke tests (crash canaries)

    /// The app must reach and hold the foreground, which catches launch-time
    /// crashes (container/schema failures, bad state restoration).
    ///
    /// Deliberately makes no claim about which screen it lands on: it is the one
    /// test that is just as meaningful on onboarding as on the tab bar.
    func testLaunchesToForeground() throws {
        let app = launchedApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))

        // Held for a few seconds by polling rather than `sleep(3)`, so this fails
        // the moment the app dies instead of at the end of a fixed wait.
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            XCTAssertEqual(app.state, .runningForeground, "App crashed shortly after launch")
            _ = app.wait(for: .runningForeground, timeout: 0.5)
        }
    }

    /// Launch once per supported language, which catches locale-specific crashes
    /// (bad format strings, missing catalog entries misused at runtime).
    ///
    /// The tab bar is the assertion rather than the process being alive, because a
    /// format string that disagrees with its key only crashes once the view holding
    /// it renders. Reaching the main UI means the dashboard, history and the More
    /// hub have all been built in that language.
    func testLaunchesInEveryLanguage() throws {
        try ensureProfileExists()

        for language in ["en", "nl", "de", "fr", "es"] {
            let app = launchedApp(language: language)
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20),
                          "App failed to launch in \(language)")
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20),
                          "Main tab bar never appeared in \(language)")
            XCTAssertEqual(app.state, .runningForeground, "App crashed after launch in \(language)")
            app.terminate()
        }
    }

    /// Every tab must be reachable and render something.
    ///
    /// Queries by accessibility identifier rather than by visible label. The old
    /// tests looked up `buttons["More"]`, which could only ever match in English,
    /// including inside the run whose whole point is the other four languages.
    func testEachTabOpens() throws {
        try ensureProfileExists()

        let app = launchedApp()
        // Waits on a real tab, not `tabBars.firstMatch`: the onboarding intro is a
        // paged TabView and publishes a tabBars element of its own, so firstMatch
        // is true in a state where none of these identifiers exist.
        XCTAssertTrue(app.tabBars.buttons["tab.home"].waitForExistence(timeout: 30))

        for identifier in ["tab.home", "tab.history", "tab.more"] {
            let tab = app.tabBars.buttons[identifier]
            XCTAssertTrue(tab.waitForExistence(timeout: 15), "Missing tab \(identifier)")
            tab.tap()
            XCTAssertTrue(tab.isSelected, "Tab \(identifier) did not become selected")
            XCTAssertEqual(app.state, .runningForeground, "App crashed opening \(identifier)")
        }
    }

    /// The log sheet is the app's primary action; opening it must not crash.
    func testLogSheetOpens() throws {
        try ensureProfileExists()

        let app = launchedApp()
        XCTAssertTrue(app.tabBars.buttons["tab.home"].waitForExistence(timeout: 20))
        app.tabBars.buttons["tab.home"].tap()

        let add = app.buttons["home.logChill"]
        guard scrollIntoView(add, in: app) else {
            XCTFail("The log button never came into view on Home")
            return
        }
        add.tap()

        // The sheet is a fullScreenCover, so Home's log button stops being hittable.
        let covered = NSPredicate(format: "exists == false OR isHittable == false")
        expectation(for: covered, evaluatedWith: add)
        waitForExpectations(timeout: 10)

        XCTAssertEqual(app.state, .runningForeground, "App crashed opening the log sheet")

        // Assert the sheet's identifiers really attach. They were declared in
        // AccessibilityID and applied nowhere, and the tab identifiers had the
        // same shape of bug: present in source, absent at runtime because they
        // sat on the wrong element. Only a query proves it.
        // Literals, not AccessibilityID constants: that file is compiled into the
        // app target only, and this target has no @testable import.
        XCTAssertTrue(
            app.buttons["log.save"].waitForExistence(timeout: 10),
            "Missing log.save. The Save button's identifier is not reaching the control."
        )
        let cancel = app.buttons["log.cancel"]
        XCTAssertTrue(
            cancel.waitForExistence(timeout: 5),
            "Missing log.cancel. The dismiss control's identifier is not reaching the control."
        )

        // Nothing was filled in, so dismissing takes no discard confirmation and
        // must put Home's log button back.
        cancel.tap()
        XCTAssertTrue(
            add.waitForExistence(timeout: 10),
            "Dismissing the log sheet did not return to Home."
        )
    }

    // MARK: - Screenshots (fastlane)

    /// Separate from the smoke tests and skipped unless fastlane is driving the
    /// run. It asserts nothing about behaviour: it exists to produce App Store
    /// screenshots.
    ///
    /// It previously wrapped every step in `if ... .exists`, so it passed
    /// unconditionally even when it captured nothing at all.
    func testScreenshots() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FASTLANE_SNAPSHOT"] == "YES",
            "Screenshot run; set FASTLANE_SNAPSHOT=YES to capture."
        )

        // fastlane erases the simulator between languages, so without this the
        // screenshots would be of the onboarding intro.
        try ensureProfileExists()

        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-hasShownFirstLaunchSplash", "YES"]
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
        snapshot("01_Dashboard")

        let more = app.tabBars.buttons["tab.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        snapshot("02_CareTools")

        let history = app.tabBars.buttons["tab.history"]
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        history.tap()
        snapshot("03_History")
    }
}
