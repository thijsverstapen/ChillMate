import SwiftData
import PhotosUI
import SwiftUI
import WidgetKit
import ChillMateCore

struct DashboardView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @AppStorage(DefaultsKey.lastDailyRecoveryScore) private var lastDailyRecoveryScore = 42
    @AppStorage(DefaultsKey.lastKnownHRVms) private var lastKnownHRVms: Double = 0
    @AppStorage(DefaultsKey.lastKnownRestingBPM) private var lastKnownRestingBPM: Double = 0
    @AppStorage(DefaultsKey.weeklyDigestEnabled) private var weeklyDigestEnabled = false
    @AppStorage(DefaultsKey.healthKitHRVReadEnabled) private var healthKitHRVReadEnabled = false
    @AppStorage(DefaultsKey.healthKitHeartRateReadEnabled) private var healthKitHeartRateReadEnabled = false
    @AppStorage(DefaultsKey.reductionGoalSessions) private var reductionGoalSessions = 0
    @AppStorage(DefaultsKey.reductionGoalCountSubstanceOnly) private var reductionGoalCountSubstanceOnly = true
    @AppStorage(DefaultsKey.notificationsEnabled) private var notificationsEnabled = false
    @Query(ChillMateQueries.dashboardEntries) private var entries: [NightEntry]
    @Query(ChillMateQueries.profile) private var profiles: [UserProfile]
    @Query(ChillMateQueries.recentPlansByCreation) private var plans: [SaferSessionPlan]
    @Query(ChillMateQueries.recentTimers) private var timers: [DrugDoseTimerRecord]
    @Query(ChillMateQueries.recentTests) private var tests: [STDTestRecord]
    @Query(ChillMateQueries.recentJournalEntries) private var journalEntries: [JournalEntry]

    @State private var isShowingLogSheet = false
    @State private var isShowingCalendar = false
    @State private var hydrationLoggedToday = false
    @State private var quickSkipHaptic = 0
    @Binding var careNavPath: [CareToolPage]
    let openCalendarTab: (() -> Void)?

    init(careNavPath: Binding<[CareToolPage]>, openCalendarTab: (() -> Void)? = nil) {
        self._careNavPath = careNavPath
        self.openCalendarTab = openCalendarTab
    }

    private var calendar: Calendar { .current }

    /// Metrics are recomputed in `.task(id:)` rather than lazily inside `body`.
    ///
    /// The previous cache keyed on `entries.count`, so editing an existing night
    /// (changing substances, logging sleep, completing aftercare) left the count
    /// unchanged and the dashboard kept showing stale numbers: stale daily score,
    /// stale streak, stale PEP countdown, and stale data pushed to the widget and
    /// the watch. It only refreshed when a row was added or deleted.
    ///
    /// It also wrote `@State` from a computed property read during `body`,
    /// deferring the write into `Task { @MainActor }` to dodge the "Modifying state
    /// during view update" warning. Because the write landed after the pass, a
    /// second read in the same pass (`shouldEscalateHelp`) still saw an empty cache
    /// and recomputed everything a second time: two full scans over every entry.
    @State private var cachedMetrics: DashboardMetrics?

    /// Changes whenever anything the metrics depend on changes. `NightEntry`
    /// exposes `contentVersion` as a computed value with two halves: a stored
    /// counter that its blob-backed setters bump, and a fold of the plain stored
    /// attributes taken at read time. Edits therefore register even though the row
    /// count is identical, including the ones no setter ever sees: sleep,
    /// hydration, food, mood, and the skipped and sex flags.
    ///
    /// Because that second half is a fold and not a count, the sum below is a
    /// fingerprint rather than a tally. It is not monotonic and can move in either
    /// direction, so it must only ever be compared for equality, never for order.
    private var metricsInvalidationKey: MetricsKey {
        MetricsKey(
            entryCount: entries.count,
            contentVersion: entries.reduce(into: 0) { $0 &+= $1.contentVersion },
            profileCount: profiles.count,
            hrv: lastKnownHRVms,
            restingBPM: lastKnownRestingBPM
        )
    }

    /// Cached value when it is current, freshly built when it is not. Never writes
    /// state, so it is safe to read as many times per pass as needed.
    private var dashboardMetrics: DashboardMetrics {
        cachedMetrics ?? DashboardMetrics(
            entries: entries,
            profiles: profiles,
            calendar: calendar,
            latestHRVms: lastKnownHRVms,
            latestRestingBPM: lastKnownRestingBPM
        )
    }

    struct MetricsKey: Equatable {
        let entryCount: Int
        let contentVersion: Int
        let profileCount: Int
        let hrv: Double
        let restingBPM: Double
    }

    @ViewBuilder
    private func careDestination(_ page: CareToolPage) -> some View {
        careLeaf(page)
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .chillMinimizingNavigationBar()
    }

    @ViewBuilder
    private func careLeaf(_ page: CareToolPage) -> some View {
        switch page {
        case .safetyAutopilot: SafetyAutopilotView()
        case .saferPlanning: SaferSessionPlanView()
        case .stdTests: STDTestsView()
        case .drugTimers: DrugTimerView()
        case .emergency: EmergencyNetherlandsView()
        case .panicSupport: PanicSupportView()
        case .drugInfo: DrugInfoView()
        case .aftercare: AftercareView()
        case .combinationRisk: CombinationRiskCheckerView()
        case .consentBoundaries: ConsentBoundariesView()
        case .recoveryMode: RecoveryModeView()
        case .privateInsights: PrivateInsightsView()
        case .helperBridge: ProfessionalHelperBridgeView()
        case .drugChecking: DrugCheckingEducationView()
        case .safeRoute: SafeRouteHomeView()
        case .weeklyReflection: WeeklyReflectionView()
        case .groupBefore, .groupDuring, .groupAfter, .groupPatterns:
            if let group = CareToolGroup.homeGroups.first(where: { $0.page == page }) {
                CareToolGroupView(group: group) { careNavPath.append($0) }
            }
        }
    }

    /// The panic control now lives in `PanicHideControl.swift` and is on all three
    /// tabs. It was only ever here.
    @ToolbarContentBuilder
    private var panicToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            PanicHideButton()
        }
    }

    /// The scrolling column of cards under the header.
    ///
    /// Pulled out of `body`, which ran past 200 lines. Takes `metrics` as a
    /// parameter rather than re-reading `dashboardMetrics`, so the value the whole
    /// pass renders from is computed exactly once.
    @ViewBuilder
    private func mainColumn(metrics: DashboardMetrics) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            GetHelpNowBar(escalated: shouldEscalateHelp(metrics)) {
                careNavPath.append(.panicSupport)
            }

            TodayFocusCard(
                entries: entries,
                plans: plans,
                timers: timers,
                tests: tests,
                journalEntries: journalEntries,
                metrics: metrics,
                log: { isShowingLogSheet = true },
                openCare: { careNavPath.append($0) },
                openCalendar: openCalendar
            )

            MetricsGrid(
                trackedCount: metrics.trackedCount,
                skippedCount: metrics.skippedCount,
                substanceCount: metrics.substanceCount,
                averageSleepHours: metrics.averageSleepHours,
                dailyScore: metrics.dailyScore,
                recoveryStreakDays: metrics.recoveryStreakDays,
                openRecoveryStreak: openCalendar
            )

            situationalCards(metrics: metrics)

            MomentGroupsSection(
                groups: orderedToolGroups,
                highlightedPage: currentMoment?.page,
                highlightHint: currentMoment?.hint
            ) { page in
                careNavPath.append(page)
            }

            if hydrationLoggedToday {
                hydrationBadge
            }

            MedicalSafetyDisclaimerCard(compact: true)
        }
    }

    /// Cards that appear only when the underlying condition holds.
    @ViewBuilder
    private func situationalCards(metrics: DashboardMetrics) -> some View {
        if let pepEntry = metrics.pepConcernEntry {
            PEPCountdownCard(entry: pepEntry)
        }

        if metrics.healthWarningCount > 3 {
            HealthWarningCard(count: metrics.healthWarningCount)
        }

        if reductionGoalSessions > 0 {
            ReductionGoalProgressCard(
                goal: reductionGoalSessions,
                substanceOnly: reductionGoalCountSubstanceOnly,
                entries: entries
            )
        }

        if metrics.shouldShowWhatChanged {
            WhatChangedPatternCard(
                recentCount: metrics.recentRiskCount,
                previousCount: metrics.previousRiskCount,
                reasonCounts: metrics.changeReasonCounts
            )
        }

        if metrics.realityCheckActive {
            RealityCheckCard {
                careNavPath.append(.panicSupport)
            }
        }
    }

    private var hydrationBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.chillSecondaryBlue)
            Text("Water logged today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: 22, tint: Color.chillSecondaryBlue.opacity(0.10))
    }

    var body: some View {
        let metrics = dashboardMetrics

        NavigationStack(path: $careNavPath) {
            ZStack {
                DashboardBackdrop(score: metrics.dailyScore.displayValue)

                GeometryReader { proxy in
                    let contentWidth = max(320, proxy.size.width - 40)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            HeaderSummaryView(width: proxy.size.width, dailyScore: metrics.dailyScore)

                            mainColumn(metrics: metrics)
                                .frame(width: contentWidth, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.top, 18)
                        }
                        .padding(.bottom, 136)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle(Text(verbatim: ""))
            .toolbarBackground(.hidden, for: .navigationBar)
            .task(id: metricsInvalidationKey) {
                // Rebuilt here rather than lazily inside `body`, so the work happens
                // once per actual change instead of once per read, and no state is
                // written during a view update.
                cachedMetrics = DashboardMetrics(
                    entries: entries,
                    profiles: profiles,
                    calendar: calendar,
                    latestHRVms: lastKnownHRVms,
                    latestRestingBPM: lastKnownRestingBPM
                )
            }
            .onAppear {
                lastDailyRecoveryScore = metrics.dailyScore.displayValue
                updateWidgetData(metrics: metrics)
                hydrationLoggedToday = HydrationLog.isLoggedToday
            }
            .onChange(of: metrics.dailyScore.displayValue) { _, value in
                lastDailyRecoveryScore = value
                updateWidgetData(metrics: metrics)
            }
            .onChange(of: metrics.pepConcernEntry?.id) { _, entryID in
                if let entry = metrics.pepConcernEntry, notificationsEnabled {
                    services.notifications.schedulePEPWindowReminders(entry: entry)
                } else {
                    services.notifications.clearPEPWindowReminders()
                }
            }
            .modifier(WatchRelayObservers(
                quickSkip: quickSkip,
                logHydration: {
                    // Persist the watch's hydration tap (the relay was previously
                    // unobserved) and reflect it immediately.
                    HydrationLog.markLoggedNow()
                    hydrationLoggedToday = true
                }
            ))
            .task(id: healthKitHRVReadEnabled) {
                guard healthKitHRVReadEnabled else { return }
                if let hrv = try? await services.health.latestHRV() {
                    lastKnownHRVms = hrv
                    // The watch needs this too: paired with heart rate it is what
                    // separates dancing from strain.
                    services.watch.sendLatestHRV(hrv)
                }
            }
            .task(id: healthKitHeartRateReadEnabled) {
                // The resting read has existed since 4.3.0 and had no caller.
                guard healthKitHeartRateReadEnabled else { return }
                if let resting = try? await services.health.latestRestingHeartRate() {
                    lastKnownRestingBPM = resting
                }
            }
            .task(id: healthKitHeartRateReadEnabled) {
                // Relay the latest resting/most-recent heart rate to the Watch so
                // its elevated-heart-rate warning card has data. Only runs when the
                // user has already granted heart-rate reads (no surprise prompt).
                guard healthKitHeartRateReadEnabled else { return }
                let bpm = (try? await services.health.latestHeartRate()) ?? nil
                services.watch.sendLatestHeartRate(bpm)
            }
            .toolbar { panicToolbarItem }
            .safeAreaInset(edge: .bottom) {
                FloatingLogBar(add: {
                    isShowingLogSheet = true
                }, skip: {
                    quickSkip()
                }, isTonightLogged: entries.contains { Calendar.current.isDate($0.date, inSameDayAs: Date.now) })
            }
            .navigationDestination(for: CareToolPage.self) { page in
                careDestination(page)
            }
            .modifier(DashboardCovers(
                isShowingLogSheet: $isShowingLogSheet,
                isShowingCalendar: $isShowingCalendar
            ))
            .sensoryFeedback(.success, trigger: quickSkipHaptic)
        }
    }

    private func openCalendar() {
        if let openCalendarTab {
            openCalendarTab()
        } else {
            isShowingCalendar = true
        }
    }

    /// The current session "moment", used to promote the most relevant tool group to
    /// the top of Home and annotate it with a live hint. `nil` ⇒ the calm default
    /// order (which matches the mockup exactly).
    private var currentMoment: (page: CareToolPage, hint: String)? {
        let now = Date.now

        // Mid-session: a dose timer is still counting down.
        if timers.contains(where: { $0.endsAt > now }) {
            return (.groupDuring, String(localized: "A dose timer is running"))
        }

        // Morning after a tracked event whose aftercare check-in is still open.
        if entries.contains(where: { entryNeedsAftercare($0, now: now) }) {
            return (.groupAfter, String(localized: "Check in on last night"))
        }

        // The small hours and the evening are not the same moment, and treating
        // them as one told everybody reading this at 2am to go and plan their
        // night. At 2am the night is happening: the useful tools are the timer,
        // the route home and panic support, not a checklist for later.
        if NightMode.isActive(at: now) {
            return (.groupDuring, String(localized: "It's late. Here if you need it"))
        }

        // Evening: most people set up before heading out.
        if NightMode.isPreNight(at: now) {
            return (.groupBefore, String(localized: "Heading out? Set up first"))
        }

        return nil
    }

    /// `CareToolGroup.homeGroups`, but with the current moment moved to the top.
    ///
    /// A Focus filter beats the app's own guess. The app infers the moment from
    /// logs and the clock, which is a reasonable guess and still a guess; someone
    /// who has told iOS they are going out has stated it outright, and a stated
    /// fact should win over an inference.
    private var orderedToolGroups: [CareToolGroup] {
        let base = CareToolGroup.homeGroups
        let focusLead: CareToolPage? = UserDefaults.standard.bool(forKey: DefaultsKey.focusSessionMode) ? .groupDuring : nil

        guard let lead = focusLead ?? currentMoment?.page,
              let index = base.firstIndex(where: { $0.page == lead }) else {
            return base
        }
        var reordered = base
        reordered.insert(reordered.remove(at: index), at: 0)
        return reordered
    }

    /// Whether the "Get help now" bar should visibly escalate (pulsing ring). True on
    /// distress signals or in the small hours, when a crisis is likeliest.
    private func shouldEscalateHelp(_ metrics: DashboardMetrics) -> Bool {
        // Takes the metrics the body already computed. Reading `dashboardMetrics`
        // here re-derived them a second time in the same pass.
        if metrics.realityCheckActive || metrics.healthWarningCount > 3 { return true }
        return NightMode.isActive()
    }

    private func entryNeedsAftercare(_ entry: NightEntry, now: Date) -> Bool {
        guard entry.isTrackedEvent, entry.aftercareCompletedAt == nil else { return false }
        let age = now.timeIntervalSince(entry.endDate)
        return age >= 6 * 60 * 60 && age <= 36 * 60 * 60
    }

    private func updateWidgetData(metrics: DashboardMetrics) {
        let shared = UserDefaults(suiteName: WidgetSharedKey.suiteName) ?? .standard
        shared.set(metrics.recoveryStreakDays, forKey: WidgetSharedKey.recoveryStreak)
        shared.set(metrics.dailyScore.displayValue, forKey: DefaultsKey.lastDailyRecoveryScore)
        shared.set(metrics.dailyScore.isActive, forKey: WidgetSharedKey.scoreIsActive)
        WidgetCenter.shared.reloadAllTimelines()

        services.watch.sendMetrics(
            recoveryStreakDays: metrics.recoveryStreakDays,
            dailyScore: metrics.dailyScore.displayValue,
            dailyScoreActive: metrics.dailyScore.isActive
        )

        // The weekly digest is a repeating calendar notification whose body is
        // baked in when it is scheduled, and both places that scheduled it passed
        // streak: 0, score: 0. So it fired every Sunday, forever, telling someone
        // on a forty-day streak that they were at zero days — in an app whose
        // whole point is that the streak is worth something.
        //
        // Rescheduling here, wherever the dashboard has just recomputed the real
        // figures, is the same trigger the widget and the watch already use, so
        // the digest can never drift from what the app is showing.
        if weeklyDigestEnabled {
            services.notifications.scheduleWeeklySummary(
                streak: metrics.recoveryStreakDays,
                score: metrics.dailyScore.displayValue
            )
        }
    }

    private func quickSkip() {
        // Prevent double-logging the same night: skip tapped twice, or once on the
        // phone and once from the Watch, or when tonight is already logged.
        if entries.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: .now) }) {
            return
        }
        let entry = NightEntry(
            date: .now,
            hadSex: false,
            skippedNight: true,
            substances: []
        )
        modelContext.insert(entry)
        modelContext.saveChanges()
        quickSkipHaptic += 1
    }
}

/// Inbound relays from the watch app.
///
/// Grouped into one modifier so the dashboard's modifier chain reads as
/// intent rather than three near-identical NotificationCenter subscriptions.
private struct WatchRelayObservers: ViewModifier {
    let quickSkip: () -> Void
    let logHydration: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .watchDidRequestQuickSkip)) { _ in
                quickSkip()
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchDidLogHydration)) { _ in
                logHydration()
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchDidRequestSOS)) { _ in
                // "Ping my phone" from the Watch Safety screen routes this phone
                // straight to the country-aware emergency page.
                UserDefaults.standard.set(
                    NotificationDestination.emergency.rawValue,
                    forKey: DefaultsKey.pendingAppDestination
                )
            }
    }
}

/// The dashboard's full-screen covers.
private struct DashboardCovers: ViewModifier {
    @Binding var isShowingLogSheet: Bool
    @Binding var isShowingCalendar: Bool

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isShowingLogSheet) {
                LogNightSheet()
            }
            .fullScreenCover(isPresented: $isShowingCalendar) {
                CalendarOverviewView()
            }

    }
}

private struct DashboardMetrics {
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

private struct HeaderSummaryView: View {
    let width: CGFloat
    let dailyScore: DailyRecoveryScore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Brand wordmark
            HStack(spacing: 9) {
                ChillMateBrandMark(size: 20)

                Text("ChillMate")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(LinearGradient.chillBrandDiagonal)
            }
            .padding(.bottom, 4)

            Text("Summary")
                .chillScaledFont(size: 38, weight: .bold, relativeTo: .largeTitle, design: .rounded)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.80)

            Text("Your private overview · last 3 months")
                .font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: max(320, width - 40), alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 4)
    }
}

private struct DailyScoreStatusPill: View {
    let score: DailyRecoveryScore

    var body: some View {
        VStack(spacing: 3) {
            // The inactive state puts an emoji here in place of the score. An emoji
            // is roughly square and does not shrink into its line box the way a
            // digit does, so at the larger text sizes it outgrows this card and is
            // drawn clipped. It gets a smaller size with headroom, the same
            // treatment as `StatTile`, rather than the digit's 26pt.
                // Hidden from accessibility, and not only to quiet the audit.
                //
                // The emoji stands in for a score that does not exist yet; the
                // label beside it is what says so, and VoiceOver reading "smiling
                // face with open mouth" before "Log to activate" is noise in front
                // of the instruction. Hiding it also settles a finding no amount of
                // resizing could: `performAccessibilityAudit` reports emoji as
                // clipped text whatever size they are drawn at, because an emoji
                // glyph's bounds exceed its layout frame by design. Replacing the
                // emoji with plain text made the finding disappear at every size,
                // which is what identified it as a property of the glyph rather
                // than of this layout.
            Text(score.isActive ? "\(score.value)" : score.emoji)
                .font(.system(size: score.isActive ? 24 : 18, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.chillText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityHidden(!score.isActive)

            Text("Daily score")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.chillText)
                .chillLineLimit(2, scale: 0.7)
                .fixedSize(horizontal: false, vertical: true)

            Text(score.isActive ? score.label : String(localized: "Log a Chill to activate your daily score"))
                .chillScaledFont(size: 9, weight: .semibold, relativeTo: .caption2)
                .foregroundStyle(Color.chillSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(score.isActive ? 1 : 3)
                .minimumScaleFactor(0.72)
        }
        .frame(width: 106)
        .frame(minHeight: 82)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .glassSurface(radius: 24, tint: .black.opacity(0.04), interactive: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(score.isActive ? "Daily score \(score.value), \(score.label)" : "Daily score inactive. Make a substance-related log to activate daily score.")
        .accessibilityIdentifier(AccessibilityID.dailyScorePill)
    }
}

private struct ProfileToolbarIcon: View {
    let profileImage: UIImage?

    var body: some View {
        Group {
            if let profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.chillText)
                    .padding(3)
            }
        }
        .frame(width: 26, height: 26)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(.white.opacity(0.55), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

private struct ReductionGoalProgressCard: View {
    let goal: Int
    let substanceOnly: Bool
    let entries: [NightEntry]

    private var currentMonthCount: Int {
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
        return entries.filter { entry in
            entry.date >= start && !entry.skippedNight && (substanceOnly ? !entry.substances.isEmpty : entry.hadSex || !entry.substances.isEmpty)
        }.count
    }

    private var progress: Double { min(1, Double(currentMonthCount) / Double(goal)) }

    private var progressColor: Color {
        switch progress {
        case 0..<0.6: Color.chillMint
        case 0.6..<0.85: .yellow
        default: .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Monthly goal", systemImage: "chart.line.downtrend.xyaxis")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(currentMonthCount)")
                    .chillScaledFont(size: 28, weight: .black, relativeTo: .title, design: .rounded)
                    .foregroundStyle(progressColor)
                Text("/ \(goal)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                Text(substanceOnly ? String(localized: "substance sessions this month") : String(localized: "sessions this month"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.10))
                    Capsule()
                        .fill(progressColor)
                        .frame(width: max(12, proxy.size.width * progress))
                }
            }
            .frame(height: 8)

            if currentMonthCount >= goal {
                Text("You've reached your limit for this month. Consider pausing.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            } else {
                Text("\(goal - currentMonthCount) \(goal - currentMonthCount == 1 ? String(localized: "session") : String(localized: "sessions")) remaining this month.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
            }
        }
        .padding(18)
        .glassSurface(radius: 30, tint: progressColor.opacity(0.08), interactive: true)
    }
}

private struct RecoveryStreakBadge: View {
    let days: Int
    let dailyScoreIsActive: Bool
    let openCalendar: () -> Void

    private var milestone: Int {
        switch days {
        case 0..<30:   return 30
        case 30..<90:  return 90
        case 90..<180: return 180
        case 180..<365: return 365
        default:        return 365
        }
    }

    private var progress: Double {
        guard milestone > 0 else { return 1 }
        return min(1, Double(days) / Double(milestone))
    }

    private var tint: Color {
        switch days {
        case 0...2:
            .red
        case 3...6:
            .orange
        case 7...13:
            .yellow
        case 14...29:
            Color.chillMint
        case 30...89:
            .green
        default:
            .cyan
        }
    }

    private var emoji: String {
        guard dailyScoreIsActive else {
            return "😄"
        }

        switch days {
        case 0...2:
            return "😢"
        case 3...6:
            return "🙁"
        case 7...13:
            return "🙂"
        case 14...29:
            return "😊"
        case 30...89:
            return "😄"
        default:
            return "🌟"
        }
    }

    private var displayText: String {
        if days >= 365 * 4 {
            return String(localized: "4+ years")
        }

        if days >= 365 {
            let years = days / 365
            let remainingDays = days % 365
            if remainingDays == 0 {
                return years == 1
                    ? String(localized: "\(years) year")
                    : String(localized: "\(years) years")
            }
            return years == 1
                ? String(localized: "\(years) year, \(remainingDays) d")
                : String(localized: "\(years) years, \(remainingDays) d")
        }

        return days == 1
            ? String(localized: "\(days) day")
            : String(localized: "\(days) days")
    }

    private var isMilestoneDay: Bool {
        [30, 90, 180, 365].contains(days)
    }

    @State private var isShowingMilestoneShare = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: openCalendar) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        Text(emoji)
                            .chillScaledFont(size: 30, relativeTo: .title)
                            .frame(width: 48, height: 48)
                            .glassSurface(radius: 24, tint: tint.opacity(0.16))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(displayText)
                                .chillScaledFont(size: 30, weight: .bold, relativeTo: .title)
                                .foregroundStyle(Color.chillText)
                                .chillLineLimit(1, scale: 0.72)

                            Text(String(localized: "without logged substance use"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.chillSecondary)
                        }

                        Spacer()
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.black.opacity(0.10))
                            Capsule()
                                .fill(.linearGradient(colors: [.red, .orange, .yellow, Color.chillMint, .green], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(12, proxy.size.width * progress))
                        }
                    }
                    .frame(height: 10)

                    Text(encouragement)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .glassSurface(radius: 30, tint: tint.opacity(0.12), interactive: true)
            }
            .buttonStyle(ChillPlainButtonStyle())
            .accessibilityLabel("Open calendar for recovery streak")

            if isMilestoneDay || days >= 30 {
                Button {
                    isShowingMilestoneShare = true
                } label: {
                    Label("Share \(displayText) milestone", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .glassSurface(radius: 18, tint: tint.opacity(0.10), interactive: true)
                }
                .buttonStyle(ChillPlainButtonStyle())
            }
        }
        .sheet(isPresented: $isShowingMilestoneShare) {
            MilestoneShareSheet(days: days, emoji: emoji, tint: tint)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sensoryFeedback(trigger: isShowingMilestoneShare) { _, presented in presented ? .impact(weight: .medium) : nil }
    }

    private var encouragement: String {
        switch days {
        case 0...2:
            String(localized: "Start gentle. One steady choice already counts.")
        case 3...6:
            String(localized: "You are creating space for recovery.")
        case 7...29:
            String(localized: "A full week changes how your body can rest.")
        case 30...89:
            String(localized: "Strong streak. Your body is building real recovery.")
        case 90...364:
            String(localized: "Three months of steady choices. That is significant.")
        default:
            String(localized: "Over a year of sustained recovery. Remarkable consistency.")
        }
    }
}

private struct DailyRecoveryScore {
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
                if !entry.substances.isEmpty {
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
                Factor(name: String(localized: "HRV"), caption: latestHRVms > 0 ? "\(Int(latestHRVms)) ms" : "not available"),
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
            Factor(name: String(localized: "Sleep"), caption: latest?.sleptYet == true ? "\(latest?.sleepHours.formatted(.number.precision(.fractionLength(0...1))) ?? "0") h" : "not logged"),
            Factor(name: String(localized: "Hydration"), caption: latest?.aftercareDrankWater == true ? "checked" : "unknown"),
            Factor(name: String(localized: "Food"), caption: latest?.aftercareAteFood == true ? "checked" : "unknown"),
            Factor(name: String(localized: "Substances"), caption: latestSubstances.isEmpty ? "clear" : "logged"),
            Factor(name: String(localized: "Anxiety"), caption: Self.anxietyCaption(latest, symptoms: latestSymptoms ?? [])),
            Factor(name: String(localized: "Streak"), caption: "\(recoveryStreakDays) d"),
            Factor(name: String(localized: "Symptoms"), caption: (latestSymptoms ?? []).isEmpty ? "none" : "\((latestSymptoms ?? []).count) selected"),
            Factor(name: String(localized: "HRV"), caption: latestHRVms > 0 ? "\(Int(latestHRVms)) ms" : "not available"),
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

private struct HealthWarningCard: View {
    let count: Int
    @State private var isShowingHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Health check-in", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("You have logged \(count) Chills involving sex and substances in the last 3 weeks. That pattern can carry physical and mental health risks.")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Would you like to start talking to a professional helper?")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            HStack {
                GlassActionButton(prominent: true) {
                    isShowingHelp = true
                } label: {
                    Label("Yes", systemImage: "person.2.wave.2.fill")
                        .font(.subheadline.weight(.bold))
                }

                Text("A GP, sexual health clinic, or trusted counselor can help without judgment.")
                    .font(.caption)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .glassSurface(radius: 30, tint: .orange.opacity(0.16), interactive: true)
        .fullScreenCover(isPresented: $isShowingHelp) {
            ProfessionalHelpView()
        }
    }
}

private struct PEPCountdownCard: View {
    let entry: NightEntry

    /// Only the remaining-time line is inside the TimelineView. The card body and
    /// its glass surface used to be rebuilt every minute along with it.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("PEP time window", systemImage: "clock.badge.exclamationmark.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("Based on what you logged, this may be worth a quick HIV PEP check. PEP works best if started within 72 hours.")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TimelineView(.periodic(from: .now, by: 60)) { context in
                let remaining = max(0, entry.pepDeadline.timeIntervalSince(context.date))
                HStack(alignment: .firstTextBaseline) {
                    Text(remainingText(for: remaining))
                        .font(.title2.bold())
                        .monospacedDigit()
                        .foregroundStyle(remaining <= 12 * 60 * 60 ? Color.chillIconRed : Color.chillSecondaryBlue)
                    Text("left in the 72 hour window")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.chillSecondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityRemainingLabel(for: remaining))
            }

            Text("Contact a sexual-health service, GP, or hospital as soon as possible. PEP works best when started quickly and is generally time limited to 72 hours.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .glassSurface(radius: 30, tint: Color.chillSecondaryBlue.opacity(0.12), interactive: true)
    }

    private func remainingText(for interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }

    private func accessibilityRemainingLabel(for interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        return String(localized: "\(hours) hours \(minutes) minutes left in the 72 hour PEP window")
    }
}

private struct WhatChangedPatternCard: View {
    let recentCount: Int
    let previousCount: Int
    let reasonCounts: [(reason: ChangeReason, count: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What changed?", systemImage: "waveform.path.ecg")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("Risky Chills increased from \(previousCount) to \(recentCount) compared with the previous 3 weeks. If something changed, tagging it in logs can make patterns easier to see.")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if reasonCounts.isEmpty {
                Text("No change reasons tagged yet. New logs now include stress, breakup, work pressure, loneliness, money, housing, conflict, and boredom.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(reasonCounts.prefix(5), id: \.reason) { item in
                        HStack {
                            Text(item.reason.localizedDisplayName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.chillText)
                            Spacer()
                            Text("\(item.count)")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(Color.chillSecondaryBlue)
                        }
                    }
                }
            }
        }
        .padding(18)
        .glassSurface(radius: 30, tint: Color.chillSecondaryBlue.opacity(0.10), interactive: true)
    }
}

private struct RealityCheckCard: View {
    let openPanicSupport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                BreathingOrb()
                    .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Reality check mode")
                        .font(.title3.bold())
                        .foregroundStyle(Color.chillText)
                    Text("A calmer layout is available because recent inputs suggest extra load.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                }
            }

            Text("No judgment. Bigger actions, fewer colors, and a slower pace can help when decisions feel noisy.")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: openPanicSupport) {
                Label("Open calming mode", systemImage: "lungs.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
            }
            .buttonStyle(ChillPillButtonStyle(prominent: true))
        }
        .padding(18)
        .glassSurface(radius: 30, tint: Color.chillDarkBackground.opacity(0.10), interactive: true)
    }
}

private struct BreathingOrb: View {
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.chillPrimary.opacity(0.72), Color.chillMint.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

private struct MilestoneShareSheet: View {
    let days: Int
    let emoji: String
    let tint: Color

    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: Image?

    private var milestoneText: String {
        if days >= 365 {
            let years = days / 365
            return years == 1
                ? String(localized: "\(years) year")
                : String(localized: "\(years) years")
        }
        return String(localized: "\(days) days")
    }

    private var cardView: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.88), Color.black.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(tint.opacity(0.36), lineWidth: 1)
                    )

                VStack(spacing: 16) {
                    Text(emoji)
                        .chillScaledFont(size: 52, relativeTo: .largeTitle)

                    Text(milestoneText)
                        .chillScaledFont(size: 36, weight: .black, relativeTo: .largeTitle, design: .rounded)
                        .foregroundStyle(.white)

                    Text(String(localized: "without logged substance use"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))

                    HStack(spacing: 6) {
                        ChillMateBrandMark(size: 18)
                        Text("ChillMate")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.54))
                    }
                }
                .padding(28)
            }
            .frame(width: 300, height: 300)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.84).ignoresSafeArea()

            VStack(spacing: 20) {
                Text(String(localized: "Share milestone"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.chillText)

                cardView
                    .frame(width: 300, height: 300)

                Text(String(localized: "Sharing this image reveals only your streak: no substances, dates, or other details."))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)

                if let img = renderedImage {
                    ShareLink(item: img, preview: SharePreview("\(milestoneText) milestone", image: img)) {
                        Label(String(localized: "Share milestone card"), systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChillPillButtonStyle(prominent: true))
                    .padding(.horizontal, 28)
                } else {
                    Button(String(localized: "Prepare card")) {
                        renderCard()
                    }
                    .buttonStyle(ChillPillButtonStyle(prominent: true))
                    .padding(.horizontal, 28)
                }

                Button(String(localized: "Done")) { dismiss() }
                    .foregroundStyle(Color.chillSecondary)
                    .padding(.bottom, 12)
            }
        }
        .onAppear { renderCard() }
    }

    private func renderCard() {
        let renderer = ImageRenderer(content: cardView.frame(width: 300, height: 300))
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            renderedImage = Image(uiImage: uiImage)
        }
    }
}

private struct ProfessionalHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DefaultsKey.lastDailyRecoveryScore) private var lastDailyRecoveryScore = 42

    private var palette: DailyScorePalette {
        DailyScorePalette(score: lastDailyRecoveryScore)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(String(localized: "Talk to someone"))
                            .font(.largeTitle.bold())
                            .foregroundStyle(palette.heroText)
                            .disablesRootSwipeBack()

                        Text(String(localized: "A professional helper can talk through sex, substances, sleep, PrEP, consent, and safety without judgment."))
                            .font(.callout)
                            .foregroundStyle(palette.heroSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HelpResourceCard(
                            title: String(localized: "Sexual health clinic"),
                            detail: String(localized: "Good for STI testing, PrEP, condoms, chemsex support, and safer-sex planning."),
                            symbol: "cross.case.fill"
                        )

                        HelpResourceCard(
                            title: String(localized: "GP or family doctor"),
                            detail: String(localized: "Good for sleep, mood, substance concerns, medication interactions, and referrals."),
                            symbol: "stethoscope"
                        )

                        HelpResourceCard(
                            title: String(localized: "Counselor or addiction support"),
                            detail: String(localized: "Good when patterns feel hard to change, risky, or emotionally heavy."),
                            symbol: "person.2.fill"
                        )
                    }
                    .padding(20)
                }
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BackChevronButton {
                        dismiss()
                    }
                }
            }
            .edgeSwipeToDismiss()
        }
    }
}

private struct HelpResourceCard: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.chillPrimary)
                .frame(width: 42, height: 42)
                .glassSurface(radius: 21, tint: Color.chillPrimary.opacity(0.10))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.chillText)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .black.opacity(0.04))
    }
}

private struct TodayFocusCard: View {
    let entries: [NightEntry]
    let plans: [SaferSessionPlan]
    let timers: [DrugDoseTimerRecord]
    let tests: [STDTestRecord]
    let journalEntries: [JournalEntry]
    let metrics: DashboardMetrics
    let log: () -> Void
    let openCare: (CareToolPage) -> Void
    let openCalendar: () -> Void

    private var action: SmartNextAction {
        SmartNextAction(
            entries: entries,
            plans: plans,
            timers: timers,
            tests: tests,
            journalEntries: journalEntries,
            metrics: metrics
        )
    }

    var body: some View {
        Button(action: performAction) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(action.tint.opacity(0.22))
                        .frame(width: 48, height: 48)
                    Image(systemName: action.symbol)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(action.tint)
                        .symbolRenderingMode(.hierarchical)
                }
                .shadow(color: action.tint.opacity(0.36), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    // The next-action headline. Its length swings from "Log a Chill"
                    // to "Ready when you are" to the German for either, and one
                    // headline-sized line at 75% does not hold the longer ones once
                    // the text size grows — it truncates the sentence that tells
                    // someone what the card is for.
                    Text(action.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.chillText)
                        .chillLineLimit(2, scale: 0.7)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(action.detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.chillTertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ChillPlainButtonStyle())
        .glassSurface(radius: 28, tint: .clear, interactive: true)
        .accessibilityLabel(action.accessibilityLabel)
    }

    private func performAction() {
        switch action.destination {
        case .log:
            log()
        case .calendar:
            openCalendar()
        case .care(let page):
            openCare(page)
        }
    }
}

private struct SmartNextAction {
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
            detail = String(localized: "\(timer.substanceName) is still active. Check the timer before deciding anything else.")
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

/// Always-visible crisis affordance pinned near the top of Home: a solid red bar,
/// so the one path that must never be hunted for is the loudest thing on screen.
/// `escalated` adds a pulsing ring when signals suggest the user may be in distress.
private struct GetHelpNowBar: View {
    var escalated: Bool = false
    let open: () -> Void

    @Environment(\.chillReduceMotion) private var reduceMotion

    /// A deep, saturated red (matching the emergency-call button) that keeps white
    /// text readable. The icon-tint `chillIconRed` is too light for a solid fill.
    private let barRed = Color(red: 216 / 255, green: 52 / 255, blue: 52 / 255)

    /// 0 → 1 continuous driver for the pulsing ring (a Bool doesn't oscillate
    /// reliably under `repeatForever`).
    @State private var pulse: CGFloat = 0

    var body: some View {
        Button(action: open) {
            HStack(spacing: 9) {
                Image(systemName: "cross.case.fill")
                Text("Get help now")
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(barRed)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(escalated ? (0.25 + 0.6 * pulse) : 0), lineWidth: 2)
            )
            .shadow(color: barRed.opacity(escalated ? 0.55 : 0.28), radius: escalated ? 18 : 9, y: 4)
        }
        .buttonStyle(ChillPlainButtonStyle())
        .accessibilityLabel(Text("Get help now. Breathing, grounding, or call emergency services."))
        .onAppear { syncPulse() }
        .onChange(of: escalated) { _, _ in syncPulse() }
    }

    private func syncPulse() {
        // Reduce Motion holds the ring steady instead of breathing. The escalated
        // state still has to READ as escalated, so the ring stays at its bright
        // value rather than being dropped: the people most likely to have Reduce
        // Motion on are the last people who should lose a crisis affordance.
        //
        // A `repeatForever` animation also never settles, so leaving it running
        // ignores the preference for as long as the bar is on screen.
        guard !reduceMotion else {
            pulse = escalated ? 1 : 0
            return
        }

        if escalated {
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) { pulse = 1 }
        } else {
            withAnimation(.easeOut(duration: 0.3)) { pulse = 0 }
        }
    }
}

private struct MetricsGrid: View {
    @State private var delays = DelayedActionRunner()
    @Environment(\.chillReduceMotion) private var reduceMotion

    let trackedCount: Int
    let skippedCount: Int
    let substanceCount: Int
    let averageSleepHours: Double?
    let dailyScore: DailyRecoveryScore
    let recoveryStreakDays: Int
    let openRecoveryStreak: () -> Void

    @State private var showDetails = false
    @State private var isShowingFactors = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: openRecoveryStreak) {
                    StatTile(
                        value: "\(recoveryStreakDays)",
                        // A `== 1` ternary, deliberately. Xcode rejects a plural
                        // variation whose value does not print the number
                        // ("Plural variation requires referencing the number in the
                        // string ... use separate top-level strings"), and this unit
                        // sits beside a number the tile already draws. Separate
                        // strings picked in code is the sanctioned form here.
                        unit: recoveryStreakDays == 1 ? String(localized: "day") : String(localized: "days"),
                        label: String(localized: "Recovery streak"),
                        showsChevron: false
                    )
                }
                .buttonStyle(ChillPlainButtonStyle())
                .accessibilityLabel(Text("Recovery streak of \(recoveryStreakDays) days. Tap to open your calendar."))

                Button { isShowingFactors = true } label: {
                    StatTile(
                        value: dailyScore.isActive ? "\(dailyScore.value)" : dailyScore.emoji,
                        unit: nil,
                        label: dailyScore.isActive ? String(localized: "Today’s score") : String(localized: "Log to activate"),
                        showsChevron: true
                    )
                }
                .buttonStyle(ChillPlainButtonStyle())
                .accessibilityLabel(dailyScore.isActive ? Text("Today’s score \(dailyScore.value). Tap to see the breakdown.") : Text("Daily score not active yet. Log a night to activate."))
            }

            if showDetails {
                LazyVGrid(columns: columns, spacing: 8) {
                    MetricCard(title: String(localized: "Logged"), value: "\(trackedCount)", caption: String(localized: "with sex or substances"), symbol: "heart.text.square.fill", tint: Color.chillIconPink)
                    MetricCard(title: String(localized: "Skipped"), value: "\(skippedCount)", caption: String(localized: "all-clear check-ins"), symbol: "moon.zzz.fill", tint: Color.chillIconPurple)
                    MetricCard(title: String(localized: "Substances"), value: "\(substanceCount)", caption: String(localized: "tags across logs"), symbol: "pills.fill", tint: Color.chillSecondaryBlue)
                    MetricCard(title: String(localized: "Sleep"), value: sleepValue, caption: sleepCaption, symbol: "bed.double.fill", tint: Color.chillIconAmber)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                withAnimation(.snappy) { showDetails.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(showDetails ? String(localized: "Hide details") : String(localized: "Show details"))
                        .font(.caption.weight(.bold))
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(Color.chillPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(ChillPlainButtonStyle())
            .accessibilityLabel(showDetails ? Text("Hide monthly details") : Text("Show monthly details"))
        }
        .padding(12)
        .glassSurface(radius: 28, tint: .clear)
        .sheet(isPresented: $isShowingFactors) {
            ScoreFactorsSheet(score: dailyScore, openCalendar: {
                isShowingFactors = false
                // Cancellable, and skipped entirely under Reduce Motion, where the
                // delay exists only to let a flourish play.
                delays.run(after: .milliseconds(350), reduceMotion: reduceMotion) { openRecoveryStreak() }
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sensoryFeedback(trigger: isShowingFactors) { _, presented in presented ? .impact(weight: .light) : nil }
        .cancellingDelayedActions(delays)
    }

    private var sleepValue: String {
        guard let averageSleepHours else { return String(localized: "0 hours") }
        return SleepMood(hours: averageSleepHours).emoji
    }

    private var sleepCaption: String {
        guard let averageSleepHours else { return String(localized: "sleep not logged") }
        return String(localized: "avg \(averageSleepHours.formatted(.number.precision(.fractionLength(0...1)))) h")
    }
}

/// One flat metric tile in the two-up summary row (recovery streak / today's score),
/// matching the mockup's stat cards.
private struct StatTile: View {
    let value: String
    let unit: String?
    let label: String
    let showsChevron: Bool

    /// True when `value` is a score rather than the placeholder emoji.
    private var isNumeric: Bool { value.allSatisfy(\.isNumber) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                // `value` is a number when the score is active and an emoji when
                // it is not, and the two need different sizes.
                //
                // A digit at 26pt relative to .title is fine: it is narrow, and
                // minimumScaleFactor shrinks it if the row runs out of width. An
                // emoji is neither. It is roughly square, it does not respond to
                // minimumScaleFactor the way glyphs from a text font do, and at the
                // accessibility sizes a .title-relative emoji outgrows this tile and
                // is drawn clipped — which is what the audit reports.
                //
                // So the emoji gets its own smaller scale with headroom to grow
                // into. It is standing in for "no score yet" rather than carrying a
                // reading, so it can afford to be smaller; the label beside it is
                // what actually says so.
                Text(value)
                    .chillScaledFont(
                        size: isNumeric ? 26 : 20,
                        weight: .bold,
                        relativeTo: isNumeric ? .title : .body,
                        design: .rounded
                    )
                    .foregroundStyle(Color.chillText)
                    .monospacedDigit()
                    .contentTransition(isNumeric ? .numericText() : .identity)
                    .chillLineLimit(1, scale: 0.6)
                    .accessibilityHidden(!isNumeric)
                if let unit {
                    Text(unit)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.chillSecondary)
                }
                Spacer(minLength: 0)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.chillTertiary)
                }
            }
            // One line at 80% is not enough room for "Log to activate" once the
            // text size grows, so it truncated — which the accessibility audit
            // reports as clipped text, and which on this tile hides the only
            // instruction telling someone how to switch the score on.
            //
            // Two lines and a little more shrink. The tiles sit side by side, so
            // the taller one sets the row height and they stay aligned.
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .chillLineLimit(2, scale: 0.7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassSurface(radius: 20, tint: .clear, interactive: true)
    }
}

private struct ScoreFactorsSheet: View {
    let score: DailyRecoveryScore
    let openCalendar: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.84).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(Color.chillPrimary.opacity(0.14), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: score.isActive ? CGFloat(score.value) / 100 : 1)
                                .stroke(LinearGradient.chillBrand, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            // Scaling text inside a container that does not scale
                            // can only ever end in clipping, and this ring is a
                            // fixed 52pt. The glyph is allowed to shrink to fit it
                            // rather than grow out of it — which matters most for
                            // the emoji, since an emoji is roughly square and hits
                            // the edge long before a digit does.
                            Text(score.isActive ? "\(score.value)" : score.emoji)
                                .chillScaledFont(size: 18, weight: .black, relativeTo: .title3, design: .rounded)
                                .foregroundStyle(Color.chillText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .accessibilityHidden(!score.isActive)
                        }
                        .frame(width: 52, height: 52)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(localized: "Daily recovery score"))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.chillText)
                            Text(score.isActive ? score.label.capitalized : String(localized: "Log a Chill to activate"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.chillSecondary)
                        }
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(score.factors.enumerated()), id: \.offset) { _, factor in
                            HStack(spacing: 14) {
                                Text(factor.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.chillText)
                                    .frame(width: 90, alignment: .leading)
                                Text(factor.caption)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.chillSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(.white.opacity(0.06))
                                    .frame(height: 1)
                            }
                        }
                    }
                    .glassSurface(radius: 20, tint: .white.opacity(0.07))

                    Text(String(localized: "Score is based on your most recent log entry: sleep, aftercare, substances, recovery streak, and Apple Watch HRV if available."))
                        .font(.caption)
                        .foregroundStyle(Color.chillTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: openCalendar) {
                        Label(String(localized: "View calendar"), systemImage: "calendar")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChillPillButtonStyle(prominent: false))
                }
                .padding(20)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let caption: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 0) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                        .frame(width: 34, height: 34)
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(tint)
                        .symbolRenderingMode(.hierarchical)
                }
                .shadow(color: tint.opacity(0.36), radius: 6, y: 2)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .chillScaledFont(size: 22, weight: .black, relativeTo: .title2, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(Color.chillText)
                    .chillLineLimit(1, scale: 0.70)

                // Both of these carry sentences whose length varies with the
                // language and with what the card is reporting, and a hard
                // one-line limit truncates them rather than wrapping. The audit
                // reports that as clipped text; on this card it is the line that
                // says what the number means.
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillText.opacity(0.90))
                    .chillLineLimit(2, scale: 0.75)
                    .fixedSize(horizontal: false, vertical: true)

                Text(caption)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .chillLineLimit(2, scale: 0.75)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        .padding(12)
        .glassSurface(radius: 20, tint: .clear, interactive: true)
    }
}

private struct SubstanceOverview: View {
    let counts: [(name: String, count: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: String(localized: "Substance tags"), symbol: "chart.bar.xaxis")

            if counts.isEmpty {
                EmptyGlassState(text: String(localized: "No substance tags in the past 3 months."))
            } else {
                VStack(spacing: 12) {
                    ForEach(counts.prefix(6), id: \.name) { item in
                        SubstanceBar(name: item.name, count: item.count, maxCount: counts.first?.count ?? 1)
                    }
                }
                .padding(16)
                .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08))
            }
        }
    }
}

struct DrugDoseHistoryGraph: View {
    let rows: [DoseHistoryRow]
    let monthDays: [Date]

    init(timers: [DrugDoseTimerRecord], entries: [NightEntry], monthDays: [Date]) {
        self.monthDays = monthDays
        rows = DoseHistoryRow.make(timers: timers, entries: entries, monthDays: monthDays)
    }

    private var maxCount: Int {
        max(1, rows.flatMap(\.dayCounts).max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: String(localized: "Substance pattern history"), symbol: "chart.xyaxis.line")

            if rows.isEmpty {
                EmptyGlassState(text: String(localized: "Start a check-in or log substances to see private patterns here."))
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text(String(localized: "A private month view for spotting changes over time. It does not label anything as good or bad."))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(rows.prefix(6)) { row in
                        DoseHistoryRowView(row: row, maxCount: maxCount)
                    }
                }
                .padding(16)
                .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08), interactive: true)
            }
        }
    }
}

// Internal alongside the graph that publishes it: `DrugDoseHistoryGraph` is used
// from the calendar now, and a public-facing type cannot expose a private one.
struct DoseHistoryRow: Identifiable {
    let id: String
    let substance: String
    let dayCounts: [Int]
    let routeSummary: String
    let doseNotesCount: Int
    let redoseDays: Int

    static func make(timers: [DrugDoseTimerRecord], entries: [NightEntry], monthDays: [Date], calendar: Calendar = .current) -> [DoseHistoryRow] {
        let dayKeys = monthDays.map { calendar.startOfDay(for: $0) }
        var countsBySubstance: [String: [Date: Int]] = [:]
        var routeCounts: [String: [String: Int]] = [:]
        var doseNotes: [String: Int] = [:]

        for timer in timers {
            let substance = timer.substanceName
            let day = calendar.startOfDay(for: timer.startedAt)
            countsBySubstance[substance, default: [:]][day, default: 0] += 1
            let routeLabel = AdministrationRoute(rawValue: timer.administrationRoute)?.displayName ?? timer.administrationRoute
            routeCounts[substance, default: [:]][routeLabel, default: 0] += 1
            if !timer.doseNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                doseNotes[substance, default: 0] += 1
            }
        }

        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            for substance in entry.substances {
                countsBySubstance[substance, default: [:]][day, default: 0] += 1
                if routeCounts[substance] == nil {
                    routeCounts[substance] = ["Logged": 1]
                }
            }
        }

        return countsBySubstance.map { substance, dayMap in
            let counts = dayKeys.map { dayMap[$0] ?? 0 }
            let routes = (routeCounts[substance] ?? [:])
                .sorted { first, second in
                    first.value == second.value ? first.key < second.key : first.value > second.value
                }
                .prefix(3)
                .map { "\($0.key) \($0.value)" }
                .joined(separator: " · ")
            return DoseHistoryRow(
                id: substance,
                substance: substance,
                dayCounts: counts,
                routeSummary: routes.isEmpty ? String(localized: "No route saved") : routes,
                doseNotesCount: doseNotes[substance] ?? 0,
                redoseDays: dayMap.values.filter { $0 > 1 }.count
            )
        }
        .sorted { first, second in
            let firstTotal = first.dayCounts.reduce(0, +)
            let secondTotal = second.dayCounts.reduce(0, +)
            return firstTotal == secondTotal ? first.substance < second.substance : firstTotal > secondTotal
        }
    }
}

private struct DoseHistoryRowView: View {
    let row: DoseHistoryRow
    let maxCount: Int

    private var total: Int {
        row.dayCounts.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.substance)
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
                Spacer()
                Text(String(localized: "\(total) logged"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondaryBlue)
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(row.dayCounts.enumerated()), id: \.offset) { _, count in
                    Capsule()
                        .fill(count > 0 ? LinearGradient(colors: [Color.chillPrimary.opacity(0.90), Color.chillSecondaryBlue.opacity(0.70)], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.07)], startPoint: .top, endPoint: .bottom))
                        .frame(maxWidth: .infinity)
                        .frame(height: count > 0 ? max(8, CGFloat(count) / CGFloat(maxCount) * 42) : 6)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 46)

            Text("\(row.routeSummary) · \(row.redoseDays) continued day\(row.redoseDays == 1 ? "" : "s") · \(row.doseNotesCount) private note\(row.doseNotesCount == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct SubstanceBar: View {
    let name: String
    let count: Int
    let maxCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.chillText)
                Spacer()
                Text("\(count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.chillSecondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.black.opacity(0.10))
                    Capsule()
                        .fill(.linearGradient(colors: [Color.chillMint, Color.chillSecondaryBlue, Color.chillAccentTeal], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(12, proxy.size.width * CGFloat(count) / CGFloat(max(maxCount, 1))))
                }
                .scrollIndicators(.hidden)
            }
            .frame(height: 9)
        }
    }
}

private struct SkippedNightCard: View {
    let statuses: [NightStatus]
    @Binding var isExpanded: Bool
    let markSkipped: (Date) -> Void

    private var missingStatuses: [NightStatus] {
        statuses.filter { $0.entry == nil }
    }

    var body: some View {
        LiquidGlassGroup(spacing: 14) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    SectionTitle(title: String(localized: "Skipped Chill check"), symbol: "checklist")
                    Spacer()
                    Button {
                        isExpanded.toggle()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.headline)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(ChillPlainButtonStyle())
                    .glassSurface(radius: 17, tint: .black.opacity(0.05), interactive: true)
                    .accessibilityLabel(isExpanded ? "Collapse skipped Chill check" : "Expand skipped Chill check")
                }

                if missingStatuses.isEmpty {
                    Text("Every Chill in the last 14 days has either a log or a skipped check-in.")
                        .font(.callout)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(missingSummary)
                        .font(.callout)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if isExpanded {
                    VStack(spacing: 10) {
                        ForEach(statuses.prefix(10)) { status in
                            NightStatusRow(status: status, markSkipped: markSkipped)
                        }
                    }
                }
            }
            .padding(18)
            .glassSurface(radius: 30, tint: .indigo.opacity(0.10))
        }
    }

    private var missingSummary: AttributedString {
        var summary = AttributedString("\(missingStatuses.count) recent Chills have no entry. Open the check to mark skipped Chills.")
        if let range = summary.range(of: "\(missingStatuses.count)") {
            summary[range].inlinePresentationIntent = .stronglyEmphasized
        }
        return summary
    }

}

private struct NightStatusRow: View {
    let status: NightStatus
    let markSkipped: (Date) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(status.tint)
                .frame(width: 32, height: 32)
                .glassSurface(radius: 16, tint: status.tint.opacity(0.16))

            VStack(alignment: .leading, spacing: 2) {
                Text(status.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.chillText)

                Text(status.detailText)
                    .font(.caption)
                    .foregroundStyle(Color.chillSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            if status.entry == nil {
                Button {
                    markSkipped(status.date)
                } label: {
                    Text("Skip")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(ChillPlainButtonStyle())
                .glassSurface(radius: 16, tint: .indigo.opacity(0.20), interactive: true)
            }
        }
        .padding(10)
        .glassSurface(radius: 20, tint: .black.opacity(0.04))
    }
}

private struct TimelineSection: View {
    let entries: [NightEntry]
    let delete: (NightEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: String(localized: "Timeline"), symbol: "calendar")

            if entries.isEmpty {
                EmptyGlassState(text: String(localized: "No entries in the past 3 months."))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(entries) { entry in
                        TimelineRow(entry: entry, delete: delete)
                    }
                }
            }
        }
    }
}

struct TimelineRow: View {
    let entry: NightEntry
    let delete: (NightEntry) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 4) {
                Text(entry.date.formatted(.dateTime.day()))
                    .font(.title3.bold())
                    .foregroundStyle(Color.chillText)
                Text(entry.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
            }
            .frame(width: 48)
            .padding(.vertical, 8)
            .glassSurface(radius: 18, tint: entry.skippedNight ? .indigo.opacity(0.14) : Color.chillAccentTeal.opacity(0.14))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(entry.skippedNight ? String(localized: "Skipped Chill") : String(localized: "Sex + substances"))
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                    Spacer()
                    Button(role: .destructive) {
                        delete(entry)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.chillSecondary)
                    }
                    .buttonStyle(ChillPlainButtonStyle())
                    .accessibilityLabel("Delete entry")
                }

                Label(entry.timeFrameSummary, systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)

                if entry.hasLocation {
                    Label(entry.locationSummary, systemImage: "location.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .lineLimit(2)
                }

                if entry.hadSex, !entry.skippedNight {
                    Label(entry.partnerSummary, systemImage: "person.2.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)

                    Label(entry.saferSexSummary, systemImage: "shield")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                }

                if entry.substances.isEmpty {
                    Text(String(localized: "No substances recorded."))
                        .font(.subheadline)
                        .foregroundStyle(Color.chillSecondary)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(Array(entry.substances.enumerated()), id: \.offset) { _, substance in
                            Text(substance)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.chillText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .glassSurface(radius: 14, tint: .black.opacity(0.04))
                        }
                    }
                }

                if !entry.injectionSubstances.isEmpty {
                    Label("Injection context: \(entry.injectionSubstances.joined(separator: ", "))", systemImage: "syringe.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillMint)
                        .lineLimit(2)
                }

                Text(entry.sleepSummary)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.chillSecondary)
                    .lineLimit(2)

                if !entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(entry.note)
                        .font(.footnote)
                        .foregroundStyle(Color.chillSecondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(14)
        .glassSurface(radius: 28, tint: .black.opacity(0.04))
    }
}

private struct FloatingLogBar: View {
    let add: () -> Void
    let skip: () -> Void
    var isTonightLogged: Bool = false
    @State private var isPressed = false
    @State private var confirmSkip = false
    @State private var hasQuickSkippedLocally = false
    @State private var pressTask: Task<Void, Never>?
    @Environment(\.chillReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Primary action: matches original clean design
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Private log"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                    Text(String(localized: "Add sleep, reflection, or a skip"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                }

                Spacer(minLength: 12)

                Button {
                    // Cancellable and reduce-motion aware. The previous
                    // DispatchQueue.main.asyncAfter could not be cancelled and fired
                    // its animation even after the view had gone away.
                    if !reduceMotion {
                        pressTask?.cancel()
                        withAnimation(.spring(response: 0.20, dampingFraction: 0.70)) { isPressed = true }
                        pressTask = Task {
                            try? await Task.sleep(for: .milliseconds(140))
                            guard !Task.isCancelled else { return }
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) { isPressed = false }
                        }
                    }
                    add()
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(LinearGradient.chillBrand, in: Capsule())
                        .shadow(color: Color.chillPrimary.opacity(0.44), radius: 12, y: 6)
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                }
                .buttonStyle(ChillPlainButtonStyle())
                .accessibilityLabel("Add Chill")
                .accessibilityIdentifier(AccessibilityID.logChillButton)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            // Secondary action: clear-night quick log.
            // Hidden once tonight is already logged, or immediately hidden when tapped locally
            if !isTonightLogged && !hasQuickSkippedLocally {
                Rectangle()
                    .fill(.white.opacity(0.07))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)

                Button {
                    confirmSkip = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.chillSecondary)
                        Text(String(localized: "Nothing happened tonight"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.chillTertiary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(ChillPlainButtonStyle())
                .accessibilityLabel("Log nothing happened tonight")
                .accessibilityIdentifier(AccessibilityID.skipNightButton)
            }
        }
        .glassSurface(radius: 30, tint: .black.opacity(0.04))
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isTonightLogged)
        .onDisappear { pressTask?.cancel() }
        .alert(String(localized: "Log a clear night?"), isPresented: $confirmSkip) {
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Confirm")) {
                withAnimation { hasQuickSkippedLocally = true }
                skip()
            }
        } message: {
            Text("This marks tonight as a clear night with nothing to track. You can still add a log later if something comes up.")
        }
    }
}

struct SectionTitle: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(LinearGradient.chillBrand)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.chillText)
        }
    }
}

struct EmptyGlassState: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(Color.chillSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassSurface(radius: 24, tint: .black.opacity(0.04))
    }
}

private struct NightStatus: Identifiable {
    let date: Date
    let entry: NightEntry?

    var id: Date { date }

    var symbol: String {
        if entry == nil { return "questionmark" }
        if entry?.skippedNight == true { return "moon.zzz.fill" }
        return "checkmark"
    }

    var tint: Color {
        if entry == nil { return .orange }
        if entry?.skippedNight == true { return .indigo }
        return Color.chillMint
    }

    var detailText: String {
        guard let entry else {
            return String(localized: "No entry recorded.")
        }

        if entry.skippedNight {
            let sleep = entry.sleepSummary
            return String(localized: "Marked skipped. \(sleep)")
        }

        let substances = entry.substances.joined(separator: ", ")
        let drugText = substances.isEmpty ? "Tracked without substance tags." : substances
        return "\(drugText) \(entry.sleepSummary)"
    }
}
