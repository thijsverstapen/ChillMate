import Foundation
import Testing
@testable import ChillMate

/// Whether a running dose timer names the substance on the Lock Screen.
@Suite("Discreet Lock Screen timer")
struct LockScreenTimerPrivacyTests {

    private func suites(_ name: String = #function) -> (standard: UserDefaults, shared: UserDefaults) {
        let standardName = "LockScreenTimerPrivacyTests.standard.\(name)"
        let sharedName = "LockScreenTimerPrivacyTests.shared.\(name)"
        let standard = UserDefaults(suiteName: standardName)!
        let shared = UserDefaults(suiteName: sharedName)!
        standard.removePersistentDomain(forName: standardName)
        shared.removePersistentDomain(forName: sharedName)
        return (standard, shared)
    }

    /// Somebody who asked for discreet notifications wanted a Lock Screen that
    /// gives nothing away. Their timer starts discreet too.
    @Test("It starts discreet for somebody who already chose discreet notifications")
    func followsDiscreetNotifications() {
        let (standard, shared) = suites()
        standard.set(true, forKey: DefaultsKey.discreetNotifications)

        LockScreenTimerPrivacy.settleDefault(standard: standard, shared: shared)

        #expect(LockScreenTimerPrivacy.isDiscreet(in: shared))
    }

    @Test("It starts as it was for everybody else")
    func otherwiseUnchanged() {
        let (standard, shared) = suites()
        LockScreenTimerPrivacy.settleDefault(standard: standard, shared: shared)
        #expect(!LockScreenTimerPrivacy.isDiscreet(in: shared))
    }

    /// The default is taken once. A later launch must never undo a choice made
    /// in Settings, in either direction.
    @Test("A choice made in Settings survives later launches", arguments: [true, false])
    func choiceSurvives(chosen: Bool) {
        let (standard, shared) = suites("choiceSurvives.\(chosen)")
        shared.set(chosen, forKey: WidgetSharedKey.discreetLockScreenTimer)
        standard.set(!chosen, forKey: DefaultsKey.discreetNotifications)

        LockScreenTimerPrivacy.settleDefault(standard: standard, shared: shared)

        #expect(LockScreenTimerPrivacy.isDiscreet(in: shared) == chosen)
    }

    /// A timer started by a build from before this setting has no `discreet` in
    /// its state. It has to keep decoding across the update, and reads as not
    /// discreet, which is what it was showing.
    @Test("A timer started by an older build still decodes")
    func oldStateDecodes() throws {
        let old = #"{"substanceName":"MDMA","endsAt":800000000,"redoseNudgeActive":false}"#
        let state = try JSONDecoder().decode(DrugTimerActivityAttributes.ContentState.self, from: Data(old.utf8))
        #expect(state.discreet == nil)
        #expect(state.substanceName == "MDMA")
    }

    @Test("The discreet flag survives the round trip ActivityKit makes")
    func discreetRoundTrips() throws {
        let state = DrugTimerActivityAttributes.ContentState(
            substanceName: "MDMA",
            endsAt: Date(timeIntervalSince1970: 1_790_000_000),
            redoseNudgeActive: false,
            startedAt: nil,
            discreet: true
        )
        let decoded = try JSONDecoder().decode(
            DrugTimerActivityAttributes.ContentState.self,
            from: try JSONEncoder().encode(state)
        )
        #expect(decoded.discreet == true)
    }
}
