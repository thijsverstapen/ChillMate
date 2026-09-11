import Foundation

/// The sheet somebody hands to a GP, a sexual-health service, a therapist or an
/// addiction-care worker.
///
/// Two things were wrong with it where it used to live, inside
/// `ProfessionalHelperBridgeView` as a `private enum`.
///
/// It was written in English. Every heading and every label — "Profile", "Past 90
/// days", "Name:", "Not set" — was a bare Swift string, so a Dutch user printed
/// an English sheet for a Dutch doctor. Only a handful of values went through
/// `String(localized:)`, which made the result worse than either extreme: an
/// English form with three Dutch words in it.
///
/// And it was private, so the one document in the app that gets read by a
/// professional and acted on had no tests at all.
///
/// It reports what the user logged and nothing else. No interpretation, no
/// severity, no advice — the last line says so in the sheet itself, because a
/// clinician reading a tidy table of counts should be told what those counts are
/// and are not.
enum HelperSummary {

    /// The window every figure here is counted over.
    static let windowDays = 90

    static func text(
        profile: UserProfile?,
        entries: [NightEntry],
        timers: [DrugDoseTimerRecord],
        stiTests: [STDTestRecord],
        riskChecks: [RiskCheckRecord],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let cutoff = calendar.date(byAdding: .day, value: -windowDays, to: now) ?? .distantPast
        let notSet = String(localized: "Not set")

        let recentEntries = entries.filter { $0.date >= cutoff }
        let recentTimers = timers.filter { $0.startedAt >= cutoff }
        let risky = recentEntries.filter { !$0.skippedNight && $0.hadSex && !$0.substances.isEmpty }
        let memoryGaps = recentEntries.filter(\.reportedMemoryGap)
        // Windowed like every other figure under the heading. These two were
        // counted over the whole array, so they reported an all-time total under a
        // 90 day label, and the array itself is a limited fetch, so the number
        // silently stopped moving once the user passed that many tests. A
        // clinician reads this sheet and has no way to see either problem.
        let recentTests = stiTests.filter { $0.testDate >= cutoff }
        let positiveTests = recentTests.filter(\.hasPositiveResult)
        let recentChecks = riskChecks.filter { $0.createdAt >= cutoff }

        let substances = ChillInsightCalculator.substanceCounts(entries: recentEntries)
            .prefix(6).map { "\($0.label) (\($0.count))" }.joined(separator: ", ")
        let triggers = ChillInsightCalculator.triggerCounts(entries: recentEntries)
            .prefix(6).map { "\($0.label) (\($0.count))" }.joined(separator: ", ")
        let medication = profile?.medications
            .map { "\($0.name) \($0.timingSummary)" }
            .joined(separator: "; ") ?? ""

        let prep: String
        if profile?.isOnPrEP == true {
            let schedule = profile?.prepSchedule ?? ""
            prep = schedule.isEmpty
                ? String(localized: "Yes")
                : String(localized: "Yes, \(schedule)")
        } else {
            prep = String(localized: "No, or not set")
        }

        var sections: [String] = []

        sections.append("""
        \(String(localized: "ChillMate private helper summary"))
        \(String(localized: "Generated: \(now.formatted(date: .abbreviated, time: .shortened))"))
        """)

        sections.append("""
        \(String(localized: "Profile"))
        \(String(localized: "Name")): \(profile?.name.isEmpty == false ? profile!.name : notSet)
        \(String(localized: "Age")): \(profile?.calculatedAge.description ?? notSet)
        \(String(localized: "Sex")): \(profile?.sex ?? notSet)
        \(String(localized: "PrEP")): \(prep)
        \(String(localized: "Medication")): \(medication.isEmpty ? notSet : medication)
        """)

        sections.append("""
        \(String(localized: "Past \(windowDays) days"))
        \(String(localized: "Chills logged")): \(recentEntries.filter { !$0.skippedNight }.count)
        \(String(localized: "Logs with sex and substances")): \(risky.count)
        \(String(localized: "Check-in records")): \(recentTimers.count)
        \(String(localized: "Continued-after-pause records")): \(recentTimers.filter { $0.redoseDecision == RedoseDecision.redosed.rawValue }.count)
        \(String(localized: "Memory gaps reported")): \(memoryGaps.count)
        \(String(localized: "STI tests saved")): \(recentTests.count)
        \(String(localized: "Positive STI tests")): \(positiveTests.count)
        """)

        // These were fetched, passed in, and then dropped on the floor: the old
        // builder took a `riskChecks` parameter and never read it. Somebody who
        // had checked every combination they took got a sheet that said nothing
        // about it, which is exactly the thing a prescriber would want to know.
        sections.append("""
        \(String(localized: "Combination checks"))
        \(String(localized: "Checks run")): \(recentChecks.count)
        \(String(localized: "Medication checked")): \(checkedMedication(in: recentChecks, fallback: notSet))
        """)

        sections.append("""
        \(String(localized: "Patterns"))
        \(String(localized: "Substances")): \(substances.isEmpty ? String(localized: "Not enough data") : substances)
        \(String(localized: "Triggers")): \(triggers.isEmpty ? String(localized: "Not enough data") : triggers)
        """)

        sections.append("""
        \(String(localized: "Talking points"))
        - \(String(localized: "I want help understanding my patterns without judgment."))
        - \(String(localized: "I want to discuss sleep, substances, sex, consent, medication interactions, PrEP/PEP/STI care, or recovery goals."))
        - \(String(localized: "I understand this export is self-reported app data and not a diagnosis."))
        """)

        return sections.joined(separator: "\n\n")
    }

    /// The headings the sheet is built from, so a test can assert they resolve
    /// through the catalog rather than assert an English literal — which would
    /// pass trivially in the other four languages while proving nothing.
    static var headingsForTesting: [String] {
        [
            String(localized: "Profile"),
            String(localized: "Past \(windowDays) days"),
            String(localized: "Combination checks"),
            String(localized: "Patterns"),
            String(localized: "Talking points")
        ]
    }

    static var sectionTitleForTesting: String {
        String(localized: "Combination checks")
    }

    /// The distinct medications the user actually ran through the combination
    /// checker, which is not the same list as the one on their profile: this is
    /// what they were unsure enough about to look up.
    private static func checkedMedication(in checks: [RiskCheckRecord], fallback: String) -> String {
        var seen = Set<String>()
        var names: [String] = []
        for check in checks {
            let text = check.medicationText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let key = text.lowercased()
            if seen.insert(key).inserted {
                names.append(text)
            }
        }
        return names.isEmpty ? fallback : names.joined(separator: "; ")
    }
}
