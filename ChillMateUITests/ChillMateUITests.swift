import XCTest

class ChillMateUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        
        let app = XCUIApplication()
        
        // Fastlane snapshot setup
        setupSnapshot(app)
        
        // Pass a launch argument if you want to bypass the App Lock or onboarding in your app code
        app.launchArguments.append("-UITestMode")
        
        app.launch()
    }

    func testScreenshots() throws {
        let app = XCUIApplication()
        
        // Wait for the Dashboard to load
        sleep(3)
        
        // 1. Capture Dashboard
        snapshot("01_Dashboard")
        
        // 2. Navigate to Care Tools (More Tab)
        if app.tabBars.buttons["More"].exists {
            app.tabBars.buttons["More"].tap()
            sleep(1)
            snapshot("02_CareTools")
        }
        
        // 3. Navigate to Timers
        // Depending on your UI, you might tap a specific button here.
        // E.g., app.buttons["Start Timer"].tap()
        // snapshot("03_Timers")
        
        // 4. Navigate to Journal Tab
        if app.tabBars.buttons["Journal"].exists {
            app.tabBars.buttons["Journal"].tap()
            sleep(1)
            snapshot("04_Journal")
        }
        
        // TIP: If the UI Test fails to find your buttons, you can click inside this
        // function in Xcode and press the red "Record" button at the bottom of the editor
        // to record your actual taps!
    }
}
