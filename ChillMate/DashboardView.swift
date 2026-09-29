import SwiftData
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
        CareToolDestination(page: page) { careNavPath.append($0) }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .chillMinimizingNavigationBar()
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
                    lastKnownHRVms = hrv.value
                }
            }
            .task(id: healthKitHeartRateReadEnabled) {
                // The resting read has existed since 4.3.0 and had no caller.
                guard healthKitHeartRateReadEnabled else { return }
                if let resting = try? await services.health.latestRestingHeartRate() {
                    lastKnownRestingBPM = resting
                }
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
/// intent rather than near-identical NotificationCenter subscriptions.
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
