import Foundation
import Testing
@testable import ChillMate

/// The rules that decide whether a person's data is copied to iCloud.
///
/// Until 5.1.0 there were none: the store mirrored to CloudKit for everyone signed
/// into iCloud, while every word in and about the app described it as opt-in.
/// These pin the replacement. Each case is a real person — a new install, an
/// existing one that has not been asked, one that said yes, one that said no — and
/// getting any of them wrong either copies data somebody declined to copy, or
/// strands history somebody was relying on without knowing it.
///
/// Each test gets its own defaults suite so no case can leak into another, or into
/// the app's own settings on the test host.
@Suite("iCloud sync preference")
struct ICloudSyncPreferenceTests {

    private func freshDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "ICloudSyncPreferenceTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: New installs

    /// The promise, made true: a new install copies nothing and is never asked.
    @Test("A new install starts off and is never asked")
    func newInstallIsOffAndSettled() {
        let defaults = freshDefaults()
        ICloudSyncPreference.resolveAtLaunch(storeExists: false, defaults: defaults)

        #expect(ICloudSyncPreference.choice(in: defaults) == .off)
        #expect(!ICloudSyncPreference.needsDecision(in: defaults))
        #expect(!ICloudSyncPreference.mirrorsToCloudKit(choice: ICloudSyncPreference.choice(in: defaults)))
    }

    // MARK: Existing installs

    /// A store on disk with no choice is an install from before 5.1.0. It has been
    /// syncing, so it is asked rather than silently switched either way.
    @Test("An install that already has a store is asked")
    func existingInstallIsAsked() {
        let defaults = freshDefaults()
        ICloudSyncPreference.resolveAtLaunch(storeExists: true, defaults: defaults)

        #expect(ICloudSyncPreference.choice(in: defaults) == nil)
        #expect(ICloudSyncPreference.needsDecision(in: defaults))
    }

    /// Until it answers, an existing install keeps doing what it was doing. The
    /// question comes before the app's own container, so this is only reachable by
    /// something that opens the store without the UI.
    @Test("An existing install that has not answered keeps its old behaviour")
    func undecidedMirrors() {
        #expect(ICloudSyncPreference.mirrorsToCloudKit(choice: nil))
    }

    // MARK: Answers

    @Test("Each answer does what it says", arguments: ICloudSyncPreference.Choice.allCases)
    func answersAreHonoured(choice: ICloudSyncPreference.Choice) {
        #expect(ICloudSyncPreference.mirrorsToCloudKit(choice: choice) == (choice == .on))
    }

    /// An answer is final until the person changes it. A later launch must not ask
    /// again, and must not re-derive the answer from whether a store exists — by
    /// then one always does, which would turn every "off" back into a question.
    @Test("An answer survives later launches", arguments: ICloudSyncPreference.Choice.allCases)
    func answerPersists(choice: ICloudSyncPreference.Choice) {
        let defaults = freshDefaults("answerPersists.\(choice.rawValue)")
        ICloudSyncPreference.resolveAtLaunch(storeExists: true, defaults: defaults)
        ICloudSyncPreference.record(choice, in: defaults)

        for storeExists in [true, false] {
            ICloudSyncPreference.resolveAtLaunch(storeExists: storeExists, defaults: defaults)
            #expect(ICloudSyncPreference.choice(in: defaults) == choice)
            #expect(!ICloudSyncPreference.needsDecision(in: defaults))
        }
    }

    /// A new install that later opens its store must stay off. The first launch
    /// creates the store, so from the second launch on it looks exactly like an
    /// existing install — the recorded "off" is the only thing telling them apart.
    @Test("A new install is not asked on its second launch")
    func newInstallStaysSettled() {
        let defaults = freshDefaults()
        ICloudSyncPreference.resolveAtLaunch(storeExists: false, defaults: defaults)
        // The first launch created a store; this is the next one.
        ICloudSyncPreference.resolveAtLaunch(storeExists: true, defaults: defaults)

        #expect(ICloudSyncPreference.choice(in: defaults) == .off)
        #expect(!ICloudSyncPreference.needsDecision(in: defaults))
    }

    /// A stored value that is neither answer — a hand-edited plist, a key from a
    /// later version rolled back — is treated as no answer, so the person is asked
    /// again rather than guessed for.
    @Test("An unrecognised stored value counts as unanswered")
    func garbageIsUnanswered() {
        let defaults = freshDefaults()
        defaults.set("maybe", forKey: DefaultsKey.iCloudSyncChoice)

        #expect(ICloudSyncPreference.choice(in: defaults) == nil)
        #expect(ICloudSyncPreference.needsDecision(in: defaults))
    }
}
