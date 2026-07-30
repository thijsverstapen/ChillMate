import Foundation

/// Rate limits PIN entry with escalating lockouts.
///
/// The lock screen accepted unlimited PIN attempts. PBKDF2 at 200,000 iterations
/// makes an *offline* attack on the stored hash expensive, but nothing at all
/// stood between someone holding the unlocked device and the 10,000-guess space of
/// a 4-digit PIN, the app's own minimum. At roughly a second per guess that is a
/// few hours of tapping to reach a full log of someone's sex and substance use.
///
/// Failures and the lockout deadline persist in UserDefaults so they survive the
/// app being force-quit and relaunched, which is otherwise the obvious way around
/// an in-memory counter.
///
/// Deliberately *not* wiping data after N failures: this app's users may be
/// handing their phone to someone, or fumbling a PIN while impaired, and silent
/// destruction of a harm-reduction log is a worse outcome than a wait.
enum PINThrottle {
    /// Attempts allowed before the first lockout.
    static let freeAttempts = 5

    /// Lockout duration after `freeAttempts`, doubling with each further failure
    /// up to `maxLockout`.
    private static let baseLockout: TimeInterval = 30
    private static let maxLockout: TimeInterval = 15 * 60

    private static var defaults: UserDefaults { .standard }

    static var failedAttempts: Int {
        defaults.integer(forKey: DefaultsKey.pinFailedAttempts)
    }

    /// When the lockout expires, or nil when not locked out.
    static var lockedUntil: Date? {
        let stamp = defaults.double(forKey: DefaultsKey.pinLockoutUntil)
        guard stamp > 0 else { return nil }
        let date = Date(timeIntervalSince1970: stamp)
        return date > .now ? date : nil
    }

    static var isLockedOut: Bool { lockedUntil != nil }

    /// Seconds left in the current lockout, rounded up; 0 when not locked out.
    static var remainingLockout: Int {
        guard let lockedUntil else { return 0 }
        return max(0, Int(lockedUntil.timeIntervalSinceNow.rounded(.up)))
    }

    /// Records a failure and starts or extends the lockout once past the free
    /// attempts. Returns the lockout imposed, or nil if attempts remain.
    @discardableResult
    static func recordFailure() -> TimeInterval? {
        let attempts = failedAttempts + 1
        defaults.set(attempts, forKey: DefaultsKey.pinFailedAttempts)

        guard attempts > freeAttempts else { return nil }

        let overage = attempts - freeAttempts - 1
        let duration = min(maxLockout, baseLockout * pow(2, Double(overage)))
        defaults.set(Date.now.addingTimeInterval(duration).timeIntervalSince1970,
                     forKey: DefaultsKey.pinLockoutUntil)
        return duration
    }

    /// Clears the counter and any lockout after a correct PIN.
    static func recordSuccess() {
        defaults.removeObject(forKey: DefaultsKey.pinFailedAttempts)
        defaults.removeObject(forKey: DefaultsKey.pinLockoutUntil)
    }
}
