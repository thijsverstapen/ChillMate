import Foundation
import Testing
@testable import ChillMate

/// The two decisions the watch makes without the phone.
///
/// The watch app has no test bundle of its own — standing up a watchOS runner in
/// CI for two rules is not worth it — so the rules live in `WidgetSharedKeys.swift`,
/// which is a member of every target, and are exercised from here.
@Suite("Watch logic")
struct WatchLogicTests {

    // MARK: The emergency number

    /// The default is right for five of the six countries ChillMate ships support
    /// for and reaches nobody in the sixth, so anything real must beat it.
    @Test("A stored number beats the 112 default", .tags(.safety))
    func storedNumberWins() {
        #expect(WatchLogic.emergencyNumber(stored: "911") == "911")
        #expect(WatchLogic.emergencyNumber(stored: "000") == "000")
    }

    @Test("A number relayed now beats a stored one", .tags(.safety))
    func relayedNumberWins() {
        #expect(WatchLogic.emergencyNumber(stored: "112", relayed: "911") == "911")
    }

    /// The failure this exists to prevent: an empty string dials nothing, and a
    /// blank arriving from the phone must not overwrite a good stored number or
    /// beat the default.
    @Test("Blank never wins, from either side", .tags(.safety), arguments: ["", " ", "   "])
    func blankNeverWins(blank: String) {
        #expect(WatchLogic.emergencyNumber(stored: blank) == "112")
        #expect(WatchLogic.emergencyNumber(stored: "911", relayed: blank) == "911")
        #expect(WatchLogic.emergencyNumber(stored: nil, relayed: blank) == "112")
    }

    @Test("With nothing at all, it still returns something dialable", .tags(.safety))
    func neverReturnsEmpty() {
        let number = WatchLogic.emergencyNumber(stored: nil, relayed: nil)
        #expect(number.isEmpty == false)
        #expect(number == "112")
    }

    // MARK: The day rollover

    @Test("The day key changes at local midnight and not before")
    func dayKeyFollowsLocalMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Amsterdam"))

        let midnight = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 11)))
        let lateSameNight = midnight.addingTimeInterval(23 * 3600 + 59 * 60)
        let justAfter = midnight.addingTimeInterval(24 * 3600)

        #expect(WatchLogic.dayKey(for: midnight, calendar: calendar)
                == WatchLogic.dayKey(for: lateSameNight, calendar: calendar))
        #expect(WatchLogic.dayKey(for: justAfter, calendar: calendar)
                == WatchLogic.dayKey(for: midnight, calendar: calendar) + 1)
    }

    /// A night out runs past midnight, which is exactly when this is used.
    @Test("Three in the morning belongs to the new day, as the rest of the app has it")
    func threeAmIsTheNextDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Amsterdam"))

        let evening = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 23)))
        let afterMidnight = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 3)))

        #expect(WatchLogic.dayKey(for: afterMidnight, calendar: calendar)
                == WatchLogic.dayKey(for: evening, calendar: calendar) + 1)
    }

    /// Zero is what `UserDefaults.integer(forKey:)` returns for a key that was
    /// never written, and it must not read as "already sent today".
    @Test("A watch that has never sent one can still send today")
    func neverSentIsAvailable() {
        #expect(WatchLogic.isAvailableToday(lastSentDay: 0))
    }

    @Test("Sent today blocks, sent yesterday does not")
    func availabilityFollowsTheDay() {
        let today = WatchLogic.dayKey(for: .now)
        #expect(WatchLogic.isAvailableToday(lastSentDay: today) == false)
        #expect(WatchLogic.isAvailableToday(lastSentDay: today - 1))
    }

    // MARK: Heart readings

    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func reading(minutesAgo: Double) -> HealthSample {
        HealthSample(value: 130, date: now.addingTimeInterval(-minutesAgo * 60))
    }

    /// A heart rate that is not from the last few minutes is not the heart as it
    /// is now, and must not be shown as though it were.
    @Test("A reading from a few minutes ago is current, one from much longer ago is not", .tags(.safety))
    func readingsExpire() {
        #expect(WatchLogic.isCurrent(reading(minutesAgo: 5), now: now))
        #expect(WatchLogic.isCurrent(reading(minutesAgo: 14), now: now))
        #expect(!WatchLogic.isCurrent(reading(minutesAgo: 16), now: now))
        #expect(!WatchLogic.isCurrent(reading(minutesAgo: 24 * 60), now: now))
        #expect(!WatchLogic.isCurrent(nil, now: now))
    }

    /// The phone's clock and the watch's can disagree by a little, never by much.
    @Test("A reading slightly in the future is allowed for, one well ahead is not")
    func futureReadings() {
        #expect(WatchLogic.isCurrent(reading(minutesAgo: -0.5), now: now))
        #expect(!WatchLogic.isCurrent(reading(minutesAgo: -5), now: now))
    }

    // MARK: Timers

    private func timerPayload(id: UUID = UUID(), substance: String = "Timer", startedMinutesAgo: Double, hours: Double) -> [String: Any] {
        [
            "id": id.uuidString,
            "substance": substance,
            "startedAt": now.addingTimeInterval(-startedMinutesAgo * 60).timeIntervalSince1970,
            "durationHours": hours,
        ]
    }

    @Test("Running timers arrive soonest-ending first, and finished or malformed ones are dropped")
    func timersParse() {
        let soon = UUID(), later = UUID()
        let payload: [[String: Any]] = [
            timerPayload(id: later, startedMinutesAgo: 10, hours: 4),
            timerPayload(id: soon, startedMinutesAgo: 170, hours: 3),
            timerPayload(startedMinutesAgo: 300, hours: 2),
            ["id": "not a uuid", "substance": "X", "startedAt": 0.0, "durationHours": 1.0],
            ["substance": "missing id"],
        ]
        let timers = WatchLogic.timers(from: payload, now: now)
        #expect(timers.map(\.id) == [soon, later])
    }

    // MARK: The face

    private var running: [WatchTimerInfo] {
        WatchLogic.timers(from: [timerPayload(substance: "Ketamin", startedMinutesAgo: 30, hours: 2)], now: now)
    }

    @Test("The face shows the first running timer when timers are visible")
    func faceShowsTimer() throws {
        let face = WatchLogic.faceSnapshot(timers: running, timersVisible: true, streakDays: 4, score: 71, scoreActive: true, discreet: false)
        let timer = try #require(running.first)
        #expect(face.timerSubstance == "Ketamin")
        #expect(face.timerEnd == timer.endsAt.timeIntervalSince1970)
        #expect(face.streakDays == 4)
        #expect(face.score == 71)
    }

    /// "Visible timers and complications" used to hide timers in the app only,
    /// so the face kept naming the substance for somebody who had switched it off.
    @Test("With timers hidden, the face shows none", .tags(.safety))
    func faceHidesTimer() {
        let face = WatchLogic.faceSnapshot(timers: running, timersVisible: false, streakDays: 4, score: 71, scoreActive: true, discreet: false)
        #expect(face.timerSubstance.isEmpty)
        #expect(face.timerStart == 0)
        #expect(face.timerEnd == 0)
    }

    @Test("What the face shows survives the App Group round trip")
    func faceRoundTrips() throws {
        let suite = "WatchLogicTests.face"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let face = WatchLogic.faceSnapshot(timers: running, timersVisible: true, streakDays: 9, score: 55, scoreActive: false, discreet: true)
        face.write(to: defaults)
        #expect(WatchFaceSnapshot.read(from: defaults) == face)
    }

    /// Only a change on the face is worth waking the watch for.
    @Test("The keys that wake the watch are the ones its face shows")
    func faceKeys() {
        #expect(WidgetSharedKey.watchFaceKeys.contains(WidgetSharedKey.watchContextTimers))
        #expect(WidgetSharedKey.watchFaceKeys.contains(WidgetSharedKey.discreetLockScreenTimer))
        #expect(WidgetSharedKey.watchFaceKeys.contains(WidgetSharedKey.watchVisibleTimers))
        #expect(!WidgetSharedKey.watchFaceKeys.contains(WidgetSharedKey.watchHydrationReminders))
        #expect(!WidgetSharedKey.watchFaceKeys.contains("trustedContactPhone"))
    }

    // MARK: Taps waiting for the phone

    @Test("Every glass of water is kept, in order")
    func waterIsKept() {
        var pending: [WatchEvent] = []
        pending = WatchLogic.enqueue(.hydrationLogged, onto: pending)
        pending = WatchLogic.enqueue(.homeSafeReported, onto: pending)
        pending = WatchLogic.enqueue(.hydrationLogged, onto: pending)
        #expect(pending == [.hydrationLogged, .homeSafeReported, .hydrationLogged])
    }

    @Test("Only the last discreet check-ins choice still waiting is sent")
    func lastChoiceWins() {
        var pending: [WatchEvent] = [.discreetCheckIns(false), .quickSkipRequested]
        pending = WatchLogic.enqueue(.discreetCheckIns(true), onto: pending)
        #expect(pending == [.quickSkipRequested, .discreetCheckIns(true)])
    }

    /// Kept on disk so a relaunch before the session activates loses nothing.
    @Test("Waiting taps survive a relaunch, and an empty queue leaves nothing behind")
    func pendingPersists() throws {
        let suite = "WatchLogicTests.pending"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let events: [WatchEvent] = [.quickSkipRequested, .discreetCheckIns(false), .homeSafeReported]
        WatchLogic.savePendingEvents(events, in: defaults)
        #expect(WatchLogic.pendingEvents(in: defaults) == events)
        WatchLogic.savePendingEvents([], in: defaults)
        #expect(defaults.object(forKey: WidgetSharedKey.watchPendingEvents) == nil)
    }

    /// The phone's `WatchConnectivityService.handleInbound` reads these exact keys.
    @Test("Each tap reaches the phone in the shape it reads")
    func eventPayloads() {
        #expect(WatchEvent.hydrationLogged.payload["hydrationLogged"] as? Bool == true)
        #expect(WatchEvent.quickSkipRequested.payload["quickSkipRequested"] as? Bool == true)
        #expect(WatchEvent.homeSafeReported.payload["homeSafeReported"] as? Bool == true)
        #expect(WatchEvent.discreetCheckIns(false).payload["setDiscreetCheckIns"] as? Bool == false)
    }

    // MARK: The phone's context across a relaunch

    /// The phone's context starts empty on every launch and each push replaces
    /// the watch's wholesale, so what was sent before has to be carried forward:
    /// a restarted phone app left the watch with no running timer.
    @Test("What was sent before a relaunch is kept, and anything sent since wins")
    @MainActor
    func contextSurvivesRelaunch() {
        let sent: [String: Any] = [
            WidgetSharedKey.watchContextTimers: [["id": "a"]],
            WidgetSharedKey.watchContextStreakDays: 3,
        ]
        let sinceLaunch: [String: Any] = [WidgetSharedKey.watchContextStreakDays: 4, "emergencyNumber": "911"]
        let restored = WatchConnectivityService.restoredContext(sent: sent, sinceLaunch: sinceLaunch)
        #expect((restored[WidgetSharedKey.watchContextTimers] as? [[String: String]])?.first?["id"] == "a")
        #expect(restored[WidgetSharedKey.watchContextStreakDays] as? Int == 4)
        #expect(restored["emergencyNumber"] as? String == "911")
    }
}

