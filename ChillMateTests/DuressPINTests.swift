import Foundation
import Testing
@testable import ChillMate

/// The second PIN, and the properties that make it worth having.
///
/// The threat is not a stolen phone — the ordinary PIN handles that. It is being
/// stood over and told to unlock. An app that visibly refuses is worse than one
/// that opens, so this one opens, and everything below is about it opening in a
/// way that gives nothing away.
///
/// Runs against the real Keychain on the simulator, and cleans up after itself so
/// the suite leaves no credentials behind.
@Suite("Duress PIN", .serialized)
struct DuressPINTests {

    private func withCleanCredentials(_ body: () -> Void) {
        LocalSecurityService.clearPIN()
        LocalSecurityService.clearDuressPIN()
        defer {
            LocalSecurityService.clearPIN()
            LocalSecurityService.clearDuressPIN()
            UserDefaults.standard.removeObject(forKey: DefaultsKey.duressModeActive)
        }
        body()
    }

    @Test("A duress PIN verifies, and only against itself", .tags(.safety))
    func verifiesOnlyItself() {
        withCleanCredentials {
            LocalSecurityService.savePINToKeychain(pin: "1234")
            LocalSecurityService.saveDuressPIN("9876")

            #expect(LocalSecurityService.verifyDuressPIN("9876"))
            #expect(LocalSecurityService.verifyDuressPIN("1234") == false)
            #expect(LocalSecurityService.verifyDuressPIN("0000") == false)
            #expect(LocalSecurityService.verifyDuressPIN("") == false)
        }
    }

    /// The two must not be confusable in either direction, or entering one would
    /// silently do the other's job.
    @Test("The real PIN and the duress PIN do not answer for each other", .tags(.safety))
    func theTwoAreIndependent() {
        withCleanCredentials {
            LocalSecurityService.savePINToKeychain(pin: "1234")
            LocalSecurityService.saveDuressPIN("9876")

            #expect(LocalSecurityService.verifyPINFromKeychain("1234"))
            #expect(LocalSecurityService.verifyPINFromKeychain("9876") == false)
            #expect(LocalSecurityService.verifyDuressPIN("9876"))
            #expect(LocalSecurityService.verifyDuressPIN("1234") == false)
        }
    }

    /// A second PIN equal to the first could never be entered, and setting one
    /// would leave somebody believing they had protection they do not have.
    @Test("A duress PIN identical to the real one is refused", .tags(.safety))
    func identicalPINIsRefused() {
        withCleanCredentials {
            LocalSecurityService.savePINToKeychain(pin: "1234")

            #expect(LocalSecurityService.isAcceptableDuressPIN("1234") == false)
            #expect(LocalSecurityService.isAcceptableDuressPIN("9876"))
        }
    }

    @Test("A duress PIN obeys the same shape rules as the real one", arguments: [
        "123", "123456789", "12a4", "", "abcd",
    ])
    func malformedPINsAreRefused(pin: String) {
        withCleanCredentials {
            LocalSecurityService.savePINToKeychain(pin: "1234")
            #expect(LocalSecurityService.isAcceptableDuressPIN(pin) == false)
        }
    }

    @Test("Turning it off removes it, and leaves the real PIN alone", .tags(.safety))
    func clearingRemovesOnlyTheDuressPIN() {
        withCleanCredentials {
            LocalSecurityService.savePINToKeychain(pin: "1234")
            LocalSecurityService.saveDuressPIN("9876")
            #expect(LocalSecurityService.hasDuressPIN())

            LocalSecurityService.clearDuressPIN()

            #expect(LocalSecurityService.hasDuressPIN() == false)
            #expect(LocalSecurityService.verifyDuressPIN("9876") == false)
            #expect(LocalSecurityService.verifyPINFromKeychain("1234"),
                    "clearing the second PIN must not disturb the real one")
        }
    }

    /// Turning it off must also drop the flag, or the app would come up empty with
    /// no way left to say otherwise.
    @Test("Turning it off leaves duress mode", .tags(.safety))
    func clearingLeavesDuressMode() {
        withCleanCredentials {
            UserDefaults.standard.set(true, forKey: DefaultsKey.duressModeActive)
            #expect(LocalSecurityService.isInDuressMode)

            LocalSecurityService.clearDuressPIN()
            #expect(LocalSecurityService.isInDuressMode == false)
        }
    }

    /// The decoy is a view, not an action. Nothing here deletes anything, because
    /// somebody under stress mistyping into a destructive PIN would lose years of
    /// history with no way back.
    @Test("Nothing about duress mode destroys the real credentials", .tags(.safety))
    func duressModeDestroysNothing() {
        withCleanCredentials {
            LocalSecurityService.savePINToKeychain(pin: "1234")
            LocalSecurityService.saveDuressPIN("9876")

            UserDefaults.standard.set(true, forKey: DefaultsKey.duressModeActive)

            #expect(LocalSecurityService.verifyPINFromKeychain("1234"),
                    "the real PIN stopped working while in duress mode")
            #expect(LocalSecurityService.hasPINCredentials())
        }
    }

    @Test("With no duress PIN set, nothing verifies", .tags(.safety))
    func noDuressPINVerifiesNothing() {
        withCleanCredentials {
            LocalSecurityService.savePINToKeychain(pin: "1234")

            #expect(LocalSecurityService.hasDuressPIN() == false)
            #expect(LocalSecurityService.verifyDuressPIN("9876") == false)
            #expect(LocalSecurityService.verifyDuressPIN("1234") == false)
        }
    }
}
