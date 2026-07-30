import Foundation
import Testing
@testable import ChillMate

/// The lock screen used to accept unlimited PIN attempts. PBKDF2 at 200,000
/// iterations protects the stored hash against an offline attack, but nothing
/// stood between someone holding the device and the 10,000-guess space of a
/// 4-digit PIN.
///
/// These run against the real `UserDefaults.standard`, because that is where
/// `PINThrottle` deliberately persists. An in-memory counter would reset on a
/// force-quit, which is the obvious way around a throttle. Each test clears the
/// two keys before and after so it neither sees nor leaves state.
@Suite(.serialized)
struct PINThrottleTests {

    init() { Self.reset() }

    private static func reset() {
        UserDefaults.standard.removeObject(forKey: DefaultsKey.pinFailedAttempts)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.pinLockoutUntil)
    }

    @Test("The first failures do not lock out", .tags(.safety))
    func freeAttemptsDoNotLock() {
        defer { Self.reset() }

        for attempt in 1...PINThrottle.freeAttempts {
            #expect(PINThrottle.recordFailure() == nil,
                    "Attempt \(attempt) of \(PINThrottle.freeAttempts) should not lock out")
            #expect(PINThrottle.isLockedOut == false)
        }
        #expect(PINThrottle.failedAttempts == PINThrottle.freeAttempts)
    }

    @Test("The attempt after the free ones starts a lockout", .tags(.safety))
    func lockoutStartsAfterFreeAttempts() {
        defer { Self.reset() }

        for _ in 1...PINThrottle.freeAttempts { _ = PINThrottle.recordFailure() }

        let duration = PINThrottle.recordFailure()
        #expect(duration != nil, "Exceeding the free attempts must impose a lockout")
        #expect(PINThrottle.isLockedOut)
        #expect(PINThrottle.remainingLockout > 0)
    }

    @Test("Lockouts lengthen with each further failure", .tags(.safety))
    func lockoutsEscalate() {
        defer { Self.reset() }

        for _ in 1...PINThrottle.freeAttempts { _ = PINThrottle.recordFailure() }

        var durations: [TimeInterval] = []
        for _ in 1...4 {
            if let duration = PINThrottle.recordFailure() { durations.append(duration) }
        }

        #expect(durations.count == 4)
        for (earlier, later) in zip(durations, durations.dropFirst()) {
            #expect(later >= earlier, "Lockout must not shrink: \(durations)")
        }
        #expect(durations.last! > durations.first!, "Lockouts must escalate: \(durations)")
    }

    @Test("Lockouts are capped so a user is never locked out indefinitely", .tags(.safety))
    func lockoutIsCapped() {
        defer { Self.reset() }

        for _ in 1...PINThrottle.freeAttempts { _ = PINThrottle.recordFailure() }

        var last: TimeInterval = 0
        for _ in 1...20 {
            if let duration = PINThrottle.recordFailure() { last = duration }
        }
        // 15 minutes is the documented ceiling; assert against it directly so a
        // change to the cap has to be deliberate.
        #expect(last <= 15 * 60, "Lockout grew past the 15-minute cap: \(last)s")
    }

    @Test("A correct PIN clears the counter and any lockout", .tags(.safety))
    func successResets() {
        defer { Self.reset() }

        for _ in 1...(PINThrottle.freeAttempts + 2) { _ = PINThrottle.recordFailure() }
        #expect(PINThrottle.isLockedOut)

        PINThrottle.recordSuccess()

        #expect(PINThrottle.failedAttempts == 0)
        #expect(PINThrottle.isLockedOut == false)
        #expect(PINThrottle.remainingLockout == 0)
        #expect(PINThrottle.lockedUntil == nil)
    }

    @Test("An expired lockout stops reporting as locked out", .tags(.safety))
    func expiredLockoutClears() {
        defer { Self.reset() }

        // Backdate the deadline rather than sleeping through a real one.
        UserDefaults.standard.set(Date.now.addingTimeInterval(-1).timeIntervalSince1970,
                                  forKey: DefaultsKey.pinLockoutUntil)
        #expect(PINThrottle.isLockedOut == false)
        #expect(PINThrottle.lockedUntil == nil)
        #expect(PINThrottle.remainingLockout == 0)
    }
}
