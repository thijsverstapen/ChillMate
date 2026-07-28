import XCTest

@MainActor
final class ChillMateUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// A launched app with onboarding and the splash bypassed.
    ///
    /// Each test launches its own instance. `setUpWithError` used to launch one and
    /// the tests then launched more, leaving several instances running against each
    /// other.
    private func launchedApp(language: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestMode", "-hasShownFirstLaunchSplash", "YES"]
        if let language {
            app.launchArguments += ["-AppleLanguages", "(\(language))"]
        }
        app.launch()
        return app
    }

    // MARK: - Smoke tests (crash canaries)

    /// The app must reach and hold the foreground — catches launch-time crashes
    /// (container/schema failures, bad state restoration).
    func testLaunchesToForeground() throws {
        let app = launchedApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        // Held for a few seconds by polling rather than `sleep(3)`, so this fails
        // the moment the app dies instead of at the end of a fixed wait.
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            XCTAssertEqual(app.state, .runningForeground, "App crashed shortly after launch")
            _ = app.wait(for: .runningForeground, timeout: 0.5)
        }
    }

    /// Launch once per supported language — catches locale-specific crashes
    /// (bad format strings, missing catalog entries misused at runtime).
    func testLaunchesInEveryLanguage() throws {
        for language in ["en", "nl", "de", "fr", "es"] {
            let app = launchedApp(language: language)
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15),
                          "App failed to launch in \(language)")
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15),
                          "Main tab bar never appeared in \(language)")
            XCTAssertEqual(app.state, .runningForeground, "App crashed after launch in \(language)")
            app.terminate()
        }
    }

    /// Every tab must be reachable and render something.
    ///
    /// Queries by accessibility identifier rather than by visible label. The old
    /// tests looked up `buttons["More"]`, which could only ever match in English —
    /// including inside the run whose whole point is the other four languages.
    func testEachTabOpens() throws {
        let app = launchedApp()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))

        for identifier in ["tab.home", "tab.history", "tab.more"] {
            let tab = app.tabBars.buttons[identifier]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing tab \(identifier)")
            tab.tap()
            XCTAssertTrue(tab.isSelected, "Tab \(identifier) did not become selected")
            XCTAssertEqual(app.state, .runningForeground, "App crashed opening \(identifier)")
        }
    }

    /// The log sheet is the app's primary action; opening it must not crash.
    func testLogSheetOpens() throws {
        let app = launchedApp()
        XCTAssertTrue(app.tabBars.buttons["tab.home"].waitForExistence(timeout: 15))
        app.tabBars.buttons["tab.home"].tap()

        let add = app.buttons["home.logChill"]
        guard add.waitForExistence(timeout: 10) else {
            XCTFail("The log button never appeared on Home")
            return
        }
        add.tap()

        // The sheet is a fullScreenCover, so Home's log button stops being hittable.
        let covered = NSPredicate(format: "exists == false OR isHittable == false")
        expectation(for: covered, evaluatedWith: add)
        waitForExpectations(timeout: 10)

        XCTAssertEqual(app.state, .runningForeground, "App crashed opening the log sheet")
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

        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-UITestMode", "-hasShownFirstLaunchSplash", "YES"]
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
