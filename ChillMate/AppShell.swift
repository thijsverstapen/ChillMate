import StoreKit
import SwiftData
import SwiftUI
import UIKit

/// The app's shell: the tab bar, what each tab holds, and the More hub.
///
/// Split out of `ProfileSetupView.swift`, where it had been sharing a file with
/// the profile wizard, the onboarding intro, the tip jar and a set of form rows —
/// four thousand lines with nothing in common but the order they were written in.
/// This is a move, not a rewrite.

struct AppHomeView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(ChillMateQueries.profile) private var profiles: [UserProfile]
    @AppStorage(DefaultsKey.lastOnDeviceRecoveryStatus) private var lastOnDeviceRecoveryStatus = ""
    @AppStorage(DefaultsKey.hasShownFirstLaunchSplash) private var hasShownFirstLaunchSplash = false
    @State private var didAttemptRecoveryRestore = false

    var body: some View {
        Group {
            if !hasShownFirstLaunchSplash {
                // First launch ever: play the animated splash once, then fall
                // through to onboarding. Every later launch skips straight past.
                FirstLaunchSplashView {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        hasShownFirstLaunchSplash = true
                    }
                }
                .transition(.opacity)
            } else if profiles.isEmpty {
                ProfileSetupView()
            } else {
                MainTabView()
            }
        }
        .task {
            await restoreOnDeviceRecoverySnapshotIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task {
                    await restoreOnDeviceRecoverySnapshotIfNeeded()
                }
            case .inactive, .background:
                Task {
                    await refreshOnDeviceRecoverySnapshot()
                }
            @unknown default:
                break
            }
        }
    }

    @MainActor
    private func restoreOnDeviceRecoverySnapshotIfNeeded() async {
        guard !didAttemptRecoveryRestore else {
            return
        }

        didAttemptRecoveryRestore = true

        do {
            if let summary = try services.encryptedBackups.restoreOnDeviceRecoverySnapshotIfNeeded(into: modelContext) {
                // These status lines are persisted and re-rendered much later in the
                // privacy timeline and the Settings backup card, so they have to be
                // translated at the moment they are written. Nothing localizes them
                // on the way back out of UserDefaults.
                lastOnDeviceRecoveryStatus = String(localized: "Recovered \(summary.totalItems) encrypted items from this iPhone.")
            }
        } catch {
            lastOnDeviceRecoveryStatus = String(localized: "Automatic recovery could not open the encrypted on-device backup.")
        }
    }

    @MainActor
    private func refreshOnDeviceRecoverySnapshot() async {
        do {
            if try services.encryptedBackups.refreshOnDeviceRecoverySnapshot(localContext: modelContext) {
                lastOnDeviceRecoveryStatus = String(localized: "Encrypted on-device recovery backup updated.")
            }
        } catch {
            lastOnDeviceRecoveryStatus = String(localized: "Encrypted on-device recovery backup could not update.")
        }
    }
}

enum AppTab: String {
    case home
    case history
    case more
}

private struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var careNavPath: [CareToolPage] = []
    @State private var historySegment: HistorySegment = .calendar
    @State private var isShowingShortcutLog = false
    @AppStorage(DefaultsKey.pendingAppDestination) private var pendingAppDestination = ""
    @AppStorage(DefaultsKey.lastSelectedTab) private var lastSelectedTab = AppTab.home.rawValue
    @AppStorage(DefaultsKey.lastBackgroundedAt) private var lastBackgroundedAt = 0.0
    @Environment(\.scenePhase) private var scenePhase

    /// After at least this long in the background, reopening the app returns to
    /// the Home tab instead of restoring whichever tab the user last viewed.
    private let backgroundResetThreshold: TimeInterval = 5 * 60

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(careNavPath: $careNavPath, openCalendarTab: {
                historySegment = .calendar
                selectedTab = .history
            })
            // Locale-independent handles for UI tests. The tests used to query
            // tab bar items by their English label, so they could only ever
            // pass in English, including the run that launches in all five
            // languages.
            //
            // The identifier belongs on the Label INSIDE `tabItem`, not on the
            // tab's content view. Applied outside, it lands on the screen the tab
            // presents and never reaches the tab bar button, so
            // `app.tabBars.buttons["tab.home"]` matches nothing.
            .tabItem {
                Label("Home", systemImage: "house.fill")
                    .accessibilityIdentifier(AccessibilityID.homeTab)
            }
            .tag(AppTab.home)

            HistoryTabView(segment: $historySegment)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .accessibilityIdentifier(AccessibilityID.historyTab)
                }
                .tag(AppTab.history)

            MoreHubView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                        .accessibilityIdentifier(AccessibilityID.moreTab)
                }
                .tag(AppTab.more)
        }
        .tint(.chillPrimary)
        .fullScreenCover(isPresented: $isShowingShortcutLog) {
            LogNightSheet()
        }
        .onAppear {
            restoreLastTabIfNeeded()
            applyPendingDestination()
        }
        .onChange(of: pendingAppDestination) { _, _ in
            applyPendingDestination()
        }
        .onChange(of: selectedTab) { _, tab in
            lastSelectedTab = tab.rawValue
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                lastBackgroundedAt = Date.now.timeIntervalSince1970
            case .active:
                // A notification/shortcut destination takes priority; otherwise,
                // returning after a long absence snaps back to Home.
                if pendingAppDestination.isEmpty, shouldResetToHomeAfterBackground() {
                    selectedTab = .home
                }
            default:
                break
            }
        }
    }

    private func restoreLastTabIfNeeded() {
        guard pendingAppDestination.isEmpty else { return }

        // Coming back after a long time away should feel like a fresh start.
        if shouldResetToHomeAfterBackground() {
            selectedTab = .home
            return
        }

        guard let tab = AppTab(rawValue: lastSelectedTab) else { return }
        selectedTab = tab
    }

    /// True when the app has spent at least `backgroundResetThreshold` in the
    /// background since it was last foregrounded.
    private func shouldResetToHomeAfterBackground() -> Bool {
        guard lastBackgroundedAt > 0 else { return false }
        return Date.now.timeIntervalSince1970 - lastBackgroundedAt > backgroundResetThreshold
    }

    private func applyPendingDestination() {
        guard let destination = NotificationDestination(rawValue: pendingAppDestination) else {
            return
        }

        switch destination {
        case .home:
            selectedTab = .home
        case .log:
            selectedTab = .home
            isShowingShortcutLog = true
        case .saferPlan:
            selectedTab = .home
            careNavPath = [.saferPlanning]
        case .timers:
            selectedTab = .home
            careNavPath = [.drugTimers]
        case .emergency:
            selectedTab = .home
            careNavPath = [.emergency]
        case .panic:
            selectedTab = .home
            careNavPath = [.panicSupport]
        case .journal:
            historySegment = .journal
            selectedTab = .history
        case .safeRoute:
            selectedTab = .home
            careNavPath = [.groupDuring, .safeRoute]
        case .combinationRisk:
            selectedTab = .home
            careNavPath = [.combinationRisk]
        }

        pendingAppDestination = ""
    }
}

private enum MoreHubPage: String, Identifiable, CaseIterable {
    case profile = "Profile"
    case settings = "Settings"
    case supportDeveloper = "Support the developer"
    case feedback = "Feedback"
    case safetyAutopilot = "Safety autopilot"
    case privacyReceipt = "Privacy"
    case helperBridge = "Helper summary"
    case recoveryMode = "Recovery mode"
    case privateInsights = "Private insights"
    case unifiedTimeline = "Full timeline"
    case recentlyDeleted = "Recently deleted"
    case weeklyReflection = "Weekly reflection"
    case emergencyCard = "Emergency card"
    case supportDirectory = "Support"
    case privacyPolicy = "Privacy Policy"
    case termsOfUse = "Terms"
    case cravingDelay = "Craving delay"
    case drugChecking = "Checking info"

    var id: String { rawValue }

    static var visiblePages: [MoreHubPage] {
        groupedSections.flatMap(\.pages)
    }

    /// Compact grouping for the hub's default (non-searching) state. Search still
    /// spans every page, including the ones not surfaced here.
    static let groupedSections: [MoreHubSection] = [
        MoreHubSection(title: String(localized: "Your setup"), pages: [.profile, .settings, .privacyReceipt]),
        // Five screens that could only be found by searching, and one of them —
        // the full timeline — had no other way in at all.
        MoreHubSection(title: String(localized: "Your data"), pages: [.unifiedTimeline, .privateInsights, .weeklyReflection, .helperBridge, .recentlyDeleted]),
        MoreHubSection(title: String(localized: "Help & safety"), pages: [.emergencyCard, .supportDirectory]),
        MoreHubSection(title: String(localized: "About the app"), pages: [.supportDeveloper, .feedback])
    ]

    var title: String {
        switch self {
        case .profile:
            String(localized: "Profile")
        case .settings:
            String(localized: "Settings")
        case .supportDeveloper:
            String(localized: "Support the developer")
        case .safetyAutopilot:
            String(localized: "Safety autopilot")
        case .privacyReceipt:
            String(localized: "Privacy")
        case .helperBridge:
            String(localized: "Helper summary")
        case .recoveryMode:
            String(localized: "Recovery mode")
        case .privateInsights:
            String(localized: "Private insights")
        case .unifiedTimeline:
            String(localized: "Full timeline")
        case .recentlyDeleted:
            String(localized: "Recently deleted")
        case .weeklyReflection:
            String(localized: "Weekly reflection")
        case .emergencyCard:
            String(localized: "Emergency card")
        case .supportDirectory:
            String(localized: "Support")
        case .privacyPolicy:
            String(localized: "Privacy Policy")
        case .termsOfUse:
            String(localized: "Terms")
        case .cravingDelay:
            String(localized: "Craving delay")
        case .drugChecking:
            String(localized: "Checking info")
        case .feedback:
            String(localized: "Feedback")
        }
    }

    var subtitle: String {
        switch self {
        case .settings:
            String(localized: "Locks, alerts, look, and your data")
        case .supportDeveloper:
            String(localized: "Leave a tip to say thanks (optional)")
        case .profile:
            String(localized: "Your details, photo, medication, and PrEP")
        case .safetyAutopilot:
            String(localized: "A calm next step when things feel busy")
        case .privacyReceipt:
            String(localized: "What is kept, where it goes, and what protects it")
        case .helperBridge:
            String(localized: "A simple summary for a GP or helper")
        case .recoveryMode:
            String(localized: "Goals, cravings, and a fresh start")
        case .privateInsights:
            String(localized: "Your patterns over time")
        case .unifiedTimeline:
            String(localized: "Everything you saved, in one place")
        case .recentlyDeleted:
            String(localized: "Things you recently removed")
        case .weeklyReflection:
            String(localized: "A calm look at the last 7 days")
        case .emergencyCard:
            String(localized: "Important help info in one card")
        case .supportDirectory:
            String(localized: "Crisis lines and support where you live")
        case .privacyPolicy:
            String(localized: "How your private information is handled")
        case .termsOfUse:
            String(localized: "Safety, medical, and app boundaries")
        case .cravingDelay:
            String(localized: "Pause for 10 minutes before deciding")
        case .drugChecking:
            String(localized: "Testing and support information")
        case .feedback:
            String(localized: "Report a bug, share an idea, or ask a question")
        }
    }

    var symbol: String {
        switch self {
        case .settings:
            "gearshape.fill"
        case .supportDeveloper:
            "heart.fill"
        case .profile:
            "person.crop.circle.fill"
        case .safetyAutopilot:
            "sparkles.rectangle.stack.fill"
        case .privacyReceipt:
            "lock.shield.fill"
        case .helperBridge:
            "doc.text.magnifyingglass"
        case .recoveryMode:
            "figure.mind.and.body"
        case .privateInsights:
            "chart.xyaxis.line"
        case .unifiedTimeline:
            "timeline.selection"
        case .recentlyDeleted:
            "trash.circle.fill"
        case .weeklyReflection:
            "calendar.badge.clock"
        case .emergencyCard:
            "staroflife.fill"
        case .supportDirectory:
            "list.bullet.clipboard.fill"
        case .privacyPolicy:
            "hand.raised.square.fill"
        case .termsOfUse:
            "doc.text.fill"
        case .cravingDelay:
            "pause.circle.fill"
        case .drugChecking:
            "checkmark.seal.text.page.fill"
        case .feedback:
            "envelope.fill"
        }
    }

    var tint: Color {
        switch self {
        case .settings:
            Color.chillSecondaryBlue
        case .supportDeveloper:
            Color.chillIconPink
        case .profile:
            Color.chillMint
        case .safetyAutopilot:
            Color.chillSecondaryBlue
        case .privacyReceipt:
            Color.chillPrimary
        case .helperBridge:
            Color.chillMint
        case .recoveryMode:
            Color.chillPrimary
        case .privateInsights:
            Color.chillSecondaryBlue
        case .unifiedTimeline:
            Color.chillSecondaryBlue
        case .recentlyDeleted:
            Color.chillIconOrange
        case .weeklyReflection:
            Color.chillIconPurple
        case .emergencyCard:
            Color.chillIconRed
        case .supportDirectory:
            Color.chillSecondaryBlue
        case .privacyPolicy:
            Color.chillIconTeal
        case .termsOfUse:
            Color.chillIconPurple
        case .cravingDelay:
            Color.chillPrimary
        case .drugChecking:
            Color.chillIconAmber
        case .feedback:
            Color.chillIconTeal
        }
    }
}

private struct MoreHubSection: Identifiable {
    let title: String
    let pages: [MoreHubPage]
    var id: String { title }
}

private struct MoreHubRowLabel: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.chillText)
                Text(subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .chillLineLimit(1, scale: 0.74)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

private struct MoreHubView: View {
    @State private var searchText = ""

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredPages: [MoreHubPage] {
        guard !query.isEmpty else {
            return MoreHubPage.visiblePages
        }

        return MoreHubPage.allCases.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    /// Settings pages found by the same search. Searching More for "Face ID"
    /// used to find nothing, because the page that has it lives one level down.
    private var filteredSettings: [SettingsSectionPage] {
        guard !query.isEmpty else { return [] }
        return SettingsSectionPage.allCases.filter {
            $0.localizedDisplayName.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
            DashboardBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(
                        title: String(localized: "More"),
                        subtitle: String(localized: "Your profile, settings, and privacy tools in one place."),
                        symbol: "ellipsis.circle.fill",
                        tint: Color.chillSecondaryBlue
                    )

                    searchField

                    VStack(spacing: 8) {
                        if query.isEmpty {
                            // Compact grouped layout for browsing; search stays flat.
                            ForEach(MoreHubPage.groupedSections) { section in
                                Text(section.title)
                                    .font(.caption.weight(.bold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(Color.chillSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 6)
                                    .padding(.top, 8)

                                ForEach(section.pages) { page in
                                    moreHubRow(page)
                                }
                            }
                        } else if filteredPages.isEmpty && filteredSettings.isEmpty {
                            Text("No results found.")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Color.chillSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .glassSurface(radius: 24, tint: .black.opacity(0.04))
                        } else {
                            ForEach(filteredPages) { page in
                                moreHubRow(page)
                            }
                            ForEach(filteredSettings) { page in
                                settingsResultRow(page)
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .endEditingOnTap()
        // More hides its navigation bar, so the panic control goes in the corner
        // rather than in a toolbar that is not there.
        .panicHideOverlay()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: MoreHubPage.self) { page in
            moreHubDestination(page)
                .navigationTitle(Text(verbatim: ""))
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
        }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.chillSecondary)
                .accessibilityHidden(true)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.chillText)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.chillSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassSurface(radius: 18, tint: .white.opacity(0.30), interactive: true)
    }

    /// A Settings page in the results, opened straight onto that page. A plain
    /// destination link rather than a value, so it cannot collide with the
    /// `SettingsSectionPage` destination Settings registers for its own list.
    private func settingsResultRow(_ page: SettingsSectionPage) -> some View {
        NavigationLink {
            SettingsView(showsBackButton: false, openingPage: page)
                .toolbar(.hidden, for: .tabBar)
        } label: {
            MoreHubRowLabel(
                title: page.localizedDisplayName,
                subtitle: String(localized: "Settings · \(page.subtitle)"),
                symbol: page.symbol,
                tint: Color.chillPrimary
            )
        }
        .buttonStyle(ChillPlainButtonStyle())
        .glassSurface(radius: 20, tint: Color.chillPrimary.opacity(0.07), interactive: true)
    }

    private func moreHubRow(_ page: MoreHubPage) -> some View {
        NavigationLink(value: page) {
            MoreHubRowLabel(title: page.title, subtitle: page.subtitle, symbol: page.symbol, tint: page.tint)
        }
        .buttonStyle(ChillPlainButtonStyle())
        .glassSurface(radius: 20, tint: page.tint.opacity(0.07), interactive: true)
    }

    @ViewBuilder
    private func moreHubDestination(_ page: MoreHubPage) -> some View {
        switch page {
        case .settings:
            // Pushed onto the More stack: rely on the system back button.
            // Passing a custom chevron here would stack on top of the system
            // one (two overlapping chevrons during the swipe-back).
            SettingsView(showsBackButton: false)
        case .supportDeveloper:
            SupportDeveloperView()
        case .feedback:
            FeedbackView(showsBackButton: false)
        case .profile:
            ProfileOverviewView(showsBackButton: false)
        case .safetyAutopilot:
            SafetyAutopilotView()
        case .privacyReceipt:
            PrivacyReceiptView()
        case .helperBridge:
            ProfessionalHelperBridgeView()
        case .recoveryMode:
            RecoveryModeView()
        case .privateInsights:
            PrivateInsightsView()
        case .unifiedTimeline:
            UnifiedTimelineView()
        case .recentlyDeleted:
            RecentlyDeletedView()
        case .weeklyReflection:
            WeeklyReflectionView()
        case .emergencyCard:
            EmergencyCardView()
        case .supportDirectory:
            NetherlandsSupportDirectoryView()
        case .privacyPolicy:
            PrivacyPolicyView()
        case .termsOfUse:
            TermsOfUseView()
        case .cravingDelay:
            CravingDelayView()
        case .drugChecking:
            DrugCheckingEducationView()
        }
    }
}
