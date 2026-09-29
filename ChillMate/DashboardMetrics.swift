import SwiftUI
import ChillMateCore

// What Home computes from the logged nights: the daily score, the streak, and
// the next thing worth suggesting. No views here.

struct DashboardMetrics {
    let trackedCount: Int
    let skippedCount: Int
    let substanceCount: Int
    let averageSleepHours: Double?
    let healthWarningCount: Int
    let recentRiskCount: Int
    let previousRiskCount: Int
    let pepConcernEntry: NightEntry?
    let changeReasonCounts: [(reason: ChangeReason, count: Int)]
    let recoveryStreakDays: Int
    let dailyScore: DailyRecoveryScore

    var shouldShowWhatChanged: Bool {
        recentRiskCount >= 3 && recentRiskCount > previousRiskCount
    }

    var realityCheckActive: Bool {
        let recentSessionsWithSubstances = healthWarningCount
        return healthWarningCount > 3 || (dailyScore.isActive && dailyScore.value < 30) || recentSessionsWithSubstances >= 10
    }

    init(entries: [NightEntry], profiles: [UserProfile], calendar: Calendar, latestHRVms: Double = 0, latestRestingBPM: Double = 0) {
        let cutoffDate = calendar.date(byAdding: .month, value: -3, to: .now) ?? .now
        var trackedCount = 0
        var skippedCount = 0
        var substanceCount = 0
        var sleepTotal = 0.0
        var sleepCount = 0
        var lastSubstanceDate: Date?
        let now = Date.now
        let recentRiskCutoff = calendar.date(byAdding: .day, value: -21, to: now) ?? now
        let previousRiskCutoff = calendar.date(byAdding: .day, value: -42, to: now) ?? now
        var recentRiskCount = 0
        var previousRiskCount = 0
        var pepConcernEntry: NightEntry?
        var reasonCounts: [ChangeReason: Int] = [:]

        for entry in entries {
            let substances = entry.substances
            let hasSubstances = !substances.isEmpty

            if !entry.skippedNight, hasSubstances {
                if lastSubstanceDate.map({ entry.date > $0 }) ?? true {
                    lastSubstanceDate = entry.date
                }
            }

            if entry.hadSex, !entry.skippedNight, hasSubstances {
                if entry.date >= recentRiskCutoff {
                    recentRiskCount += 1
                    for reason in entry.changeReasons {
                        reasonCounts[reason, default: 0] += 1
                    }
                } else if entry.date >= previousRiskCutoff {
                    previousRiskCount += 1
                }
            }

            if entry.suggestsPEPConcern, entry.pepDeadline > now, pepConcernEntry == nil || entry.startDate > pepConcernEntry!.startDate {
                pepConcernEntry = entry
            }

            guard entry.date >= cutoffDate else {
                continue
            }

            if entry.isTrackedEvent {
                trackedCount += 1
                substanceCount += substances.count
            }

            if entry.skippedNight {
                skippedCount += 1
            }

            if entry.sleptYet {
                sleepTotal += entry.sleepHours
                sleepCount += 1
            }
        }

        self.trackedCount = trackedCount
        self.skippedCount = skippedCount
        self.substanceCount = substanceCount
        averageSleepHours = sleepCount > 0 ? sleepTotal / Double(sleepCount) : nil
        healthWarningCount = recentRiskCount
        self.recentRiskCount = recentRiskCount
        self.previousRiskCount = previousRiskCount
        self.pepConcernEntry = pepConcernEntry
        changeReasonCounts = reasonCounts
            .map { (reason: $0.key, count: $0.value) }
            .sorted { first, second in
                first.count == second.count ? first.reason.rawValue < second.reason.rawValue : first.count > second.count
            }

        let today = calendar.startOfDay(for: .now)
        if let lastSubstanceDate {
            let lastDay = calendar.startOfDay(for: lastSubstanceDate)
            recoveryStreakDays = max(0, calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0)
        } else {
            let profileStart = profiles.first?.createdAt ?? today
            let startDay = calendar.startOfDay(for: profileStart)
            recoveryStreakDays = max(0, calendar.dateComponents([.day], from: startDay, to: today).day ?? 0)
        }

        dailyScore = DailyRecoveryScore(entries: entries, recoveryStreakDays: recoveryStreakDays, calendar: calendar, latestHRVms: latestHRVms, latestRestingBPM: latestRestingBPM)
    }
}

struct DailyRecoveryScore {
    let isActive: Bool
    let value: Int
    let label: String
    let emoji: String
    let factors: [Factor]

    var displayValue: Int {
        isActive ? value : 88
    }

    /// `entries` arrives sorted by date descending, so the latest non-skipped row is
    /// simply the first one (no scan needed). The substance check still has to look
    /// at rows until it finds one, but stops there instead of always walking the
    /// whole table.
    ///
    /// `entry.substances` is not a stored property: each read filters, sorts and
    /// dedupes a SwiftData relationship that may fault to disk. The previous loop
    /// called it once per entry and then `substancePoints` called it twice more on
    /// the latest row, so a several-hundred-entry store did thousands of redundant
    /// sorts per dashboard render.
    /// `latestRestingBPM` is shown, not scored.
    ///
    /// 4.3.0 added the HealthKit read for resting heart rate and respiratory rate
    /// and then consumed neither: `latestRestingHeartRate()` had no caller
    /// anywhere in the app. The release notes said the app reads them as recovery
    /// signals, and it read them into nothing.
    ///
    /// It joins the factor list rather than the arithmetic on purpose. Folding a
    /// new term into the score would silently move every existing user's number
    /// with no explanation, and what a raised resting heart rate means the morning
    /// after is context a person can read, not a coefficient.
    init(entries: [NightEntry], recoveryStreakDays: Int, calendar: Calendar, latestHRVms: Double = 0, latestRestingBPM: Double = 0) {
        let latest = entries.first { !$0.skippedNight }
        // Read once and pass down, rather than re-reading the getter.
        let latestSubstances = latest?.substances ?? []

        var hasEverLoggedSubstances = !latestSubstances.isEmpty
        if !hasEverLoggedSubstances {
            for entry in entries where !entry.skippedNight {
                if entry.hasSubstances {
                    hasEverLoggedSubstances = true
                    break
                }
            }
        }

        if !hasEverLoggedSubstances {
            isActive = false
            value = 0
            label = String(localized: "not active")
            emoji = "😄"
            factors = [
                Factor(name: String(localized: "Daily score"), caption: String(localized: "make a substance-related log to activate")),
                Factor(name: String(localized: "Sleep"), caption: String(localized: "starts after activation")),
                Factor(name: String(localized: "Hydration"), caption: String(localized: "starts after activation")),
                Factor(name: String(localized: "Food"), caption: String(localized: "starts after activation")),
                Factor(name: String(localized: "Substances"), caption: String(localized: "no substance use logged")),
                Factor(name: String(localized: "Streak"), caption: "\(recoveryStreakDays) d"),
                Factor(name: String(localized: "Symptoms"), caption: String(localized: "starts after activation")),
                Factor(name: String(localized: "HRV"), caption: latestHRVms > 0 ? "\(Int(latestHRVms)) ms" : String(localized: "not available")),
            Factor(name: String(localized: "Resting heart rate"), caption: latestRestingBPM > 0 ? "\(Int(latestRestingBPM)) bpm" : String(localized: "not available")),
                Factor(name: String(localized: "Resting heart rate"), caption: latestRestingBPM > 0 ? "\(Int(latestRestingBPM)) bpm" : String(localized: "not available"))
            ]
            return
        }

        let sleep = Self.sleepPoints(latest)
        let hydration = latest?.aftercareDrankWater == true ? 12 : 5
        let food = latest?.aftercareAteFood == true ? 10 : 4
        let substance = Self.substancePoints(latest, substances: latestSubstances)
        // nil when there is no latest entry, which is what symptomPoints scores
        // differently from "an entry with no symptoms".
        let latestSymptoms: [AftercareSymptom]? = latest?.aftercareSymptoms
        let anxiety = Self.anxietyPoints(latest, symptoms: latestSymptoms ?? [])
        let recovery = Int(min(18.0, (log(Double(max(1, recoveryStreakDays)) + 1) / log(30)) * 18))
        let symptoms = Self.symptomPoints(latestSymptoms)
        let hrv = Self.hrvPoints(latestHRVms)
        let total = min(100, max(0, sleep + hydration + food + substance + anxiety + recovery + symptoms + hrv))

        isActive = true
        value = total
        label = Self.label(for: total)
        emoji = Self.emoji(for: total)
        factors = [
            Factor(name: String(localized: "Sleep"), caption: latest?.sleptYet == true ? "\(latest?.sleepHours.formatted(.number.precision(.fractionLength(0...1))) ?? "0") h" : String(localized: "not logged")),
            Factor(name: String(localized: "Hydration"), caption: latest?.aftercareDrankWater == true ? String(localized: "checked") : String(localized: "unknown")),
            Factor(name: String(localized: "Food"), caption: latest?.aftercareAteFood == true ? String(localized: "checked") : String(localized: "unknown")),
            Factor(name: String(localized: "Substances"), caption: latestSubstances.isEmpty ? String(localized: "clear") : String(localized: "logged")),
            Factor(name: String(localized: "Anxiety"), caption: Self.anxietyCaption(latest, symptoms: latestSymptoms ?? [])),
            Factor(name: String(localized: "Streak"), caption: "\(recoveryStreakDays) d"),
            Factor(name: String(localized: "Symptoms"), caption: (latestSymptoms ?? []).isEmpty ? String(localized: "none") : String(localized: "\((latestSymptoms ?? []).count) selected")),
            Factor(name: String(localized: "HRV"), caption: latestHRVms > 0 ? "\(Int(latestHRVms)) ms" : String(localized: "not available")),
            Factor(name: String(localized: "Resting heart rate"), caption: latestRestingBPM > 0 ? "\(Int(latestRestingBPM)) bpm" : String(localized: "not available"))
        ]
    }

    struct Factor {
        let name: String
        let caption: String
    }

    private static func sleepPoints(_ entry: NightEntry?) -> Int {
        guard let entry, entry.sleptYet else {
            return 7
        }

        switch entry.sleepHours {
        case 7...:
            return 18
        case 6..<7:
            return 16
        case 4..<6:
            return 11
        case 2..<4:
            return 6
        default:
            return 2
        }
    }

    /// Takes the already-read substance list instead of reading the getter twice.
    private static func substancePoints(_ entry: NightEntry?, substances: [String]) -> Int {
        guard entry != nil else {
            return 12
        }

        if substances.isEmpty {
            return 15
        }

        return max(2, 14 - (substances.count * 4))
    }

    private static func anxietyPoints(_ entry: NightEntry?, symptoms: [AftercareSymptom]) -> Int {
        guard let entry else {
            return 7
        }

        let mood = AftercareMood(rawValue: entry.aftercareMood) ?? .okay
        if symptoms.contains(.anxious) || mood == .anxious || mood == .overwhelmed {
            return 2
        }

        if mood == .low {
            return 4
        }

        return 10
    }

    /// Takes the already-decoded symptom list. `aftercareSymptoms` JSON-decodes on
    /// every read, and this was one of three reads of it per score.
    private static func symptomPoints(_ symptoms: [AftercareSymptom]?) -> Int {
        guard let symptoms else {
            return 8
        }

        return max(0, 12 - (symptoms.count * 2))
    }

    private static func anxietyCaption(_ entry: NightEntry?, symptoms: [AftercareSymptom]) -> String {
        guard let entry else {
            return "unknown"
        }

        let mood = AftercareMood(rawValue: entry.aftercareMood) ?? .okay
        return symptoms.contains(.anxious) ? "selected" : mood.rawValue.lowercased()
    }

    private static func hrvPoints(_ ms: Double) -> Int {
        guard ms > 0 else { return 5 }
        switch ms {
        case 60...:
            return 12
        case 40..<60:
            return 9
        case 25..<40:
            return 6
        default:
            return 3
        }
    }

    private static func label(for value: Int) -> String {
        switch value {
        case 0..<35:
            String(localized: "needs care")
        case 35..<60:
            String(localized: "gentle pace")
        case 60..<80:
            String(localized: "recovering")
        default:
            String(localized: "steady")
        }
    }

    private static func emoji(for value: Int) -> String {
        switch value {
        case 0..<35:
            "😟"
        case 35..<60:
            "😐"
        case 60..<80:
            "🙂"
        default:
            "😄"
        }
    }
}

struct SmartNextAction {
    enum Destination {
        case log
        case calendar
        case care(CareToolPage)
    }

    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let destination: Destination

    var accessibilityLabel: String {
        "\(title). \(detail)"
    }

    init(
        entries: [NightEntry],
        plans: [SaferSessionPlan],
        timers: [DrugDoseTimerRecord],
        tests: [STDTestRecord],
        journalEntries: [JournalEntry],
        metrics: DashboardMetrics,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        if let timer = timers.first(where: { $0.endsAt > now }) {
            title = String(localized: "Timer running")
            detail = String(localized: "\(timer.localizedSubstanceName) is still active. Check the timer before deciding anything else.")
            symbol = "timer"
            tint = Color.chillIconAmber
            destination = .care(.drugTimers)
            return
        }

        if let plan = plans.first(where: { $0.endingDate > now }) {
            title = String(localized: "Plan in progress")
            detail = String(localized: "Your plan ends around \(plan.endingDate.formatted(date: .omitted, time: .shortened)). Open it for check-ins and reminders.")
            symbol = "checkmark.shield.fill"
            tint = Color.chillMint
            destination = .care(.saferPlanning)
            return
        }

        if let pepEntry = metrics.pepConcernEntry {
            title = String(localized: "PEP time window")
            detail = String(localized: "A recent log may need quick sexual-health advice before \(pepEntry.pepDeadline.formatted(date: .abbreviated, time: .shortened)).")
            symbol = "cross.case.fill"
            tint = Color.chillIconRed
            destination = .care(.emergency)
            return
        }

        if let pendingTest = tests.first(where: { $0.resultsDueDate <= now && Self.hasPendingResult($0) }) {
            title = String(localized: "STI results due")
            detail = String(localized: "Your test from \(pendingTest.testDate.formatted(date: .abbreviated, time: .omitted)) is ready to update.")
            symbol = "cross.case.fill"
            tint = Color.chillIconTeal
            destination = .care(.stdTests)
            return
        }

        if let entry = entries.first(where: { Self.needsAftercare($0, now: now) }) {
            title = String(localized: "Morning-after check-in")
            detail = String(localized: "Check how you feel after \(entry.startDate.formatted(date: .abbreviated, time: .shortened)).")
            symbol = "heart.text.square.fill"
            tint = Color.chillIconPink
            destination = .care(.aftercare)
            return
        }

        if journalEntries.first(where: { calendar.isDateInToday($0.date) }) != nil {
            title = String(localized: "Today is saved")
            detail = String(localized: "You already have a journal entry for today. Review your calendar when you want context.")
            symbol = "book.closed.fill"
            tint = Color.chillIconPurple
            destination = .calendar
            return
        }

        if entries.first(where: { calendar.isDateInToday($0.date) }) == nil {
            title = String(localized: "Ready when you are")
            detail = String(localized: "No Chill has been logged today. Add one only if there is something worth saving.")
            symbol = "plus.circle.fill"
            tint = Color.chillSecondaryBlue
            destination = .log
            return
        }

        title = String(localized: "Open your timeline")
        detail = String(localized: "See today next to earlier logs, timers, plans, STI tests, and journal notes.")
        symbol = "calendar"
        tint = Color.chillSecondaryBlue
        destination = .calendar
    }

    private static func hasPendingResult(_ test: STDTestRecord) -> Bool {
        test.oralResult == STDResultStatus.pending.rawValue ||
        test.genitalResult == STDResultStatus.pending.rawValue ||
        test.analResult == STDResultStatus.pending.rawValue
    }

    private static func needsAftercare(_ entry: NightEntry, now: Date) -> Bool {
        guard entry.isTrackedEvent, entry.aftercareCompletedAt == nil else {
            return false
        }

        let age = now.timeIntervalSince(entry.endDate)
        return age >= 6 * 60 * 60 && age <= 36 * 60 * 60
    }
}
