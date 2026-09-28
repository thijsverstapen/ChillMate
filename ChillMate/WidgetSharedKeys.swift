import Foundation

/// Keys in the shared App Group suite, written by the phone or watch app and read
/// by the widget and Live Activity extensions.
///
/// These crossed four targets (the app, the watch app, the watch widget, and the
/// Live Activity extension) as bare string literals duplicated at each end, with
/// a comment in `WatchConnectivityReceiver` reading "Key strings are duplicated in
/// the widget's WidgetStore by design. Keep them in sync." Nothing enforced that.
/// Renaming a key on the writing side left the reading side compiling cleanly and
/// silently showing zeros on the user's watch face.
///
/// This file is a member of all four targets, so the two ends cannot drift.
///
/// The names are deliberately unchanged: they are already in use on shipped
/// devices, and altering one would blank a complication until the next write.
enum WidgetSharedKey {
    /// App Group suite shared by every ChillMate target.
    static let suiteName = "group.com.codex.ChillMate"

    // MARK: Written by the watch app, read by the watch complication
    static let watchStreakDays = "widgetStreakDays"
    static let watchScore = "widgetScore"
    static let watchScoreActive = "widgetScoreActive"
    static let watchTimerSubstance = "widgetTimerSubstance"
    static let watchTimerStart = "widgetTimerStart"
    static let watchTimerEnd = "widgetTimerEnd"

    // MARK: Written by the phone app, read by the Live Activity extension
    static let recoveryStreak = "widgetRecoveryStreak"
    static let dailyScore = "lastDailyRecoveryScore"
    static let scoreIsActive = "widgetScoreIsActive"

    // MARK: Written by the phone app and by the Live Activity's Log water button

    /// Hydration timestamp. `HydrationLog` in the app target and the Live Activity's
    /// intent both read and write this, in the shared suite above, from separate
    /// processes. It lived as a bare literal at both ends, so changing either the
    /// spelling or the suite at one end stopped hydration crossing the boundary with
    /// no error anywhere.
    static let hydrationLogDate = "lastHydrationLogDate"

    // MARK: Watch settings, pushed from the phone in the application context
    //
    // These were bare string literals at both ends: spelled once in
    // `WatchConnectivityService.sendSettings()` and again in the watch's
    // `applyContext`. Renaming either side left both compiling and the watch
    // silently falling back to its defaults, which is the exact failure this file
    // was created to stop and which its own header describes.

    static let watchHydrationReminders = "watchHydrationReminders"
    static let watchBreathingHaptics = "watchBreathingHaptics"
    static let watchDiscreetCheckIns = "watchDiscreetCheckIns"
    static let watchVisibleTimers = "watchVisibleTimers"
    static let watchHeartRateWarnings = "watchHeartRateWarnings"

    static let watchStrainDetection = "watchStressAndTemperatureDetection"

    /// Every watch setting the phone pushes, so the sender cannot omit one by
    /// accident.
    static let watchSettingKeys = [
        watchHydrationReminders,
        watchBreathingHaptics,
        watchDiscreetCheckIns,
        watchVisibleTimers,
        watchHeartRateWarnings,
        watchStrainDetection,
    ]

    // MARK: Physiological strain, pushed from the phone

    /// Heart-rate variability in milliseconds, and whether a reading exists.
    ///
    /// Paired with the heart rate the phone already relays. Neither number means
    /// much alone: a high heart rate on its own is dancing. A high heart rate
    /// with suppressed variability is the body under load, which is the signal
    /// worth interrupting someone for.
    static let hasHRV = "hasHRV"
    static let latestHRVms = "latestHRVms"
    /// When that variability reading was taken, in seconds since 1970.
    static let latestHRVAt = "latestHRVAt"

    /// The heart rate the phone last read from Apple Health, whether one exists,
    /// and when it was taken. The time is what lets the watch refuse a reading
    /// that is no longer about now. A phone on an older build sends none, and
    /// its readings count as not current.
    static let hasBPM = "hasBPM"
    static let latestBPM = "latestBPM"
    static let latestBPMAt = "latestBPMAt"

    // MARK: What the watch face shows, pushed from the phone

    static let watchContextTimers = "timers"
    static let watchContextStreakDays = "recoveryStreakDays"
    static let watchContextScore = "dailyScore"
    static let watchContextScoreActive = "dailyScoreActive"

    /// The pushed keys the watch face shows. A push that changes one of them is
    /// worth waking the watch for, so the face is right without the app open.
    static let watchFaceKeys: Set<String> = [
        watchContextTimers,
        watchContextStreakDays,
        watchContextScore,
        watchContextScoreActive,
        watchVisibleTimers,
        discreetLockScreenTimer,
    ]

    // MARK: Watch-local state
    //
    // These live in the watch's own `UserDefaults.standard`, NOT in the shared suite
    // above, because nothing off the watch reads them. They are registered here only
    // because this file is the one key registry the watch target compiles, and a key
    // that is not in a registry is a key that can drift.

    static let watchHydrationCount = "watchHydrationCount"
    static let watchHydrationDay = "watchHydrationDay"
    static let watchQuickSkipDay = "watchQuickSkipDay"
    static let watchEmergencyNumber = "watchEmergencyNumber"
    /// Taps waiting for the phone: made before the session could carry them.
    static let watchPendingEvents = "watchPendingEvents"

    // MARK: Written by the phone app, read by the Lock Screen dose widget
    //
    // Separate from the `watchTimer*` keys above, which the *watch* writes for its
    // own complication. Sharing them would mean a phone with no paired watch
    // showing nothing, and a paired watch overwriting the phone's own state.

    static let doseTimerSubstance = "doseTimerSubstance"
    static let doseTimerStart = "doseTimerStart"
    static let doseTimerEnd = "doseTimerEnd"
    static let doseTimerComedownEnd = "doseTimerComedownEnd"

    /// Whether a running dose timer names its substance on the Lock Screen, in
    /// the Dynamic Island, in the Lock Screen widget and on the watch face.
    /// Written by the phone app's Privacy & lock setting; read by the Live
    /// Activity extension, which cannot see the app's own defaults, and relayed
    /// to the watch, which writes it into its own suite for its complication.
    /// See `LockScreenTimerPrivacy`.
    static let discreetLockScreenTimer = "discreetLockScreenTimer"

    // MARK: Written by the Control Center controls, read by the phone app

    /// Where the app should navigate on next foreground. A control runs in the
    /// extension's process, so it cannot reach the app's own `UserDefaults`
    /// and has to hand the destination over through the shared suite instead.
    static let pendingDestination = "widgetPendingDestination"

    /// Must equal `NotificationDestination.panic.rawValue` in the app target,
    /// which the extension cannot see. `ControlDestinationTests` asserts it.
    static let destinationPanic = "panic"

    /// The shared suite, or nil when the App Group is unavailable.
    static var suite: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}


/// The one dose the Lock Screen is showing, as it crosses from the app into the
/// widget extension.
///
/// Four bare keys with a shape agreed at both ends is exactly the drift this file
/// exists to prevent, so the shape lives here too and neither end spells a key.
///
/// `comedownEndsAt` is the reason this is not just the check-in timer. The timer
/// is a wellbeing reminder the user picked the length of; the comedown window is
/// what the sources publish, and it routinely outlives the timer by a day. A
/// Lock Screen that goes blank when the reminder ends would be answering the
/// easier question.
struct DoseTimerSnapshot: Equatable, Sendable {
    let substanceName: String
    let startedAt: Date
    let endsAt: Date

    /// When every published figure for this dose has elapsed, where the sources
    /// publish one. Nil is normal: it means nobody publishes an after-effects
    /// window for this substance, not that there is nothing after the timer.
    let comedownEndsAt: Date?

    /// The last moment this dose is worth a place on the Lock Screen.
    var lastMoment: Date {
        max(endsAt, comedownEndsAt ?? endsAt)
    }

    func isWorthShowing(at now: Date) -> Bool {
        now < lastMoment
    }

    /// Whether the check-in window has run out while the published window has not.
    func isInComedown(at now: Date) -> Bool {
        now >= endsAt && now < lastMoment
    }

    /// Reads the snapshot, or nil when there is none or it has expired.
    ///
    /// Expiry is checked on read rather than cleaned up on a schedule, because
    /// nothing wakes the app to do the cleaning. A stale write left behind by a
    /// force-quit must not become a Lock Screen that insists a dose from Tuesday
    /// is still running.
    static func read(from defaults: UserDefaults? = WidgetSharedKey.suite, now: Date = .now) -> DoseTimerSnapshot? {
        guard let defaults else { return nil }
        let name = defaults.string(forKey: WidgetSharedKey.doseTimerSubstance) ?? ""
        let start = defaults.double(forKey: WidgetSharedKey.doseTimerStart)
        let end = defaults.double(forKey: WidgetSharedKey.doseTimerEnd)
        guard !name.isEmpty, start > 0, end > 0 else { return nil }

        let comedown = defaults.double(forKey: WidgetSharedKey.doseTimerComedownEnd)
        let snapshot = DoseTimerSnapshot(
            substanceName: name,
            startedAt: Date(timeIntervalSince1970: start),
            endsAt: Date(timeIntervalSince1970: end),
            comedownEndsAt: comedown > 0 ? Date(timeIntervalSince1970: comedown) : nil
        )
        return snapshot.isWorthShowing(at: now) ? snapshot : nil
    }

    /// Writes the snapshot, or clears it when there is nothing to show.
    static func write(_ snapshot: DoseTimerSnapshot?, to defaults: UserDefaults? = WidgetSharedKey.suite) {
        guard let defaults else { return }
        guard let snapshot else {
            for key in [
                WidgetSharedKey.doseTimerSubstance,
                WidgetSharedKey.doseTimerStart,
                WidgetSharedKey.doseTimerEnd,
                WidgetSharedKey.doseTimerComedownEnd
            ] {
                defaults.removeObject(forKey: key)
            }
            return
        }
        defaults.set(snapshot.substanceName, forKey: WidgetSharedKey.doseTimerSubstance)
        defaults.set(snapshot.startedAt.timeIntervalSince1970, forKey: WidgetSharedKey.doseTimerStart)
        defaults.set(snapshot.endsAt.timeIntervalSince1970, forKey: WidgetSharedKey.doseTimerEnd)
        defaults.set(
            snapshot.comedownEndsAt?.timeIntervalSince1970 ?? 0,
            forKey: WidgetSharedKey.doseTimerComedownEnd
        )
    }
}

/// The two decisions the watch makes on its own, pulled out of
/// `WatchConnectivityReceiver` so they can be tested.
///
/// The watch app is its own target with no test bundle, and standing one up means
/// a watchOS runner in CI for the sake of two rules. These are the two rules —
/// both pure, both consequential — and this file is already a member of every
/// target, so they can be exercised from `ChillMateTests` instead.
///
/// The alternative was leaving the emergency number untested, which is the last
/// thing in the app that should be.
enum WatchLogic {

    /// Which number the watch should dial.
    ///
    /// The order matters and the empty check is the point. The phone relays the
    /// user's real emergency number over `applicationContext`, and the watch keeps
    /// the last one so a cold launch out of range still dials correctly. Falling
    /// back to 112 is right for the Netherlands, Belgium, Germany, France and
    /// Spain and reaches nobody in the United States or Australia, so a stored
    /// value must win over the default — and a *blank* stored value must not,
    /// because an empty string dials nothing at all.
    ///
    /// - Parameters:
    ///   - stored: what the watch last persisted, if anything.
    ///   - relayed: a number arriving from the phone in this update, if any.
    /// - Returns: the number to dial, never empty.
    static func emergencyNumber(stored: String?, relayed: String? = nil) -> String {
        if let relayed, !relayed.trimmingCharacters(in: .whitespaces).isEmpty {
            return relayed
        }
        if let stored, !stored.trimmingCharacters(in: .whitespaces).isEmpty {
            return stored
        }
        return "112"
    }

    /// The day a piece of once-a-day watch state belongs to.
    ///
    /// Whole days since the reference date, in the watch's own calendar. Hydration
    /// counts and the quick-skip flag both reset when this changes.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> Int {
        Int(calendar.startOfDay(for: date).timeIntervalSinceReferenceDate / 86_400)
    }

    /// Whether a once-a-day action is still available.
    ///
    /// Quick skip sends one event per day. `lastSentDay` is 0 on a watch that has
    /// never sent one, which must not collide with a real day key — it cannot,
    /// because day zero is 1 January 2001.
    static func isAvailableToday(lastSentDay: Int, now: Date = .now, calendar: Calendar = .current) -> Bool {
        lastSentDay != dayKey(for: now, calendar: calendar)
    }

    // MARK: Heart readings

    /// How long a heart reading counts as describing now.
    ///
    /// Not a clinical threshold: it is how stale a number may be before "your
    /// heart rate" stops being true of this moment. The phone used to relay the
    /// most recent sample ever recorded, with no time, so the watch could warn
    /// about yesterday's workout, or show a calm reading from hours ago while
    /// the heart it described was racing.
    static let readingIsCurrentFor: TimeInterval = 15 * 60

    /// Whether a reading may be shown as the heart rate right now. A reading
    /// dated a little ahead is allowed for, since the two clocks can disagree.
    static func isCurrent(_ reading: HealthSample?, now: Date = .now) -> Bool {
        guard let reading else { return false }
        let age = now.timeIntervalSince(reading.date)
        return age >= -60 && age <= readingIsCurrentFor
    }

    /// A heart reading carried by a push.
    ///
    /// `nil` when the push said nothing about it, so the watch keeps what it has.
    /// `.some(nil)` when it said there is none, or sent a value without a time,
    /// as an older phone does: a number of unknown age cannot be shown as now.
    static func reading(in context: [String: Any], flag: String, value: String, takenAt: String) -> HealthSample?? {
        guard let has = context[flag] as? Bool else { return nil }
        guard has,
              let number = context[value] as? Double,
              let seconds = context[takenAt] as? TimeInterval else { return .some(nil) }
        return .some(HealthSample(value: number, date: Date(timeIntervalSince1970: seconds)))
    }

    // MARK: Timers

    /// The running timers in a push, soonest to end first. Entries that are
    /// malformed or already over are dropped rather than shown.
    static func timers(from payload: [[String: Any]], now: Date = .now) -> [WatchTimerInfo] {
        payload.compactMap { dict -> WatchTimerInfo? in
            guard
                let idString = dict["id"] as? String,
                let id = UUID(uuidString: idString),
                let substance = dict["substance"] as? String,
                let startedAt = dict["startedAt"] as? TimeInterval,
                let durationHours = dict["durationHours"] as? Double
            else { return nil }
            return WatchTimerInfo(
                id: id,
                substanceName: substance,
                startedAt: Date(timeIntervalSince1970: startedAt),
                durationSeconds: durationHours * 3600
            )
        }
        .filter { $0.endsAt > now }
        .sorted { $0.endsAt < $1.endsAt }
    }

    // MARK: The face

    /// What the complications should show. "Visible timers and complications"
    /// switched off keeps the running timer off the face as well as out of the
    /// app; it used to reach the app only.
    static func faceSnapshot(
        timers: [WatchTimerInfo],
        timersVisible: Bool,
        streakDays: Int,
        score: Int,
        scoreActive: Bool,
        discreet: Bool
    ) -> WatchFaceSnapshot {
        let active = timersVisible ? timers.first : nil
        return WatchFaceSnapshot(
            streakDays: streakDays,
            score: score,
            scoreActive: scoreActive,
            timerSubstance: active?.substanceName ?? "",
            timerStart: active?.startedAt.timeIntervalSince1970 ?? 0,
            timerEnd: active?.endsAt.timeIntervalSince1970 ?? 0,
            discreet: discreet
        )
    }

    // MARK: Taps waiting for the phone

    /// Adds a tap to those waiting for the session. A later discreet check-ins
    /// choice replaces one still waiting, because only the last one counts;
    /// everything else is kept, in order. Two glasses of water are two.
    static func enqueue(_ event: WatchEvent, onto pending: [WatchEvent]) -> [WatchEvent] {
        var result = pending
        if case .discreetCheckIns = event {
            result.removeAll { if case .discreetCheckIns = $0 { true } else { false } }
        }
        result.append(event)
        return result
    }

    static func pendingEvents(in defaults: UserDefaults) -> [WatchEvent] {
        guard let data = defaults.data(forKey: WidgetSharedKey.watchPendingEvents) else { return [] }
        return (try? JSONDecoder().decode([WatchEvent].self, from: data)) ?? []
    }

    static func savePendingEvents(_ events: [WatchEvent], in defaults: UserDefaults) {
        if events.isEmpty {
            defaults.removeObject(forKey: WidgetSharedKey.watchPendingEvents)
        } else if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: WidgetSharedKey.watchPendingEvents)
        }
    }
}

/// A value read from Apple Health, and when it was measured.
struct HealthSample: Equatable, Sendable {
    let value: Double
    let date: Date
}

/// One running dose timer, as the watch has it from the phone.
struct WatchTimerInfo: Identifiable, Equatable, Sendable {
    let id: UUID
    let substanceName: String
    let startedAt: Date
    let durationSeconds: TimeInterval

    var endsAt: Date { startedAt.addingTimeInterval(durationSeconds) }
}

/// Something the watch tells the phone.
///
/// Codable so it can wait on disk: a tap made before the session could carry
/// it used to be dropped while the watch showed it as done.
enum WatchEvent: Codable, Equatable, Sendable {
    case hydrationLogged
    case quickSkipRequested
    case homeSafeReported
    case discreetCheckIns(Bool)

    /// The message as the phone's `WatchConnectivityService.handleInbound` reads it.
    var payload: [String: Any] {
        switch self {
        case .hydrationLogged: ["hydrationLogged": true]
        case .quickSkipRequested: ["quickSkipRequested": true]
        case .homeSafeReported: ["homeSafeReported": true]
        case .discreetCheckIns(let isOn): ["setDiscreetCheckIns": isOn]
        }
    }
}

/// What the watch face's complications show, as the watch app keeps it in the
/// App Group.
///
/// Compared before it is written, so the complications are reloaded only when
/// something on the face changed. Every push from the phone used to reload
/// them, heart-rate relays included, spending a budget the system rations.
struct WatchFaceSnapshot: Equatable {
    var streakDays: Int
    var score: Int
    var scoreActive: Bool
    /// Empty when no timer is shown.
    var timerSubstance: String
    var timerStart: TimeInterval
    var timerEnd: TimeInterval
    var discreet: Bool

    static func read(from defaults: UserDefaults) -> WatchFaceSnapshot {
        WatchFaceSnapshot(
            streakDays: defaults.integer(forKey: WidgetSharedKey.watchStreakDays),
            score: defaults.integer(forKey: WidgetSharedKey.watchScore),
            scoreActive: defaults.bool(forKey: WidgetSharedKey.watchScoreActive),
            timerSubstance: defaults.string(forKey: WidgetSharedKey.watchTimerSubstance) ?? "",
            timerStart: defaults.double(forKey: WidgetSharedKey.watchTimerStart),
            timerEnd: defaults.double(forKey: WidgetSharedKey.watchTimerEnd),
            discreet: defaults.bool(forKey: WidgetSharedKey.discreetLockScreenTimer)
        )
    }

    func write(to defaults: UserDefaults) {
        defaults.set(streakDays, forKey: WidgetSharedKey.watchStreakDays)
        defaults.set(score, forKey: WidgetSharedKey.watchScore)
        defaults.set(scoreActive, forKey: WidgetSharedKey.watchScoreActive)
        defaults.set(timerSubstance, forKey: WidgetSharedKey.watchTimerSubstance)
        defaults.set(timerStart, forKey: WidgetSharedKey.watchTimerStart)
        defaults.set(timerEnd, forKey: WidgetSharedKey.watchTimerEnd)
        defaults.set(discreet, forKey: WidgetSharedKey.discreetLockScreenTimer)
    }
}

/// Whether the Lock Screen timer says what was taken.
///
/// A running timer used to show the substance by name on the Lock Screen and in
/// the Dynamic Island — "GHB 1:12:40" on a phone face-up on a table, readable by
/// anyone near it, whatever the discreet notification setting said. Discreet, it
/// says "Timer", and "Winding down" where it would have said "After effects".
///
/// Deciding the words is left to each surface, whose catalog they live in; this
/// only carries the choice across the process boundary.
enum LockScreenTimerPrivacy {
    static func isDiscreet(in defaults: UserDefaults? = WidgetSharedKey.suite) -> Bool {
        defaults?.bool(forKey: WidgetSharedKey.discreetLockScreenTimer) ?? false
    }
}
