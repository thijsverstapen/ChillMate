import Contacts
import ContactsUI
import CoreMotion
import PhotosUI
import StoreKit
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

#if canImport(DeclaredAgeRange)
@unsafe @preconcurrency import DeclaredAgeRange
#endif

struct AppHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(ChillMateQueries.profile) private var profiles: [UserProfile]
    @AppStorage(DefaultsKey.lastOnDeviceRecoveryStatus) private var lastOnDeviceRecoveryStatus = ""
    @AppStorage(DefaultsKey.iCloudBackupEnabled) private var iCloudBackupEnabled = false
    @AppStorage(DefaultsKey.lastICloudBackupStatus) private var lastICloudBackupStatus = ""
    @AppStorage(DefaultsKey.lastICloudBackupTimestamp) private var lastICloudBackupTimestamp = 0.0
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
            if let summary = try EncryptedBackupService.shared.restoreOnDeviceRecoverySnapshotIfNeeded(into: modelContext) {
                lastOnDeviceRecoveryStatus = "Recovered \(summary.totalItems) encrypted items from this iPhone."
            }
        } catch {
            lastOnDeviceRecoveryStatus = "Automatic recovery could not open the encrypted on-device backup."
        }
    }

    @MainActor
    private func refreshOnDeviceRecoverySnapshot() async {
        // The two backups fail independently. A shared catch used to blame the
        // on-device snapshot whenever the iCloud save threw (e.g. iCloud Drive
        // unavailable), surfacing a persistent, misleading error status on every
        // backgrounding.
        do {
            if try EncryptedBackupService.shared.refreshOnDeviceRecoverySnapshot(localContext: modelContext) {
                lastOnDeviceRecoveryStatus = "Encrypted on-device recovery backup updated."
            }
        } catch {
            lastOnDeviceRecoveryStatus = "Encrypted on-device recovery backup could not update."
        }

        guard iCloudBackupEnabled else { return }
        do {
            let date = try ICloudBackupService.shared.saveLatestBackup(localContext: modelContext)
            lastICloudBackupTimestamp = date.timeIntervalSince1970
            lastICloudBackupStatus = "Encrypted iCloud backup updated."
        } catch {
            // Signed out of iCloud is an expected state, not a failure worth an
            // alarming banner; keep the wording calm and actionable.
            lastICloudBackupStatus = ICloudBackupService.shared.isAvailable
                ? "Encrypted iCloud backup could not update."
                : String(localized: "iCloud backup is paused. Sign in to iCloud with iCloud Drive on to resume.")
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
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            // Locale-independent handles for UI tests. The tests used to query
            // tab bar items by their English label, so they could only ever
            // pass in English — including the run that launches in all five
            // languages.
            .accessibilityIdentifier(AccessibilityID.homeTab)
            .tag(AppTab.home)

            HistoryTabView(segment: $historySegment)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .accessibilityIdentifier(AccessibilityID.historyTab)
                .tag(AppTab.history)

            MoreHubView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
                .accessibilityIdentifier(AccessibilityID.moreTab)
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
    case privacyTimeline = "Privacy timeline"
    case securityHealth = "Security check"
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

    static let visiblePages: [MoreHubPage] = [
        .profile,
        .settings,
        .supportDeveloper,
        .feedback,
        .privacyReceipt,
        .emergencyCard,
        .supportDirectory
    ]

    /// Compact grouping for the hub's default (non-searching) state. Search still
    /// spans every page, including the ones not surfaced here.
    static let groupedSections: [MoreHubSection] = [
        MoreHubSection(title: String(localized: "Your setup"), pages: [.profile, .settings, .privacyReceipt]),
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
        case .privacyTimeline:
            String(localized: "Privacy timeline")
        case .securityHealth:
            String(localized: "Security check")
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
            String(localized: "What is saved, policies, and terms")
        case .privacyTimeline:
            String(localized: "Recent backup, restore, and lock activity")
        case .securityHealth:
            String(localized: "See which privacy options are on")
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
            String(localized: "Dutch help lines and support")
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
        case .privacyTimeline:
            "clock.badge.checkmark.fill"
        case .securityHealth:
            "checkmark.shield.fill"
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
        case .privacyTimeline:
            Color.chillIconTeal
        case .securityHealth:
            Color.chillMint
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

private struct MoreHubView: View {
    @State private var searchText = ""

    private var filteredPages: [MoreHubPage] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return MoreHubPage.visiblePages
        }

        return MoreHubPage.allCases.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
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

                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.chillText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .glassSurface(radius: 18, tint: .white.opacity(0.30), interactive: true)

                    VStack(spacing: 8) {
                        if filteredPages.isEmpty {
                            Text("No results found.")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Color.chillSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .glassSurface(radius: 24, tint: .black.opacity(0.04))
                        }

                        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                        } else {
                            ForEach(filteredPages) { page in
                                moreHubRow(page)
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
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: MoreHubPage.self) { page in
            moreHubDestination(page)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
        }
        }
    }

    private func moreHubRow(_ page: MoreHubPage) -> some View {
        NavigationLink(value: page) {
            HStack(spacing: 12) {
                Image(systemName: page.symbol)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(page.tint)
                    .frame(width: 36, height: 36)
                    .background(page.tint.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(page.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.chillText)
                    Text(page.subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
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
        case .privacyTimeline:
            PrivacyTimelineView()
        case .securityHealth:
            SecurityHealthCheckView()
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

// MARK: - Support the developer (tip jar via In-App Purchase)

/// Tips use StoreKit In-App Purchase. Apple requires IAP for developer tips,
/// so external links, Apple Pay, and Revolut are not allowed. Create these as
/// **Consumable** products in App Store Connect with matching identifiers and
/// your chosen prices; they then load and display automatically. Arbitrary
/// "custom" amounts are not possible with IAP, so we offer fixed tiers.
private enum TipProduct {
    static let coffee = "com.BIJTHIJS.ChillMate.tip.coffee"
    static let pizza = "com.BIJTHIJS.ChillMate.tip.pizza"
    static let generous = "com.BIJTHIJS.ChillMate.tip.generous"
    static let all = [coffee, pizza, generous]
}

private struct TipOption: Identifiable {
    let id: String          // StoreKit product identifier
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let fallbackPrice: String
}

struct SupportDeveloperView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = TipStore()

    private let options: [TipOption] = [
        TipOption(id: TipProduct.coffee, title: String(localized: "Buy me a coffee"), detail: String(localized: "A little caffeine for late-night coding"), symbol: "cup.and.saucer.fill", tint: Color.chillIconAmber, fallbackPrice: "€3"),
        TipOption(id: TipProduct.pizza, title: String(localized: "Treat me to a pizza"), detail: String(localized: "Fuel for a whole new feature"), symbol: "fork.knife", tint: Color.chillIconOrange, fallbackPrice: "€10"),
        TipOption(id: TipProduct.generous, title: String(localized: "Sponsor a feature"), detail: String(localized: "Wow, thank you so much"), symbol: "sparkles", tint: Color.chillIconPink, fallbackPrice: "€25")
    ]

    @State private var selectedID = TipProduct.coffee
    @State private var isPurchasing = false
    @State private var alertTitle = "Thank you 💜"
    @State private var alertMessage: String?

    private func priceText(for option: TipOption) -> String {
        store.products.first { $0.id == option.id }?.displayPrice ?? option.fallbackPrice
    }

    private var selectedOption: TipOption? {
        options.first { $0.id == selectedID }
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Support the developer"),
                            subtitle: String(localized: "ChillMate is free for everyone. A tip is a small, completely optional way to say thanks."),
                            symbol: "heart.fill",
                            tint: Color.chillIconPink
                        )

                        storyCard

                        VStack(alignment: .leading, spacing: 10) {
                            Label("Choose a tip", systemImage: "gift.fill")
                                .font(.headline)
                                .foregroundStyle(Color.chillText)

                            ForEach(options) { tipRow($0) }
                        }

                        payButton

                        Text("Tips are a voluntary gift to the developer through the App Store. They don't unlock any features or content, everything in ChillMate stays free. Thank you for being here. 💜")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .task { await store.loadProducts() }
            .alert(alertTitle, isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("Close", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private var storyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hey, thank you for using ChillMate 👋")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("I build ChillMate on my own, on late nights and weekends, because I wanted a calm, private place to look after yourself, with no judgment. It's completely free: no ads, nothing locked behind a paywall, and it will stay that way.")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("If ChillMate has helped you feel a little safer or more in control, a small tip is a lovely way to say thanks. Every bit goes straight back into keeping the app running, updated, and free for everyone.")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Thijs 💜")
                .font(.headline.weight(.heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.chillPrimary, Color.chillSecondaryBlue, Color.chillMint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(radius: 26, tint: Color.chillIconPink.opacity(0.10), interactive: true)
    }

    private func tipRow(_ tip: TipOption) -> some View {
        let isSelected = selectedID == tip.id
        return Button {
            withAnimation(.snappy) { selectedID = tip.id }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tip.symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tip.tint)
                    .frame(width: 40, height: 40)
                    .background(tip.tint.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(tip.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.chillText)
                    Text(tip.detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(priceText(for: tip))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.chillText)

                selectionDot(isSelected)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .glassSurface(radius: 20, tint: tip.tint.opacity(isSelected ? 0.16 : 0.06), interactive: true)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(tip.tint.opacity(isSelected ? 0.7 : 0), lineWidth: 1.5)
            }
        }
        .buttonStyle(ChillPlainButtonStyle())
    }

    private func selectionDot(_ isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(isSelected ? Color.chillMint : Color.chillSecondary.opacity(0.5))
    }

    @ViewBuilder
    private var payButton: some View {
        let priceLabel = selectedOption.map { priceText(for: $0) } ?? ""
        let isLoadingProducts = store.loadState == .loading
        let loadFailed = store.loadState == .failed || (store.loadState == .loaded && store.products.isEmpty)
        let isBlocked = isPurchasing || isLoadingProducts

        if loadFailed {
            Button {
                Task { await store.retryLoad() }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline)
                    Text("Retry")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.chillSecondary.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(ChillPlainButtonStyle())
        } else {
            Button(action: purchase) {
                HStack(spacing: 9) {
                    if isBlocked {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "heart.fill")
                            .font(.headline)
                    }
                    Text(isPurchasing ? String(localized: "Processing…") :
                         isLoadingProducts ? String(localized: "Loading…") :
                         String(localized: "Leave a \(priceLabel) tip"))
                        .font(.headline.weight(.bold))
                        .sensoryFeedback(trigger: isPurchasing) { _, purchasing in purchasing ? .impact(weight: .medium) : nil }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color.chillPrimary, Color.chillSecondaryBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(ChillPlainButtonStyle())
            .opacity(isBlocked ? 0.6 : 1)
            .allowsHitTesting(!isBlocked)
        }
    }

    private func purchase() {
        if store.loadState == .loading {
            return
        }
        guard let product = store.products.first(where: { $0.id == selectedID }) else {
            alertTitle = "Tips unavailable"
            alertMessage = "Tipping isn't available right now. Make sure you're signed in to the App Store, then try again."
            return
        }

        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            switch await store.purchase(product) {
            case .success:
                alertTitle = "Thank you 💜"
                alertMessage = "Your tip means the world and helps keep ChillMate free and updated."
            case .cancelled:
                break
            case .failed(let message):
                alertTitle = "Something went wrong"
                alertMessage = message ?? "The tip could not be completed. Please try again."
            }
        }
    }
}

/// Loads and purchases the tip In-App Purchases via StoreKit 2.
@MainActor
final class TipStore: ObservableObject {
    enum Outcome { case success, cancelled, failed(String?) }
    enum LoadState { case idle, loading, loaded, failed }

    @Published private(set) var products: [Product] = []
    @Published private(set) var loadState: LoadState = .idle

    func loadProducts() async {
        guard products.isEmpty else { return }
        loadState = .loading
        do {
            let fetched = try await Product.products(for: TipProduct.all)
            products = fetched.sorted { $0.price < $1.price }
            loadState = .loaded
        } catch {
            products = []
            loadState = .failed
        }
    }

    func retryLoad() async {
        loadState = .idle
        products = []
        await loadProducts()
    }

    func purchase(_ product: Product) async -> Outcome {
        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return .success
                case .unverified:
                    return .failed("Your purchase could not be verified.")
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .failed("Your purchase is pending approval.")
            @unknown default:
                return .failed(nil)
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

private enum ProfileSetupStep: Int, CaseIterable, Identifiable {
    case basicDetails = 1
    case identityAndHealth = 2
    case safetyAndEmergency = 3
    case featuresAndPermissions = 4

    var id: Int { rawValue }
}

/// Optional, privacy-preserving 18+ confirmation backed by Apple's
/// `DeclaredAgeRange`. It augments the self-entered date of birth: the app never
/// receives a birthdate from Apple, only a coarse age-range signal the user
/// explicitly chooses to share.
struct AgeAssuranceRow: View {
    let verified: Bool
    let underage: Bool
    let isChecking: Bool
    let message: String?
    let action: () -> Void

    private var icon: String {
        if verified { return "checkmark.seal.fill" }
        if underage { return "exclamationmark.triangle.fill" }
        return "person.badge.shield.checkmark"
    }

    private var iconTint: Color {
        if verified { return .chillIconGreen }
        if underage { return .chillIconRed }
        return .chillPrimary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(iconTint)
                    .frame(width: 30, height: 30)
                    .glassSurface(radius: 15, tint: iconTint.opacity(0.14))

                VStack(alignment: .leading, spacing: 2) {
                    Text(verified ? "Age confirmed with Apple" : "Confirm you're 18 or older")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                    Text(verified
                        ? String(localized: "Verified privately through your Apple Account.")
                        : String(localized: "Optional. Uses Apple's age range, never your birthdate."))
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if !verified {
                    Button(action: action) {
                        if isChecking {
                            ProgressView().tint(Color.chillPrimary)
                        } else {
                            Text("Confirm")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.chillPrimary)
                        }
                    }
                    .disabled(isChecking)
                }
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(underage ? .red : Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

/// Collapsible, plain-language explainer shown next to the age gate so people
/// understand why ChillMate asks their age and how the privacy-preserving check
/// works. Collapsed by default to keep the setup step calm.
struct AgeVerificationInfo: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.chillPrimary)
                    Text("Why verify your age, and how it works")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                    Spacer(minLength: 4)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.chillSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ChillMate is an adults-only wellbeing app. It includes harm-reduction, sexual-health, and substance-safety information written for people 18 and older, so it checks your age before creating a profile.")
                    Text("You can confirm your age in two private ways. The date of birth you enter stays on this device. The optional Apple Account check returns only a yes-or-no \"18 or older\" answer from Apple; it never shares your birthdate or name with the app.")
                    Text("Your age is used only on this device to unlock ChillMate. It is never sent to the developer, never uploaded, and never shared. You can leave the Apple check off and simply use your date of birth.")
                }
                .font(.caption)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

struct ProfileSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(DefaultsKey.healthKitAutoSync) private var healthKitAutoSync = false
    @AppStorage(DefaultsKey.healthKitSexualActivityWriteEnabled) private var healthKitSexualActivityWriteEnabled = false
    @AppStorage(DefaultsKey.healthKitSleepReadWriteEnabled) private var healthKitSleepReadWriteEnabled = false
    @AppStorage(DefaultsKey.healthKitHeartRateReadEnabled) private var healthKitHeartRateReadEnabled = false
    @AppStorage(DefaultsKey.healthKitHRVReadEnabled) private var healthKitHRVReadEnabled = false
    @AppStorage(DefaultsKey.healthKitWorkoutReadEnabled) private var healthKitWorkoutReadEnabled = false
    @AppStorage(DefaultsKey.appLanguage) private var appLanguage = "en"
    @AppStorage(DefaultsKey.country) private var country = "Netherlands"
    @AppStorage(DefaultsKey.notificationsEnabled) private var notificationsEnabled = false
    @AppStorage(DefaultsKey.dailyAffirmationsEnabled) private var dailyAffirmationsEnabled = false
    @AppStorage(DefaultsKey.requiresFaceID) private var requiresFaceID = false
    @AppStorage(DefaultsKey.locationServicesChecked) private var locationServicesChecked = false
    @AppStorage(DefaultsKey.iCloudBackupEnabled) private var iCloudBackupEnabled = false
    @AppStorage(DefaultsKey.lastICloudBackupStatus) private var lastICloudBackupStatus = ""
    @AppStorage(DefaultsKey.trustedContactName) private var trustedContactName = ""
    @AppStorage(DefaultsKey.trustedContactPhone) private var trustedContactPhone = ""
    @AppStorage(DefaultsKey.trustedContactMessage) private var trustedContactMessage = "Please come get me, I’m not okay at this moment."

    @State private var hasSeenIntroduction = false
    @State private var setupStep: ProfileSetupStep = .basicDetails
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImageData: Data?
    @State private var hasAgreed = false
    @State private var name = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date.now) ?? Date.now
    @State private var sex: ProfileSex = .preferNotToSay
    @State private var sexualOrientation: SexualOrientation = .preferNotToSay
    @State private var sexualRole: SexualRole = .preferNotToSay
    @State private var isOnPrEP = false
    @State private var prepStartDate = Date.now
    @State private var prepSchedule: PrEPSchedule = .daily
    @State private var weightKg = 75.0
    @State private var heightCm = 175.0
    @State private var homeStreet = ""
    @State private var homeHouseNumber = ""
    @State private var homePostalCode = ""
    @State private var homeCity = ""
    @State private var homeCountry = "Netherlands"
    @State private var usesCurrentMedication = false
    @State private var medications: [ProfileMedication] = []
    @State private var medicationName = ""
    @State private var medicationDosage = ""
    @State private var medicationTakenAt = Date.now
    @State private var medicationEffectiveHours = 8.0
    @State private var permissionMessage: String?
    @State private var backupImportMessage: String?
    @State private var isCheckingPermissions = false
    @State private var isShowingPermissionWarning = false
    @State private var isShowingBackupImporter = false
    @State private var isImportingBackup = false
    @State private var isRestoringICloudBackup = false
    @State private var isShowingTrustedContactPicker = false

    // MARK: Age assurance (DeclaredAgeRange)
    /// Set once Apple's age-range signal confirms 18+, so we don't re-prompt.
    @AppStorage(DefaultsKey.ageAssuranceVerifiedAdult) private var ageAssuranceVerifiedAdult = false
    /// True only when Apple positively reports the account is under 18. Persisted
    /// so the 18+ block survives an app relaunch (a determined relaunch must not
    /// silently clear an authoritative under-18 signal).
    @AppStorage(DefaultsKey.ageAssuranceUnderage) private var ageAssuranceUnderage = false
    @State private var isCheckingAgeRange = false
    @State private var ageAssuranceMessage: String?
    #if canImport(DeclaredAgeRange)
    @Environment(\.requestAgeRange) private var requestAgeRange
    #endif

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && calculatedAge >= 18
    }

    private var calculatedAge: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: .now).year ?? 18
    }

    private var shouldShowSexualRole: Bool {
        let eligibleSex = sex == .male || sex == .nonBinary
        let eligibleOrientation = sexualOrientation == .gay
            || sexualOrientation == .bisexual
            || sexualOrientation == .queer
            || sexualOrientation == .questioning

        return eligibleSex && eligibleOrientation
    }

    private var allPersonalizationFeaturesEnabled: Bool {
        healthKitAutoSync && notificationsEnabled && locationServicesChecked && iCloudBackupEnabled
    }

    private var formattedHomeAddress: String {
        let streetLine = [homeStreet, homeHouseNumber]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let cityLine = [homePostalCode, homeCity]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return [streetLine, cityLine, homeCountry.trimmingCharacters(in: .whitespacesAndNewlines)]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                if hasSeenIntroduction {
                    VStack(spacing: 0) {
                        SetupWizardProgressBar(step: setupStep)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 2)

                        TabView(selection: $setupStep) {
                            ForEach(ProfileSetupStep.allCases) { step in
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 22) {
                                        stepContent(step)
                                    }
                                    .frame(maxWidth: 600, alignment: .leading)
                                    .frame(maxWidth: .infinity)
                                    .padding(20)
                                    .padding(.bottom, 24)
                                }
                                .scrollIndicators(.hidden)
                                .scrollDismissesKeyboard(.interactively)
                                .tag(step)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut(duration: 0.3), value: setupStep)

                        SetupWizardFooter(
                            step: setupStep,
                            canAdvance: footerCanAdvance,
                            reason: footerDisabledReason,
                            onBack: goToPreviousStep,
                            onNext: goToNextStep
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    }
                    // The wizard rises softly into place as the intro dissolves, so the
                    // two read as one continuous flow rather than a hard cut.
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    ProfileIntroductionView {
                        withAnimation(.easeInOut(duration: 0.55)) {
                            hasSeenIntroduction = true
                        }
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("")
            .liquidGlassAlert(
                isPresented: $isShowingPermissionWarning,
                title: String(localized: "Continue without everything on?"),
                message: String(localized: "ChillMate still works. Apple Health, notifications, location, and iCloud backup just make reminders, recovery, emergency messages, and restore easier."),
                primaryTitle: String(localized: "Yes, continue"),
                primaryAction: createProfile,
                secondaryTitle: String(localized: "Review permissions")
            )
            .fileImporter(
                isPresented: $isShowingBackupImporter,
                allowedContentTypes: [UTType(filenameExtension: "cmbak") ?? .data, .data, .json],
                allowsMultipleSelection: false,
                onCompletion: handleBackupImport
            )
            .sheet(isPresented: $isShowingTrustedContactPicker) {
                ContactPicker { contact in
                    trustedContactName = contact.name
                    trustedContactPhone = contact.phoneNumber
                }
            }
            .endEditingOnTap()
            .onChange(of: selectedPhoto) { _, newValue in
                loadProfilePhoto(newValue)
            }
        }
    }

    @ViewBuilder
    private func stepContent(_ step: ProfileSetupStep) -> some View {
        switch step {
        case .basicDetails:
            basicDetailsStep
        case .identityAndHealth:
            identityStep
        case .safetyAndEmergency:
            safetyStep
        case .featuresAndPermissions:
            permissionsStep
        }
    }

    @ViewBuilder
    private var basicDetailsStep: some View {
        ProfileSetupPhotoPicker(imageData: profileImageData, selectedPhoto: $selectedPhoto)

                VStack(alignment: .leading, spacing: 16) {
                    ProfileSetupSectionHeader(
                        eyebrow: String(localized: "Step 1 of 4"),
                        title: String(localized: "Let’s set up your profile"),
                        subtitle: String(localized: "Add what feels useful now. You can change it later.")
                    )

                    ProfileSetupBackupImportCard(
                        isImporting: isImportingBackup,
                        isRestoringICloud: isRestoringICloudBackup,
                        message: backupImportMessage,
                        importAction: {
                            isShowingBackupImporter = true
                        },
                        restoreICloudAction: {
                            restoreICloudBackup()
                        }
                    )

                    VStack(spacing: 0) {
                        ProfileSetupPickerRow(
                            title: String(localized: "Language"),
                            systemImage: "globe"
                        ) {
                            Picker("Language", selection: $appLanguage) {
                                ForEach(AppLanguage.allCases) { language in
                                    Text(verbatim: language.endonym).tag(language.rawValue)
                                }
                            }
                        }
                        .onChange(of: appLanguage) { _, newValue in
                            // Writes AppleLanguages, which is what actually selects
                            // the bundle's .lproj. Without this the picker only
                            // stored a string nothing read.
                            guard let language = AppLanguage.matching(newValue) else { return }
                            LocalizationService.apply(language)
                        }

                        if LocalizationService.pendingRestart {
                            // Bundle localization is resolved once at process start,
                            // so the new language applies on the next launch. Say so
                            // rather than letting the screen look broken.
                            Label(
                                String(localized: "Reopen ChillMate to finish switching language."),
                                systemImage: "arrow.clockwise"
                            )
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }

                        ProfileSetupRowDivider()

                        ProfileSetupPickerRow(
                            title: String(localized: "Country"),
                            systemImage: "mappin.and.ellipse"
                        ) {
                            // Names come from Locale, so they translate with the app
                            // instead of being hard-coded English. The tag stays the
                            // English rawValue because it is the persisted key that
                            // SupportResource and EmergencyContactInfo match on.
                            Picker("Country", selection: $country) {
                                ForEach(SupportedCountry.allCases) { supported in
                                    Text(supported.displayName).tag(supported.rawValue)
                                }
                            }
                        }

                        ProfileSetupRowDivider()

                        ProfileSetupTextField(
                            title: String(localized: "Name"),
                            placeholder: String(localized: "Enter your name"),
                            text: $name,
                            systemImage: "person.fill"
                        )

                        ProfileSetupRowDivider()

                        ProfileSetupDateRow(
                            title: String(localized: "Date of birth (\(calculatedAge))"),
                            date: $dateOfBirth,
                            systemImage: "calendar"
                        )

                        if calculatedAge < 18 {
                            ProfileSetupRowDivider()

                            Text("ChillMate is for adults. You need to be 18 or older to create an account.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        }

                        #if canImport(DeclaredAgeRange)
                        ProfileSetupRowDivider()

                        AgeAssuranceRow(
                            verified: ageAssuranceVerifiedAdult,
                            underage: ageAssuranceUnderage,
                            isChecking: isCheckingAgeRange,
                            message: ageAssuranceMessage,
                            action: { Task { await verifyAgeWithAppleAccount() } }
                        )
                        #endif

                        ProfileSetupRowDivider()

                        AgeVerificationInfo()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
                }
    }

    @ViewBuilder
    private var identityStep: some View {
                VStack(alignment: .leading, spacing: 16) {
                    ProfileSetupSectionHeader(
                        eyebrow: String(localized: "Step 2 of 4"),
                        title: String(localized: "Identity & preferences"),
                        subtitle: String(localized: "(Optional) This helps ChillMate make your overview feel more personal.")
                    )

                    VStack(spacing: 0) {
                        ProfileSetupPickerRow(
                            title: String(localized: "Sex"),
                            systemImage: "person.2.fill"
                        ) {
                            Picker("Sex", selection: $sex) {
                                ForEach(ProfileSex.allCases) { option in
                                    Text(option.localizedDisplayName).tag(option)
                                }
                            }
                        }

                        ProfileSetupRowDivider()

                        ProfileSetupPickerRow(
                            title: String(localized: "Orientation"),
                            systemImage: "heart.fill"
                        ) {
                            Picker("Sexual orientation", selection: $sexualOrientation) {
                                ForEach(SexualOrientation.allCases) { option in
                                    Text(option.localizedDisplayName).tag(option)
                                }
                            }
                        }

                        if shouldShowSexualRole {
                            ProfileSetupRowDivider()

                            ProfileSetupPickerRow(
                                title: String(localized: "Role"),
                                systemImage: "arrow.left.arrow.right"
                            ) {
                                Picker("Role", selection: $sexualRole) {
                                    ForEach(SexualRole.allCases.filter { $0 != .notApplicable }) { option in
                                        Text(option.localizedDisplayName).tag(option)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
                }
    }

    @ViewBuilder
    private var safetyStep: some View {
                VStack(alignment: .leading, spacing: 16) {
                    ProfileSetupSectionHeader(
                        eyebrow: String(localized: "Step 3 of 4"),
                        title: String(localized: "Home information"),
                        subtitle: String(localized: "Optional. This helps the Route tab get you home faster.")
                    )

                    VStack(spacing: 0) {
                        ProfileSetupTextField(
                            title: String(localized: "Street"),
                            placeholder: String(localized: "Street name"),
                            text: $homeStreet,
                            systemImage: "house.fill"
                        )

                        ProfileSetupRowDivider()

                        ProfileSetupTextField(
                            title: String(localized: "House number"),
                            placeholder: String(localized: "Number or addition"),
                            text: $homeHouseNumber,
                            systemImage: "number"
                        )

                        ProfileSetupRowDivider()

                        ProfileSetupTextField(
                            title: String(localized: "Postal code"),
                            placeholder: String(localized: "Postal code"),
                            text: $homePostalCode,
                            systemImage: "envelope.fill"
                        )

                        ProfileSetupRowDivider()

                        ProfileSetupTextField(
                            title: String(localized: "City"),
                            placeholder: String(localized: "City"),
                            text: $homeCity,
                            systemImage: "building.2.fill"
                        )

                        ProfileSetupRowDivider()

                        ProfileSetupTextField(
                            title: String(localized: "Country"),
                            placeholder: String(localized: "Country"),
                            text: $homeCountry,
                            systemImage: "globe.europe.africa.fill"
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
                }

                VStack(alignment: .leading, spacing: 16) {
                    ProfileSetupSectionHeader(
                        eyebrow: String(localized: "Step 3 of 4"),
                        title: String(localized: "Emergency contact"),
                        subtitle: String(localized: "Optional, but helpful. You can call or message this person from Emergency, Panic support, and Safe Route.")
                    )

                    VStack(spacing: 0) {
                        // Import from Contacts button
                        Button {
                            isShowingTrustedContactPicker = true
                        } label: {
                            HStack(spacing: 12) {
                                ProfileSetupIcon(systemImage: "person.crop.circle.badge.plus")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trustedContactName.isEmpty ? String(localized: "Import from Contacts") : trustedContactName)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(trustedContactName.isEmpty ? Color.chillPrimary : Color.chillText)
                                    if !trustedContactPhone.isEmpty {
                                        Text(trustedContactPhone)
                                            .font(.caption)
                                            .foregroundStyle(Color.chillSecondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.chillTertiary)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(ChillPlainButtonStyle())

                        ProfileSetupRowDivider()

                        ProfileSetupTextField(
                            title: String(localized: "Message to send"),
                            placeholder: String(localized: "Short message to send if you need help"),
                            text: $trustedContactMessage,
                            systemImage: "message.fill"
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassSurface(radius: 28, tint: Color.chillMint.opacity(0.08), interactive: true)
                }

                VStack(alignment: .leading, spacing: 16) {
                    ProfileSetupSectionHeader(
                        eyebrow: String(localized: "Health context"),
                        title: String(localized: "Body information"),
                        subtitle: String(localized: "This helps with your profile and timer estimates.")
                    )

                    VStack(spacing: 0) {
                        ProfileSetupMeasurementRow(
                            title: String(localized: "Weight"),
                            value: $weightKg,
                            range: 35...180,
                            unit: "kg",
                            systemImage: "scalemass.fill"
                        )

                        ProfileSetupRowDivider()

                        ProfileSetupMeasurementRow(
                            title: String(localized: "Height"),
                            value: $heightCm,
                            range: 130...220,
                            unit: "cm",
                            systemImage: "ruler.fill"
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
                }

                VStack(alignment: .leading, spacing: 16) {
                    ProfileSetupSectionHeader(
                        eyebrow: String(localized: "Health context"),
                        title: String(localized: "PrEP status"),
                        subtitle: String(localized: "Optional. Add it if you want reminders or easier planning.")
                    )

                    VStack(spacing: 0) {
                        ProfileSetupToggleRow(
                            title: String(localized: "On PrEP"),
                            subtitle: isOnPrEP ? "Enabled" : "Not enabled",
                            isOn: $isOnPrEP,
                            systemImage: "cross.case.fill"
                        )

                        if isOnPrEP {
                            ProfileSetupRowDivider()

                            ProfileSetupPickerRow(
                                title: String(localized: "PrEP schedule"),
                                systemImage: "clock.badge.checkmark.fill"
                            ) {
                                Picker("PrEP schedule", selection: $prepSchedule) {
                                    ForEach(PrEPSchedule.allCases) { option in
                                        Text(option.localizedDisplayName).tag(option)
                                    }
                                }
                            }

                            ProfileSetupRowDivider()

                            ProfileSetupDateRow(
                                title: String(localized: "Since"),
                                date: $prepStartDate,
                                systemImage: "calendar.badge.clock"
                            )

                            if prepSchedule == .daily && Calendar.current.dateComponents([.day], from: prepStartDate, to: .now).day ?? 0 < 7 {
                                ProfileSetupRowDivider()

                                Text("Daily PrEP needs about 7 days to reach maximum protection for receptive anal sex. Until then, use extra protection and follow medical advice.")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.red)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
                }

                ProfileSetupMedicationSection(
                    isEnabled: $usesCurrentMedication,
                    medications: $medications,
                    name: $medicationName,
                    dosage: $medicationDosage,
                    takenAt: $medicationTakenAt,
                    effectiveHours: $medicationEffectiveHours
                )
    }

    @ViewBuilder
    private var permissionsStep: some View {
        ProfilePermissionsPage(
            healthKitAutoSync: $healthKitAutoSync,
            notificationsEnabled: $notificationsEnabled,
            dailyAffirmationsEnabled: $dailyAffirmationsEnabled,
            requiresFaceID: $requiresFaceID,
            locationServicesChecked: $locationServicesChecked,
            iCloudBackupEnabled: $iCloudBackupEnabled,
            message: permissionMessage,
            isChecking: isCheckingPermissions,
            requestHealth: requestHealthPermission,
            requestNotifications: requestNotificationPermission,
            requestFaceID: requestFaceID,
            requestLocation: requestLocationPermission,
            requestICloud: requestICloudBackup,
            hasAgreed: $hasAgreed
        )
    }

    #if canImport(DeclaredAgeRange)
    /// Asks Apple for a privacy-preserving age-range signal (18+ gate). The app
    /// only learns whether the account is 18+ or under — never a birthdate.
    /// Declining, or any error (Simulator / unsupported region throws
    /// `.notAvailable`), simply falls back to the self-entered date of birth.
    @MainActor
    private func verifyAgeWithAppleAccount() async {
        isCheckingAgeRange = true
        defer { isCheckingAgeRange = false }
        do {
            let response = try await requestAgeRange(ageGates: 18)
            switch response {
            case .sharing(let range):
                if let lower = range.lowerBound, lower >= 18 {
                    ageAssuranceVerifiedAdult = true
                    ageAssuranceUnderage = false
                    ageAssuranceMessage = String(localized: "Age confirmed with your Apple Account.")
                } else {
                    ageAssuranceVerifiedAdult = false
                    ageAssuranceUnderage = true
                    ageAssuranceMessage = String(localized: "Your Apple Account indicates you are under 18.")
                }
            case .declinedSharing:
                ageAssuranceMessage = String(localized: "No problem. Your date of birth will be used instead.")
            @unknown default:
                ageAssuranceMessage = nil
            }
        } catch {
            ageAssuranceMessage = String(localized: "Apple's age check isn't available here. Your date of birth will be used.")
        }
    }
    #endif

    private var footerCanAdvance: Bool {
        switch setupStep {
        case .basicDetails:
            return canCreate
        case .featuresAndPermissions:
            return canCreate && hasAgreed
        default:
            return true
        }
    }

    /// Explains why the footer's primary action is blocked, so a swipe-ahead
    /// never leaves the user with a mystery-disabled button.
    private var footerDisabledReason: String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch setupStep {
        case .basicDetails:
            if trimmedName.isEmpty { return String(localized: "Enter your name to continue.") }
            if ageAssuranceUnderage { return String(localized: "Your Apple Account indicates you are under 18.") }
            if calculatedAge < 18 { return String(localized: "You must be 18 or older to use ChillMate.") }
            return nil
        case .featuresAndPermissions:
            if trimmedName.isEmpty { return String(localized: "Add your name on the first step to finish.") }
            if ageAssuranceUnderage { return String(localized: "Your Apple Account indicates you are under 18.") }
            if calculatedAge < 18 { return String(localized: "You must be 18 or older to use ChillMate.") }
            if !hasAgreed { return String(localized: "Please read and agree to the statement to finish.") }
            return nil
        default:
            return nil
        }
    }

    private func goToNextStep() {
        switch setupStep {
        case .basicDetails:
            withAnimation { setupStep = .identityAndHealth }
        case .identityAndHealth:
            withAnimation { setupStep = .safetyAndEmergency }
        case .safetyAndEmergency:
            withAnimation { setupStep = .featuresAndPermissions }
        case .featuresAndPermissions:
            finishSetup()
        }
    }

    private func goToPreviousStep() {
        switch setupStep {
        case .basicDetails:
            break
        case .identityAndHealth:
            withAnimation { setupStep = .basicDetails }
        case .safetyAndEmergency:
            withAnimation { setupStep = .identityAndHealth }
        case .featuresAndPermissions:
            withAnimation { setupStep = .safetyAndEmergency }
        }
    }

    private func loadProfilePhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            let optimized = await ChillImageOptimizer.downsampledJPEG(from: data, maxPixelSize: 640, compressionQuality: 0.84)
            profileImageData = optimized
        }
    }

    private func finishSetup() {
        if allPersonalizationFeaturesEnabled {
            createProfile()
        } else {
            isShowingPermissionWarning = true
        }
    }

    private func createProfile() {
        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            age: calculatedAge,
            dateOfBirth: dateOfBirth,
            sex: sex,
            sexualOrientation: sexualOrientation,
            sexualRole: shouldShowSexualRole ? sexualRole : .notApplicable,
            isOnPrEP: isOnPrEP,
            prepStartDate: prepStartDate,
            prepSchedule: prepSchedule,
            weightKg: weightKg,
            heightCm: heightCm,
            homeAddress: formattedHomeAddress,
            medications: usesCurrentMedication ? medications : [],
            profileImageData: profileImageData
        )

        modelContext.insert(profile)
        modelContext.saveChanges()
    }

    private func requestHealthPermission() {
        isCheckingPermissions = true
        permissionMessage = nil

        Task {
            do {
                try await HealthKitService.shared.requestAuthorization(scopes: Set(HealthKitPermissionScope.allCases))
                await MainActor.run {
                    healthKitAutoSync = true
                    healthKitSexualActivityWriteEnabled = true
                    healthKitSleepReadWriteEnabled = true
                    healthKitHeartRateReadEnabled = true
                    healthKitHRVReadEnabled = true
                    healthKitWorkoutReadEnabled = true
                    permissionMessage = "Apple Health Sync is connected for logs, sleep, heart rate, HRV, and workouts."
                    isCheckingPermissions = false
                }
            } catch {
                await MainActor.run {
                    healthKitAutoSync = false
                    healthKitSexualActivityWriteEnabled = false
                    healthKitSleepReadWriteEnabled = false
                    healthKitHeartRateReadEnabled = false
                    healthKitHRVReadEnabled = false
                    healthKitWorkoutReadEnabled = false
                    permissionMessage = error.localizedDescription
                    isCheckingPermissions = false
                }
            }
        }
    }

    private func requestNotificationPermission() {
        isCheckingPermissions = true
        permissionMessage = nil

        Task {
            do {
                let granted = try await NotificationService.shared.requestAuthorization()
                await MainActor.run {
                    notificationsEnabled = granted
                    if granted {
                        NotificationService.shared.scheduleCheckInReminder()
                        NotificationService.shared.scheduleInactivityReminders()
                    }
                    permissionMessage = granted ? "Notifications are on." : "Notification permission was not granted."
                    isCheckingPermissions = false
                }
            } catch {
                await MainActor.run {
                    notificationsEnabled = false
                    permissionMessage = error.localizedDescription
                    isCheckingPermissions = false
                }
            }
        }
    }

    private func requestLocationPermission() {
        isCheckingPermissions = true
        permissionMessage = nil

        Task {
            do {
                _ = try await LocationLookupService.shared.currentLoggedLocation()
                await MainActor.run {
                    locationServicesChecked = true
                    permissionMessage = "Location is ready for logs and emergency messages."
                    isCheckingPermissions = false
                }
            } catch {
                await MainActor.run {
                    locationServicesChecked = false
                    permissionMessage = error.localizedDescription
                    isCheckingPermissions = false
                }
            }
        }
    }

    private func requestFaceID() {
        isCheckingPermissions = true
        permissionMessage = nil

        Task {
            let success = try? await AppAuthenticator.authenticate(reason: String(localized: "Protect ChillMate with Face ID"))
            await MainActor.run {
                if success == true {
                    requiresFaceID = true
                    permissionMessage = "Face ID lock is enabled."
                } else {
                    requiresFaceID = false
                    permissionMessage = "Face ID could not be enabled."
                }
                isCheckingPermissions = false
            }
        }
    }

    private func requestICloudBackup() {
        isCheckingPermissions = true
        permissionMessage = nil

        Task {
            await MainActor.run {
                if ICloudBackupService.shared.isAvailable {
                    iCloudBackupEnabled = true
                    lastICloudBackupStatus = ICloudBackupService.shared.statusLine
                    permissionMessage = "iCloud backup is ready. ChillMate will save encrypted backup files to iCloud Drive."
                } else {
                    iCloudBackupEnabled = false
                    permissionMessage = ICloudBackupError.iCloudUnavailable.localizedDescription
                }
                isCheckingPermissions = false
            }
        }
    }

    private func restoreICloudBackup() {
        isRestoringICloudBackup = true
        backupImportMessage = nil

        Task {
            do {
                let summary = try ICloudBackupService.shared.restoreLatestBackup(into: modelContext)
                await MainActor.run {
                    iCloudBackupEnabled = true
                    backupImportMessage = "Restored from iCloud. \(summary.displayText)"
                    isRestoringICloudBackup = false
                }
            } catch {
                await MainActor.run {
                    backupImportMessage = "Could not restore iCloud backup: \(error.localizedDescription)"
                    isRestoringICloudBackup = false
                }
            }
        }
    }

    private func handleBackupImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importBackup(from: url)
        case .failure(let error):
            backupImportMessage = error.localizedDescription
        }
    }

    private func importBackup(from url: URL) {
        isImportingBackup = true
        backupImportMessage = nil

        Task {
            do {
                let canAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if canAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let data = try Data(contentsOf: url)
                let summary = try EncryptedBackupService.shared.importEncryptedBackupData(data, into: modelContext)

                await MainActor.run {
                    backupImportMessage = summary.displayText
                    isImportingBackup = false
                }
            } catch {
                await MainActor.run {
                    backupImportMessage = "Could not import backup: \(error.localizedDescription)"
                    isImportingBackup = false
                }
            }
        }
    }
}

private struct SetupWizardProgressBar: View {
    let step: ProfileSetupStep

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                ForEach(ProfileSetupStep.allCases) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? Color.chillPrimary : Color.chillPrimary.opacity(0.18))
                        .frame(height: 6)
                        .frame(maxWidth: .infinity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: step)

            Text("Step \(step.rawValue) of \(ProfileSetupStep.allCases.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue) of \(ProfileSetupStep.allCases.count)")
    }
}

private struct SetupWizardFooter: View {
    let step: ProfileSetupStep
    let canAdvance: Bool
    let reason: String?
    let onBack: () -> Void
    let onNext: () -> Void

    private var isFirst: Bool { step == .basicDetails }
    private var isLast: Bool { step == .featuresAndPermissions }

    var body: some View {
        VStack(spacing: 8) {
            if let reason, !canAdvance {
                Text(reason)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }

            HStack(spacing: 12) {
                if !isFirst {
                    Button(action: onBack) {
                        Label("Back", systemImage: "chevron.left")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChillPillButtonStyle(prominent: false))
                }

                GlassActionButton(prominent: true, action: onNext) {
                    Label(
                        isLast ? String(localized: "Create account") : String(localized: "Continue"),
                        systemImage: isLast ? "person.crop.circle.badge.checkmark" : "arrow.right.circle.fill"
                    )
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                }
                .disabled(!canAdvance)
                .opacity(canAdvance ? 1 : 0.55)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: reason)
    }
}

private struct ProfileSetupPhotoPicker: View {
    let imageData: Data?
    @Binding var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color.chillPrimary.opacity(0.62))
                            .padding(26)
                    }
                }
                .frame(width: 116, height: 116)
                .clipShape(Circle())
                .glassSurface(radius: 58, tint: Color.chillPrimary.opacity(0.18))

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.chillText)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay {
                            Circle().stroke(.white.opacity(0.35), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
                }
                .accessibilityLabel("Add profile picture")
            }

            Text(image == nil ? String(localized: "Add a photo (optional)") : String(localized: "Tap to change photo"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if image == nil, let imageData {
                image = UIImage(data: imageData)
            }
        }
        .onChange(of: imageData) { _, newValue in
            image = newValue.flatMap(UIImage.init(data:))
        }
    }
}

private struct ProfilePermissionsPage: View {
    @Binding var healthKitAutoSync: Bool
    @Binding var notificationsEnabled: Bool
    @Binding var dailyAffirmationsEnabled: Bool
    @Binding var requiresFaceID: Bool
    @Binding var locationServicesChecked: Bool
    @Binding var iCloudBackupEnabled: Bool
    @AppStorage(DefaultsKey.discreetNotifications) private var discreetNotifications = false
    @AppStorage(DefaultsKey.weekendSafetyEnabled) private var weekendSafetyEnabled = false
    @AppStorage(DefaultsKey.safetyCheckInsEnabled) private var safetyCheckInsEnabled = false
    @AppStorage(DefaultsKey.weeklyDigestEnabled) private var weeklyDigestEnabled = false
    @AppStorage(DefaultsKey.stiReminderEnabled) private var stiReminderEnabled = false
    let message: String?
    let isChecking: Bool
    let requestHealth: () -> Void
    let requestNotifications: () -> Void
    let requestFaceID: () -> Void
    let requestLocation: () -> Void
    let requestICloud: () -> Void
    @Binding var hasAgreed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ProfileSetupSectionHeader(
                eyebrow: String(localized: "Step 4 of 4"),
                title: String(localized: "Features & Permissions"),
                subtitle: String(localized: "Choose which system features ChillMate can use. You can change these later in Settings.")
            )

            profilePermissionsPageContinued
        }
    }

    /// Second half of `ProfilePermissionsPage`'s body, which ran to 150 lines.
    ///
    /// Split purely for readability: these are the same views in the same
    /// order, still direct children of the same container.
    @ViewBuilder
    private var profilePermissionsPageContinued: some View {
            VStack(spacing: 0) {
                PermissionSetupCard(
                    title: String(localized: "Face ID"),
                    subtitle: String(localized: "Require Face ID to open ChillMate and protect your local data."),
                    symbol: "faceid",
                    isOn: requiresFaceID,
                    action: requestFaceID
                )

                ProfileSetupRowDivider()

                PermissionSetupCard(
                    title: String(localized: "Notifications"),
                    subtitle: String(localized: "Reminders for safe plans, STI results, aftercare, and private check-ins."),
                    symbol: "bell.badge.fill",
                    isOn: notificationsEnabled,
                    action: requestNotifications
                )

                if notificationsEnabled {
                    ProfileSetupRowDivider()

                    PermissionSetupCard(
                        title: String(localized: "Discreet notifications"),
                        subtitle: String(localized: "Keep lock-screen wording vague. Off shows the full reminder text."),
                        symbol: "eye.slash.fill",
                        isOn: discreetNotifications,
                        action: { discreetNotifications.toggle() }
                    )

                    ProfileSetupRowDivider()

                    PermissionSetupCard(
                        title: String(localized: "Night safety check-ins"),
                        subtitle: String(localized: "On weekend nights (12 to 6 am), a discreet “you okay?” with one-tap help."),
                        symbol: "moon.stars.fill",
                        isOn: weekendSafetyEnabled,
                        action: {
                            weekendSafetyEnabled.toggle()
                            if weekendSafetyEnabled {
                                NotificationService.shared.scheduleWeekendSafetyCheckIns()
                            } else {
                                NotificationService.shared.clearWeekendSafetyCheckIns()
                            }
                        }
                    )

                    ProfileSetupRowDivider()

                    PermissionSetupCard(
                        title: String(localized: "Session safety check-ins"),
                        subtitle: String(localized: "While a dose timer runs, more noticeable check-ins with fast help."),
                        symbol: "shield.lefthalf.filled",
                        isOn: safetyCheckInsEnabled,
                        action: { safetyCheckInsEnabled.toggle() }
                    )

                    ProfileSetupRowDivider()

                    PermissionSetupCard(
                        title: String(localized: "Weekly summary"),
                        subtitle: String(localized: "A Sunday-evening digest of your streak and score."),
                        symbol: "calendar.badge.clock",
                        isOn: weeklyDigestEnabled,
                        action: {
                            weeklyDigestEnabled.toggle()
                            if weeklyDigestEnabled {
                                NotificationService.shared.scheduleWeeklySummary(streak: 0, score: 0)
                            } else {
                                NotificationService.shared.clearWeeklySummary()
                            }
                        }
                    )

                    ProfileSetupRowDivider()

                    PermissionSetupCard(
                        title: String(localized: "STI test reminders"),
                        subtitle: String(localized: "A gentle reminder to test on a regular schedule."),
                        symbol: "cross.case.fill",
                        isOn: stiReminderEnabled,
                        action: {
                            stiReminderEnabled.toggle()
                            if stiReminderEnabled {
                                let dueDate = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
                                NotificationService.shared.scheduleSTIReminder(dueDate: dueDate)
                            } else {
                                NotificationService.shared.clearSTIReminder()
                            }
                        }
                    )
                }

                ProfileSetupRowDivider()

                PermissionSetupCard(
                    title: String(localized: "Daily Affirmations"),
                    subtitle: String(localized: "Receive a gentle affirmation when you open the app."),
                    symbol: "quote.bubble.fill",
                    isOn: dailyAffirmationsEnabled,
                    action: {
                        dailyAffirmationsEnabled.toggle()
                    }
                )

                ProfileSetupRowDivider()

                PermissionSetupCard(
                    title: String(localized: "Apple Health Sync"),
                    subtitle: String(localized: "Request read/write access for logs, sleep, heart rate, HRV, and workouts."),
                    symbol: "heart.text.square.fill",
                    isOn: healthKitAutoSync,
                    action: requestHealth
                )

                ProfileSetupRowDivider()

                PermissionSetupCard(
                    title: String(localized: "Location"),
                    subtitle: String(localized: "Attach a location to logs and include your current location in emergency messages."),
                    symbol: "location.fill",
                    isOn: locationServicesChecked,
                    action: requestLocation
                )

                ProfileSetupRowDivider()

                PermissionSetupCard(
                    title: String(localized: "iCloud Backup"),
                    subtitle: String(localized: "Save and restore encrypted ChillMate backups through iCloud Drive."),
                    symbol: "icloud.fill",
                    isOn: iCloudBackupEnabled,
                    action: requestICloud
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)

            profilePermissionsPageContinuedTail
    }

    /// Second half of `ProfilePermissionsPage`'s body, which ran to 192 lines.
    ///
    /// Split purely for readability: these are the same views in the same
    /// order, still direct children of the same container.
    @ViewBuilder
    private var profilePermissionsPageContinuedTail: some View {
            if isChecking {
                Label("Checking permission", systemImage: "hourglass")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .padding(14)
                    .glassSurface(radius: 20, tint: .black.opacity(0.04))
            }

            if let message {
                Text(message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .glassSurface(radius: 20, tint: .black.opacity(0.04))
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Before you start", systemImage: "doc.text.fill")
                    .font(.headline)
                    .foregroundStyle(Color.chillText)

                Text("ChillMate supports reflection, recovery, STI care, privacy, and emergency planning. It does not replace a clinician, diagnose conditions, decide whether something is safe, or recommend amounts, timing, or substance use. Its information is drawn from verified, official public-health sources and is updated over time as those sources change. ChillMate and its maker are not liable in any way for decisions made using the app. If someone may be in immediate danger, call local emergency services.")
                    .font(.footnote)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: $hasAgreed.animation(.snappy)) {
                    Text("I have read and agree to this.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                }
                .tint(.chillMint)
            }
            .padding(16)
            .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)

            Text("Your profile stays private on this device. If iCloud Backup is on, ChillMate saves encrypted backup files to iCloud Drive.")
                .font(.footnote)
                .foregroundStyle(Color.chillSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
    }
}

struct ProfileSetupBackupImportCard: View {
    let isImporting: Bool
    let isRestoringICloud: Bool
    let message: String?
    let importAction: () -> Void
    let restoreICloudAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ProfileSetupIcon(systemImage: "externaldrive.badge.plus")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Have a backup?")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                    Text("Restore from iCloud or import a previous encrypted ChillMate backup before creating a new profile.")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button(action: restoreICloudAction) {
                    HStack {
                        if isRestoringICloud {
                            ProgressView()
                        }
                        Label("iCloud", systemImage: "icloud.and.arrow.down.fill")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: true))
                .disabled(isRestoringICloud || isImporting)

                Button(action: importAction) {
                    HStack {
                        if isImporting {
                            ProgressView()
                        }
                        Label("File", systemImage: "square.and.arrow.down.fill")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .chillSecondaryBlue))
                .disabled(isImporting || isRestoringICloud)
            }

            if let message {
                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08), interactive: true)
    }
}

private struct PermissionSetupCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ProfileSetupIcon(systemImage: symbol)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                    Text(isOn ? String(localized: "Enabled") : subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: isOn ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.chillMint : Color.chillPrimary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(ChillPlainButtonStyle())
    }
}

struct ProfileSetupMedicationSection: View {
    @Binding var isEnabled: Bool
    @Binding var medications: [ProfileMedication]
    @Binding var name: String
    @Binding var dosage: String
    @Binding var takenAt: Date
    @Binding var effectiveHours: Double

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProfileSetupSectionHeader(
                eyebrow: String(localized: "Medication"),
                title: String(localized: "Current medication"),
                subtitle: String(localized: "Turn this on only if you want ChillMate to remember medication for check-ins and risk checks.")
            )

            medicationCard
        }
    }

    private func addMedication() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        medications.append(
            ProfileMedication(
                name: trimmedName,
                dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines),
                takenAt: takenAt,
                effectiveHours: effectiveHours
            )
        )
        name = ""
        dosage = ""
        takenAt = .now
        effectiveHours = 8
    }

    /// Toggle and medication rows, split out of a 107-line body.
    @ViewBuilder
    private var medicationCard: some View {
        VStack(spacing: 0) {
            ProfileSetupToggleRow(
                title: String(localized: "I use current medication"),
                subtitle: isEnabled ? "Medication fields are shown" : "No medication fields needed",
                isOn: $isEnabled,
                systemImage: "pills.fill"
            )

            if isEnabled {
                ProfileSetupRowDivider()

                ProfileSetupTextField(
                    title: String(localized: "Medication name"),
                    placeholder: String(localized: "For example sertraline"),
                    text: $name,
                    systemImage: "pills.fill"
                )

                ProfileSetupRowDivider()

                ProfileSetupTextField(
                    title: String(localized: "Prescription amount"),
                    placeholder: String(localized: "As written on your label"),
                    text: $dosage,
                    systemImage: "number"
                )

                ProfileSetupRowDivider()

                ProfileSetupDateRow(
                    title: String(localized: "Last taken"),
                    date: $takenAt,
                    systemImage: "clock.fill"
                )

                ProfileSetupRowDivider()

                ProfileSetupMeasurementRow(
                    title: String(localized: "Medication duration"),
                    value: $effectiveHours,
                    range: 0.5...72,
                    unit: "h",
                    systemImage: "timer"
                )

                GlassActionButton(prominent: false, action: addMedication) {
                    Label("Add medication", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canAdd)
                .opacity(canAdd ? 1 : 0.55)
                .padding(.top, 14)

                if medications.isEmpty {
                    Text("No medication saved yet.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                } else {
                    VStack(spacing: 8) {
                        ForEach(medications) { medication in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "pills.circle.fill")
                                    .foregroundStyle(Color.chillPrimary)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(medication.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.chillText)
                                    Text(medication.timingSummary)
                                        .font(.caption)
                                        .foregroundStyle(Color.chillSecondary)
                                }

                                Spacer()

                                Button {
                                    medications.removeAll { $0.id == medication.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(ChillPlainButtonStyle())
                                .foregroundStyle(Color.chillSecondary)
                            }
                            .padding(10)
                            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
    }
}

/// Publishes a gently low-passed device tilt so the intro atmosphere can drift with
/// the phone, adding depth on top of the finger-follow parallax. Simulator reports no
/// device motion, so this reads as a harmless zero there. Gated behind Reduce Motion
/// by the caller (updates are never started when motion is off).
@MainActor
private final class MotionTilt: ObservableObject {
    @Published var x: CGFloat = 0
    @Published var y: CGFloat = 0
    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let targetX = max(-0.6, min(0.6, CGFloat(motion.attitude.roll)))
            let targetY = max(-0.6, min(0.6, CGFloat(motion.attitude.pitch - 0.6)))
            // Low-pass to kill jitter without per-frame animation transactions.
            self.x = self.x * 0.86 + targetX * 0.14
            self.y = self.y * 0.86 + targetY * 0.14
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }
}

@MainActor
private struct ProfileIntroductionView: View {
    @StateObject private var delays = DelayedActionRunner()
    let continueAction: () -> Void
    @State private var activePage = 0
    @State private var isCompleting = false
    @State private var dragX: CGFloat = 0
    @State private var nudge: CGFloat = 0
    @State private var containerWidth: CGFloat = 1
    @StateObject private var tilt = MotionTilt()
    @Environment(\.accessibilityReduceMotion) private var reduceSystemMotion
    @AppStorage(DefaultsKey.chillReducedMotion) private var chillReducedMotion = false
    @AppStorage(DefaultsKey.onboardingSwipeHintShown) private var swipeHintShown = false

    private let pages = IntroPage.all
    private var currentPage: IntroPage {
        guard activePage < pages.count else { return IntroPage.fallback }
        return pages[activePage]
    }
    private var motionOff: Bool { reduceSystemMotion || chillReducedMotion }

    // Drag-coupled morph: which neighbour the finger is pulling toward, and how far.
    private var dragDirection: Int {
        if dragX < 0 { return 1 }        // dragging left → next slide
        if dragX > 0 { return -1 }       // dragging right → previous slide
        return 0
    }
    private var neighborIndex: Int { activePage + dragDirection }
    private var hasNeighbor: Bool { neighborIndex >= 0 && neighborIndex < pages.count }
    private var neighborKind: IntroAnimationKind {
        hasNeighbor ? pages[neighborIndex].animation : currentPage.animation
    }
    private var morphT: CGFloat {
        guard hasNeighbor else { return 0 }
        return min(1, abs(dragX) / max(containerWidth, 1) * 1.3)
    }
    // Resist at the ends (rubber-band) and fold in the one-time swipe nudge.
    private var effectiveParallax: CGFloat {
        (hasNeighbor ? dragX : dragX * 0.3) + nudge
    }

    var body: some View {
        ZStack {
            IntroRootBackground(kind: currentPage.animation)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.54), value: currentPage.animation)

            IntroSlideView(
                page: currentPage,
                index: activePage,
                isCompleting: isCompleting,
                parallax: effectiveParallax,
                activeKind: currentPage.animation,
                neighborKind: neighborKind,
                morphT: morphT,
                tiltX: motionOff ? 0 : tilt.x,
                tiltY: motionOff ? 0 : tilt.y,
                showSkip: activePage < pages.count - 1 && !isCompleting,
                onSkip: finish
            )
            .ignoresSafeArea()
            .scaleEffect(isCompleting ? 1.09 : 1)
            .blur(radius: isCompleting ? 12 : 0)
            .opacity(isCompleting ? 0.12 : 1)
            .animation(.easeInOut(duration: 0.44), value: isCompleting)

            IntroBottomControls(
                index: activePage,
                count: pages.count,
                isCompleting: isCompleting,
                actionTitle: activePage == pages.count - 1 ? String(localized: "Set up my profile") : String(localized: "Next"),
                action: advance
            )
            .opacity(isCompleting ? 0 : 1)
            .offset(y: isCompleting ? 24 : 0)
            .animation(.easeInOut(duration: 0.28), value: isCompleting)
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { containerWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newWidth in containerWidth = newWidth }
            }
        )
        .gesture(
            DragGesture(minimumDistance: 18)
                .onChanged { val in
                    dragX = val.translation.width
                }
                .onEnded { val in
                    let width = val.translation.width
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.90)) { dragX = 0 }
                    if width < -60 { advance() }
                    else if width > 60 { goBack() }
                }
        )
        .sensoryFeedback(.impact(weight: .light), trigger: activePage)
        .sensoryFeedback(trigger: isCompleting) { _, completing in
            completing ? .impact(weight: .heavy) : nil
        }
        .onAppear {
            if !motionOff { tilt.start() }
            armSwipeHint()
        }
        .onDisappear { tilt.stop() }
    }

    // One-time nudge on first launch: the slide drifts a few points and springs back,
    // signalling that it can be swiped. Reuses the parallax channel so hero, text, and
    // atmosphere all lean together, exactly like a real drag.
    private func armSwipeHint() {
        guard !swipeHintShown, !motionOff else { return }
        swipeHintShown = true
        delays.run(after: .milliseconds(1100), skipDelayWhenReducingMotion: false) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { nudge = -24 }
            delays.run(after: .milliseconds(440), skipDelayWhenReducingMotion: false) {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.7)) { nudge = 0 }
            }
        }
    }

    private func advance() {
        if activePage == pages.count - 1 {
            finish()
        } else {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.88)) { activePage += 1 }
        }
    }

    private func finish() {
        guard !isCompleting else { return }
        withAnimation(.spring(response: 0.56, dampingFraction: 0.82)) { isCompleting = true }
        delays.run(after: .milliseconds(500), reduceMotion: motionOff) { continueAction() }
    }

    private func goBack() {
        guard activePage > 0 else { return }
        withAnimation(.spring(response: 0.44, dampingFraction: 0.88)) { activePage -= 1 }
    }
}

private struct IntroBottomControls: View {
    @StateObject private var delays = DelayedActionRunner()
    let index: Int
    let count: Int
    let isCompleting: Bool
    let actionTitle: String
    let action: () -> Void
    @State private var shimmerPhase: CGFloat = -0.4
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceSystemMotion
    @AppStorage(DefaultsKey.chillReducedMotion) private var chillReducedMotion = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            OnboardingProgress(index: index, count: count)

            Button {
                if !(reduceSystemMotion || chillReducedMotion) {
                    withAnimation(.spring(response: 0.20, dampingFraction: 0.68)) { isPressed = true }
                    delays.run(after: .milliseconds(140), skipDelayWhenReducingMotion: false) {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) { isPressed = false }
                    }
                }
                action()
            } label: {
                ZStack {
                    HStack(spacing: 10) {
                        Text(actionTitle)
                            .font(.headline.weight(.bold))
                        Image(systemName: index == count - 1 ? "person.crop.circle.badge.checkmark" : "arrow.right")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)

                    // Shimmer sweep
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: shimmerPhase - 0.18),
                            .init(color: .white.opacity(0.22), location: shimmerPhase),
                            .init(color: .clear, location: shimmerPhase + 0.18),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(LinearGradient.chillBrand, in: Capsule())
                .overlay { Capsule().stroke(.white.opacity(0.36), lineWidth: 1) }
                .shadow(color: Color.chillPrimary.opacity(0.50), radius: 24, x: 0, y: 14)
                .scaleEffect(isPressed ? 0.96 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.74), value: isPressed)
            }
            .buttonStyle(ChillPlainButtonStyle())
            .disabled(isCompleting)
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
            .onAppear {
                // Gate the endless shimmer sweep behind Reduce Motion, like the rest
                // of the intro. Left off, shimmerPhase stays parked off-screen left.
                guard !reduceSystemMotion, !chillReducedMotion else { return }
                withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false).delay(1.0)) {
                    shimmerPhase = 1.4
                }
            }
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingProgress: View {
    let index: Int
    let count: Int

    // A thin bar that fills as you move through the intro, with faint ticks marking
    // each screen so the length reads at a glance ("four short screens").
    var body: some View {
        let fraction = CGFloat(index + 1) / CGFloat(max(count, 1))
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.16))
                    .frame(height: 5)

                Capsule()
                    .fill(LinearGradient.chillBrand)
                    .frame(width: max(14, width * fraction), height: 5)
                    .shadow(color: Color.chillPrimary.opacity(0.55), radius: 8)

                if count > 1 {
                    HStack(spacing: 0) {
                        ForEach(1..<count, id: \.self) { _ in
                            Spacer(minLength: 0)
                            Rectangle()
                                .fill(Color.chillDarkBackground.opacity(0.55))
                                .frame(width: 2, height: 5)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(height: 5)
        .frame(maxWidth: 210)
        .animation(.spring(response: 0.44, dampingFraction: 0.82), value: index)
        .accessibilityLabel("Onboarding page \(index + 1) of \(count)")
    }
}

private struct IntroPage {
    let eyebrow: String
    let title: String
    let subtitle: String
    let animation: IntroAnimationKind

    static let fallback = IntroPage(
        eyebrow: String(localized: "Track privately"),
        title: String(localized: "Your last 3 months, in one\u{00A0}place"),
        subtitle: String(localized: "Log the parts you want to remember, like sleep, substances, and aftercare. Then see your Chills, patterns, and wellbeing score in one private overview."),
        animation: .summary
    )

    static let all = [
        IntroPage(
            eyebrow: String(localized: "Welcome"),
            title: String(localized: "Welcome to ChillMate"),
            subtitle: String(localized: "A calm, private space to track Chills, stay safer, and recover softer. Let's set it up together."),
            animation: .welcome
        ),
        fallback,
        IntroPage(
            eyebrow: String(localized: "Your tools"),
            title: String(localized: "Grouped by the moment"),
            subtitle: String(localized: "Everything sits under four moments: plan before you go, stay safe while you’re out, check in with aftercare and health, then see your patterns. The one you need rises to the top."),
            animation: .care
        ),
        IntroPage(
            eyebrow: String(localized: "Private and honest"),
            title: String(localized: "Private, locked, and honest"),
            subtitle: String(localized: "Lock ChillMate with Face ID or a PIN, keep everything encrypted on this iPhone, and hide the screen in one tap. It offers reflection and safety information from verified sources. It is not medical advice."),
            animation: .privacy
        )
    ]
}

private enum IntroAnimationKind {
    case welcome
    case summary
    case log
    case care
    case privacy
    case notice
    case ready
}

@MainActor
private struct IntroSlideView: View {
    @StateObject private var delays = DelayedActionRunner()
    let page: IntroPage
    let index: Int
    let isCompleting: Bool
    var parallax: CGFloat = 0
    var activeKind: IntroAnimationKind = .welcome
    var neighborKind: IntroAnimationKind = .welcome
    var morphT: CGFloat = 0
    var tiltX: CGFloat = 0
    var tiltY: CGFloat = 0
    var showSkip: Bool = false
    var onSkip: (() -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceSystemMotion
    @AppStorage(DefaultsKey.chillReducedMotion) private var chillReducedMotion = false
    @State private var checkmarkInPlace = false
    @State private var textVisible = false

    var body: some View {
        GeometryReader { proxy in
            let topPadding = max(proxy.safeAreaInsets.top + 16, 58)
            let heroHeight = min(max(proxy.size.height * 0.32, 220), 310)

            TimelineView(.animation) { ctx in
                let rawPhase = ctx.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: .pi * 2)
                let phase = (reduceSystemMotion || chillReducedMotion) ? 0.22 : rawPhase
                // Finger-following parallax: far layers move least, near layers most.
                let pOffset: CGFloat = (reduceSystemMotion || chillReducedMotion) ? 0 : parallax

                ZStack {
                    IntroAtmosphere(kind: page.animation, index: index, phase: phase)
                        .ignoresSafeArea()
                        .offset(x: pOffset * 0.05 + tiltX * 26, y: tiltY * 20)

                    VStack(alignment: .leading, spacing: 0) {
                        OnboardingTopBar(
                            checkmarkInPlace: checkmarkInPlace || isCompleting,
                            showSkip: showSkip,
                            onSkip: onSkip
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, topPadding)

                        Spacer(minLength: 14)

                        MorphingIntroHero(
                            activeKind: activeKind,
                            neighborKind: neighborKind,
                            morphT: morphT,
                            phase: phase,
                            isCompleting: isCompleting,
                            checkmarkInPlace: checkmarkInPlace || isCompleting
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: heroHeight)
                        .scaleEffect(isCompleting ? 1.16 : 1)
                        .blur(radius: isCompleting ? 6 : 0)
                        .animation(.spring(response: 0.56, dampingFraction: 0.76), value: isCompleting)
                        .offset(x: pOffset * 0.16 + tiltX * 10, y: tiltY * 8)

                        Spacer(minLength: 28)

                        IntroTextBlock(page: page, isVisible: textVisible)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 196)
                            .offset(x: pOffset * 0.10)
                    }
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear { armEntrance() }
        .onChange(of: index) { _, _ in armEntrance() }
    }

    private func armEntrance() {
        textVisible = false
        checkmarkInPlace = false
        delays.run(after: .milliseconds(60), skipDelayWhenReducingMotion: false) {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.80)) { textVisible = true }
        }
        delays.run(after: .milliseconds(160), skipDelayWhenReducingMotion: false) {
            withAnimation(.spring(response: 0.70, dampingFraction: 0.62)) { checkmarkInPlace = true }
        }
    }
}

private struct OnboardingTopBar: View {
    let checkmarkInPlace: Bool
    var showSkip: Bool = false
    var onSkip: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ChillMateIntroWordmark(checkmarkInPlace: checkmarkInPlace)

            Spacer(minLength: 12)

            if showSkip, let onSkip {
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.12), in: Capsule())
                        .overlay { Capsule().stroke(.white.opacity(0.16), lineWidth: 1) }
                }
                .buttonStyle(ChillPlainButtonStyle())
                .transition(.opacity)
                .accessibilityLabel("Skip introduction")
            }
        }
        .frame(height: 42, alignment: .center)
        .animation(.easeInOut(duration: 0.25), value: showSkip)
    }
}

private struct IntroTextBlock: View {
    let page: IntroPage
    let isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(page.eyebrow.uppercased())
                .font(.caption.weight(.heavy))
                .tracking(2.4)
                .foregroundStyle(LinearGradient.chillBrand)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 10)
                .blur(radius: isVisible ? 0 : 5)
                .animation(.spring(response: 0.50, dampingFraction: 0.82), value: isVisible)

            Text(page.title)
                .chillScaledFont(size: 39, weight: .black, relativeTo: .largeTitle, design: .rounded)
                .foregroundStyle(.white)
                .lineSpacing(1)
                .minimumScaleFactor(0.74)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 18)
                .blur(radius: isVisible ? 0 : 5)
                .animation(.spring(response: 0.54, dampingFraction: 0.80).delay(0.06), value: isVisible)

            Text(page.subtitle)
                .font(.title3.weight(.semibold))
                .lineSpacing(4)
                .foregroundStyle(.white.opacity(0.86))
                .minimumScaleFactor(0.86)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 22)
                .blur(radius: isVisible ? 0 : 5)
                .animation(.spring(response: 0.58, dampingFraction: 0.78).delay(0.12), value: isVisible)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct IntroRootBackground: View {
    let kind: IntroAnimationKind
    @Environment(\.accessibilityReduceMotion) private var reduceSystemMotion
    @AppStorage(DefaultsKey.chillReducedMotion) private var chillReducedMotion = false

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = (reduceSystemMotion || chillReducedMotion)
                ? 0
                : ctx.date.timeIntervalSinceReferenceDate
            MeshGradient(
                width: 3,
                height: 3,
                points: meshPoints(t),
                colors: meshColors,
                smoothsColors: true
            )
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.06), .black.opacity(0.18), .black.opacity(0.64)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .animation(.easeInOut(duration: 0.54), value: kind)
    }

    // Corners stay pinned; edge mid-points slide along their own edge and the
    // centre drifts in both axes, so the gradient morphs like a slow liquid.
    private func meshPoints(_ t: TimeInterval) -> [SIMD2<Float>] {
        func wob(_ base: Float, speed: Double, amp: Float, phase: Double) -> Float {
            base + Float(sin(t * speed + phase)) * amp
        }
        return [
            SIMD2<Float>(0, 0),
            SIMD2<Float>(wob(0.5, speed: 0.43, amp: 0.07, phase: 0.0), 0),
            SIMD2<Float>(1, 0),
            SIMD2<Float>(0, wob(0.5, speed: 0.37, amp: 0.07, phase: 1.3)),
            SIMD2<Float>(wob(0.5, speed: 0.31, amp: 0.09, phase: 2.1), wob(0.5, speed: 0.35, amp: 0.08, phase: 0.7)),
            SIMD2<Float>(1, wob(0.5, speed: 0.41, amp: 0.07, phase: 3.0)),
            SIMD2<Float>(0, 1),
            SIMD2<Float>(wob(0.5, speed: 0.39, amp: 0.07, phase: 4.2), 1),
            SIMD2<Float>(1, 1),
        ]
    }

    private var meshColors: [Color] {
        switch kind {
        case .welcome:
            [Color.chillDarkBackground, Color.chillPrimary.opacity(0.94), Color.chillMint.opacity(0.72),
             Color.chillDarkBackground, Color.chillPrimary.opacity(0.56), Color.chillMint.opacity(0.40),
             Color.chillDarkBackground, Color.chillDarkBackground, Color.chillDarkBackground]
        case .summary:
            [Color.chillDarkBackground, Color.chillPrimary.opacity(0.88), Color.chillMint.opacity(0.66),
             Color.chillDarkBackground, Color.chillPrimary.opacity(0.52), Color.chillMint.opacity(0.38),
             Color.chillDarkBackground, Color.chillDarkBackground, Color.chillDarkBackground]
        case .log:
            [Color.chillDarkBackground, Color.chillIconPink.opacity(0.72), Color.chillSecondaryBlue.opacity(0.72),
             Color.chillDarkBackground, Color.chillIconPink.opacity(0.36), Color.chillSecondaryBlue.opacity(0.38),
             Color.chillDarkBackground, Color.chillDarkBackground, Color.chillDarkBackground]
        case .care:
            [Color.chillDarkBackground, Color.chillIconTeal.opacity(0.74), Color.chillMint.opacity(0.60),
             Color.chillDarkBackground, Color.chillIconTeal.opacity(0.38), Color.chillMint.opacity(0.28),
             Color.chillDarkBackground, Color.chillDarkBackground, Color.chillDarkBackground]
        case .privacy:
            [Color.chillDarkBackground, Color.chillSurfaceDark, Color.chillPrimary.opacity(0.78),
             Color.chillDarkBackground, Color.chillSurfaceDark.opacity(0.66), Color.chillPrimary.opacity(0.40),
             Color.chillDarkBackground, Color.chillDarkBackground, Color.chillDarkBackground]
        case .notice:
            [Color.chillDarkBackground, Color.chillIconOrange.opacity(0.70), Color.chillPrimary.opacity(0.70),
             Color.chillDarkBackground, Color.chillIconOrange.opacity(0.32), Color.chillPrimary.opacity(0.36),
             Color.chillDarkBackground, Color.chillDarkBackground, Color.chillDarkBackground]
        case .ready:
            [Color.chillDarkBackground, Color.chillPrimary.opacity(0.92), Color.chillMint.opacity(0.72),
             Color.chillDarkBackground, Color.chillPrimary.opacity(0.54), Color.chillMint.opacity(0.36),
             Color.chillDarkBackground, Color.chillDarkBackground, Color.chillDarkBackground]
        }
    }
}

private struct IntroAtmosphere: View {
    let kind: IntroAnimationKind
    let index: Int
    let phase: TimeInterval

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { item in
                Circle()
                    .fill(accent(for: item).opacity(0.16))
                    .frame(width: CGFloat(190 + item * 58), height: CGFloat(190 + item * 58))
                    .blur(radius: CGFloat(14 + item * 4))
                    .offset(
                        x: CGFloat(item % 2 == 0 ? -76 : 86) + wave(item, amount: 18),
                        y: CGFloat(-260 + item * 112) + wave(item + 2, amount: 14)
                    )
            }

            Image(systemName: symbol)
                .font(.system(size: 260, weight: .black))
                .foregroundStyle(.white.opacity(0.055))
                .rotationEffect(.degrees(Double(index * 8 - 18) + Double(wave(index, amount: 3))))
                .offset(x: 108, y: -18)

            VStack(spacing: 15) {
                Spacer()
                ForEach(0..<5, id: \.self) { line in
                    Capsule()
                        .fill(.white.opacity(0.055 + Double(line) * 0.010))
                        .frame(width: CGFloat(180 + line * 54), height: 6)
                        .rotationEffect(.degrees(-17))
                        .offset(x: CGFloat(-58 + line * 12), y: CGFloat(-18 * line))
                }
                Spacer().frame(height: 176)
            }
        }
    }

    private var symbol: String {
        switch kind {
        case .welcome: "sparkles"
        case .summary: "chart.bar.xaxis"
        case .log: "heart.text.square.fill"
        case .care: "checkmark.shield.fill"
        case .privacy: "lock.shield.fill"
        case .notice: "exclamationmark.triangle.fill"
        case .ready: "person.crop.circle.badge.checkmark"
        }
    }

    private func wave(_ item: Int, amount: CGFloat) -> CGFloat {
        let raw = (phase * (0.22 + Double(item) * 0.025) + Double(item) * 0.31)
            .truncatingRemainder(dividingBy: 2)
        let normalized = raw < 0 ? raw + 2 : raw
        let triangle = normalized <= 1 ? normalized : 2 - normalized
        return CGFloat(triangle * 2 - 1) * amount
    }

    private func accent(for item: Int) -> Color {
        let colors: [Color]
        switch kind {
        case .welcome:
            colors = [Color.chillPrimary, Color.chillMint, Color.chillSecondaryBlue]
        case .summary:
            colors = [Color.chillPrimary, Color.chillMint, Color.chillSecondaryBlue]
        case .log:
            colors = [Color.chillSecondaryBlue, Color.chillPrimary, Color.chillMint]
        case .care:
            colors = [Color.chillMint, Color.chillPrimary, Color.chillAccentTeal]
        case .privacy:
            colors = [Color.chillPrimary, Color.chillSecondaryBlue, Color.chillMint]
        case .notice:
            colors = [Color.chillPrimary, Color.chillSecondaryBlue, Color.chillMint]
        case .ready:
            colors = [Color.chillPrimary, Color.chillMint, Color.chillSecondaryBlue]
        }
        return colors[item % colors.count]
    }
}

private struct ChillMateIntroWordmark: View {
    let checkmarkInPlace: Bool

    var body: some View {
        HStack(spacing: 10) {
            ChillMateOnboardingLogo(checkmarkInPlace: checkmarkInPlace, size: 38)
            Text("ChillMate")
                .font(.headline.weight(.heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.chillPrimary, Color.chillSecondaryBlue, Color.chillMint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ChillMate")
    }
}

private struct ChillMateOnboardingLogo: View {
    let checkmarkInPlace: Bool
    var size: CGFloat = 136

    var body: some View {
        // Real app-icon glyph (C + checkmark) — see ChillMateBrandMark.
        // `checkmarkInPlace` drives a gentle pop-in entrance so the mark
        // animates onto screen while always resolving to the exact icon art.
        Image("ChillMateGlyph")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(checkmarkInPlace ? 1 : 0.6)
            .opacity(checkmarkInPlace ? 1 : 0)
            .shadow(color: Color.chillPrimary.opacity(0.40), radius: size * 0.13, x: 0, y: size * 0.06)
            .shadow(color: Color.chillMint.opacity(0.30), radius: size * 0.10, x: 0, y: size * 0.04)
            .accessibilityHidden(true)
    }
}

/// A single, persistent hero that morphs between the four intro states, instead of
/// each slide spawning and discarding its own. It stacks every scene and cross-fades
/// / scales the active one, so the mark reads as one element transforming through the
/// story rather than four separate reveals. Reuses the existing `IntroHeroScene`
/// visuals as morph layers.
@MainActor
private struct MorphingIntroHero: View {
    let activeKind: IntroAnimationKind
    var neighborKind: IntroAnimationKind = .welcome
    var morphT: CGFloat = 0
    let phase: TimeInterval
    let isCompleting: Bool
    let checkmarkInPlace: Bool

    private let kinds: [IntroAnimationKind] = [.welcome, .summary, .care, .privacy]

    // `morphT` (0…1) tracks the finger during a swipe, blending the active scene into
    // the one being dragged toward. At rest it is 0, so the active scene sits at full
    // and everything else is parked small and transparent. Releasing without committing
    // springs the parallax back to 0, which unwinds the blend — the morph is reversible.
    var body: some View {
        ZStack {
            ForEach(Array(kinds.enumerated()), id: \.offset) { _, kind in
                let isActive = kind == activeKind
                let isNeighbor = kind == neighborKind && neighborKind != activeKind
                let opacity: Double = isActive
                    ? Double(1 - morphT)
                    : (isNeighbor ? Double(morphT) : 0)
                let scale: CGFloat = isActive
                    ? (1 - 0.10 * morphT)
                    : (isNeighbor ? (0.72 + 0.28 * morphT) : 0.72)
                let rotation: Double = isActive
                    ? Double(6 * morphT)
                    : (isNeighbor ? Double(10 * (1 - morphT)) : 10)

                IntroHeroScene(
                    kind: kind,
                    phase: phase,
                    isCompleting: isCompleting && isActive,
                    checkmarkInPlace: checkmarkInPlace,
                    // Constant index: the scenes are assembled once and never
                    // re-enter on page change — the blend above carries the motion.
                    pageIndex: 0
                )
                .opacity(opacity)
                .scaleEffect(max(0.0001, scale))
                .rotationEffect(.degrees(rotation))
                .allowsHitTesting(isActive)
            }
        }
        // Only the committed page change springs; the drag-driven blend tracks the
        // finger directly (no implicit animation on morphT).
        .animation(.spring(response: 0.62, dampingFraction: 0.74), value: activeKind)
    }
}

@MainActor
private struct IntroHeroScene: View {
    @StateObject private var delays = DelayedActionRunner()
    let kind: IntroAnimationKind
    let phase: TimeInterval
    let isCompleting: Bool
    let checkmarkInPlace: Bool
    let pageIndex: Int

    @State private var appeared = false
    @State private var careLead: Int? = nil
    @State private var careTapped = false
    @Environment(\.accessibilityReduceMotion) private var reduceSystemMotion
    @AppStorage(DefaultsKey.chillReducedMotion) private var chillReducedMotion = false

    private var careMotionOff: Bool { reduceSystemMotion || chillReducedMotion }

    var body: some View {
        ZStack {
            switch kind {
            case .welcome:   welcomeScene
            case .summary:   summaryScene
            case .log:       logScene
            case .care:      careScene
            case .privacy:   privacyScene
            case .notice:    noticeScene
            case .ready:     readyScene
            }
        }
        .scaleEffect(isCompleting ? 1.18 : (appeared ? 1 : 0.82))
        .opacity(appeared || isCompleting ? 1 : 0)
        .blur(radius: appeared ? 0 : 10)
        .animation(.spring(response: 0.62, dampingFraction: 0.76).delay(0.04), value: appeared)
        .animation(.spring(response: 0.56, dampingFraction: 0.76), value: isCompleting)
        // A soft tap the instant a moment is chosen and rises to the top.
        .sensoryFeedback(.impact(weight: .medium), trigger: careLead)
        .onAppear {
            appeared = false
            delays.run(after: .milliseconds(40), skipDelayWhenReducingMotion: false) {
                withAnimation { appeared = true }
            }
        }
        .onChange(of: pageIndex) { _, _ in
            appeared = false
            delays.run(after: .milliseconds(40), skipDelayWhenReducingMotion: false) {
                withAnimation { appeared = true }
            }
        }
        .cancellingDelayedActions(delays)
    }

    private func selectMoment(_ index: Int) {
        if careMotionOff {
            careLead = index
            careTapped = true
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.76)) {
                careLead = index
                careTapped = true
            }
        }
    }

    // MARK: – Welcome: logomark bloom (continues the launch splash)

    private var welcomeScene: some View {
        ZStack {
            // Soft glow halo, echoing the splash's final beat.
            Circle()
                .fill(RadialGradient(
                    colors: [Color.chillPrimary.opacity(0.55), .clear],
                    center: .center, startRadius: 4, endRadius: 150))
                .frame(width: 300, height: 300)
                .blur(radius: 22)
                .scaleEffect(appeared ? 1 + bob(0, amount: 0.03) : 0.6)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.80, dampingFraction: 0.82), value: appeared)

            // Gentle breathing brand ring.
            Circle()
                .stroke(LinearGradient.chillBrand, lineWidth: 2)
                .frame(width: 208, height: 208)
                .scaleEffect(appeared ? 1 + bob(1, amount: 0.04) : 0.72)
                .opacity(appeared ? 0.65 : 0)
                .animation(.spring(response: 0.90, dampingFraction: 0.84).delay(0.05), value: appeared)

            // The app logomark, blooming in just like the launch splash.
            ChillMateOnboardingLogo(checkmarkInPlace: checkmarkInPlace, size: 150)
                .scaleEffect(appeared ? 1 : 0.7)
                .animation(.spring(response: 0.70, dampingFraction: 0.72), value: appeared)
        }
        .shadow(color: Color.chillPrimary.opacity(0.34), radius: 30, y: 16)
    }

    // MARK: – Summary: animated bar chart + logo

    private var summaryScene: some View {
        ZStack {
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(0..<4, id: \.self) { i in
                    let targetHeights: [CGFloat] = [108, 158, 80, 132]
                    let colors: [Color] = [.chillSecondaryBlue, Color(red: 251/255, green: 146/255, blue: 60/255), .chillAccentTeal, .chillMint]
                    let labels = ["Chills", "Sleep", "Care", "Score"]
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(LinearGradient(colors: [colors[i], colors[i].opacity(0.50)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 44, height: appeared ? targetHeights[i] + bob(i, amount: 5) : 4)
                            .overlay(alignment: .top) {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(.white.opacity(0.24))
                                    .frame(width: 44, height: 13)
                            }
                            .shadow(color: colors[i].opacity(0.42), radius: 14, y: 6)
                            .animation(.spring(response: 0.78, dampingFraction: 0.68).delay(Double(i) * 0.09), value: appeared)
                        Text(labels[i])
                            .chillScaledFont(size: 9, weight: .bold, relativeTo: .caption2)
                            .foregroundStyle(.white.opacity(0.74))
                    }
                }
            }
            .offset(y: 28)

            ChillMateOnboardingLogo(checkmarkInPlace: checkmarkInPlace, size: 90)
                .offset(x: 0, y: -82 + bob(0, amount: 4))

            ScoreRing(progress: appeared ? 0.74 : 0, tint: Color.chillMint)
                .frame(width: 82, height: 82)
                .offset(x: 116, y: -48 + bob(2, amount: 4))
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.72, dampingFraction: 0.76).delay(0.20), value: appeared)
        }
    }

    // MARK: – Log: pills fly in with stagger

    private var logScene: some View {
        ZStack {
            let titles = ["Time", "Sleep", "Condom", "People", "Location"]
            let symbols = ["clock.fill", "bed.double.fill", "checkmark.shield.fill", "person.2.fill", "location.fill"]
            let tints: [Color] = [.chillSecondaryBlue, Color(red: 251/255, green: 146/255, blue: 60/255), .chillMint, Color(red: 244/255, green: 114/255, blue: 182/255), .chillAccentTeal]

            ForEach(0..<5, id: \.self) { i in
                let x: CGFloat = i % 2 == 0 ? -54 : 46
                TimelinePill(title: titles[i], symbol: symbols[i], tint: tints[i])
                    .offset(x: x, y: appeared ? CGFloat(-124 + i * 56) + bob(i, amount: 4) : 110)
                    .opacity(appeared ? 1 : 0)
                    .blur(radius: appeared ? 0 : 3)
                    .animation(.spring(response: 0.60, dampingFraction: 0.74).delay(Double(i) * 0.10), value: appeared)
            }

            Image(systemName: "plus")
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(LinearGradient.chillBrand, in: Circle())
                .shadow(color: Color.chillPrimary.opacity(0.56), radius: 28, y: 14)
                .scaleEffect(appeared ? 1 : 0.28)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.62, dampingFraction: 0.60).delay(0.52), value: appeared)
                .offset(x: 92, y: 94 + bob(1, amount: 5))
        }
    }

    // MARK: – Care: real circular orbit

    /// Teaches the four Home "moments" — the same icons, colours, and order the
    /// user meets on the dashboard — and lets the user *do* the core Home behaviour
    /// once: tap the moment you're in, and it rises to the top with a "Now" badge,
    /// exactly the way the real dashboard rearranges itself.
    private var careScene: some View {
        let moments: [(title: String, symbol: String, tint: Color)] = [
            (String(localized: "Before you go"), "checkmark.shield.fill", .chillSecondaryBlue),
            (String(localized: "While you’re out"), "timer", Color(red: 251/255, green: 146/255, blue: 60/255)),
            (String(localized: "Aftercare & health"), "heart.text.square.fill", .chillMint),
            (String(localized: "Your patterns"), "chart.xyaxis.line", .chillPrimary)
        ]
        // Promote the chosen moment to the top, keeping the rest in their order.
        let order: [Int] = {
            guard let lead = careLead else { return Array(moments.indices) }
            return [lead] + moments.indices.filter { $0 != lead }
        }()

        return ZStack {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(.white.opacity(0.10))
                .frame(width: 288, height: 262)
                .overlay {
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1.1)
                }

            VStack(spacing: 8) {
                ForEach(order, id: \.self) { index in
                    let moment = moments[index]
                    let isLead = careLead == index
                    HStack(spacing: 12) {
                        Image(systemName: moment.symbol)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(moment.tint)
                            .frame(width: 38, height: 38)
                            .background(moment.tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                        Text(moment.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Spacer(minLength: 6)

                        if isLead {
                            Text("Now")
                                .chillScaledFont(size: 10, weight: .heavy, relativeTo: .caption2)
                                .foregroundStyle(moment.tint)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(moment.tint.opacity(0.22), in: Capsule())
                                .fixedSize()
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(.white.opacity(isLead ? 0.12 : 0.0001))
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(moment.tint.opacity(isLead ? 0.5 : 0), lineWidth: 1.2)
                            }
                    )
                    .frame(width: 240, alignment: .leading)
                    .contentShape(Rectangle())
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : -26)
                    .animation(.spring(response: 0.52, dampingFraction: 0.78).delay(Double(index) * 0.10 + 0.12), value: appeared)
                    .onTapGesture { selectMoment(index) }
                }

                careHint
                    .frame(width: 240, alignment: .leading)
                    .padding(.top, 2)
            }
            .offset(y: bob(1, amount: 2.0))
        }
        .shadow(color: Color.chillPrimary.opacity(0.30), radius: 26, y: 14)
    }

    /// The one-line coach mark under the moments: an invitation before the first tap,
    /// then a confirmation of what just happened.
    private var careHint: some View {
        HStack(spacing: 6) {
            Image(systemName: careTapped ? "arrow.up" : "hand.tap.fill")
                .font(.system(size: 11, weight: .bold))
                .symbolEffect(.pulse, options: careTapped || careMotionOff ? .nonRepeating : .repeating, isActive: !careTapped)
            Text(careTapped
                 ? String(localized: "The moment you’re in rises to the top")
                 : String(localized: "Tap the one you’re in right now"))
                .chillScaledFont(size: 11, weight: .semibold, relativeTo: .caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(.white.opacity(0.66))
    }

    // MARK: – Privacy: ping rings + face ID

    private var privacyScene: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.chillSurfaceDark.opacity(0.90), Color.chillPrimary.opacity(0.30), .white.opacity(0.14)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 238, height: 260)
                .overlay {
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .stroke(.white.opacity(0.24), lineWidth: 1.2)
                }

            VStack(spacing: 14) {
                ZStack {
                    // Expanding ping rings
                    ForEach(0..<3, id: \.self) { ring in
                        let raw = (phase * 0.36 + Double(ring) * 0.60).truncatingRemainder(dividingBy: 1.8)
                        let progress = raw / 1.8
                        Circle()
                            .stroke(
                                LinearGradient.chillBrand.opacity(0.30 * (1 - progress)),
                                lineWidth: 1.4
                            )
                            .frame(width: 72 + CGFloat(progress * 60), height: 72 + CGFloat(progress * 60))
                    }
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.chillDarkBackground.opacity(0.80))
                        .frame(width: 96, height: 96)
                    ChillMateOnboardingLogo(checkmarkInPlace: checkmarkInPlace, size: 72)
                }

                ForEach(0..<3, id: \.self) { item in
                    HStack(spacing: 9) {
                        Image(systemName: ["faceid", "lock.fill", "key.fill"][item])
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle([Color.chillPrimary, Color.chillMint, Color.chillSecondaryBlue][item])
                        Capsule()
                            .fill(.white.opacity(0.24))
                            .frame(width: CGFloat([82, 124, 102][item]), height: 7)
                    }
                    .frame(width: 156, alignment: .leading)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : -20)
                    .animation(.spring(response: 0.50, dampingFraction: 0.80).delay(Double(item) * 0.10 + 0.22), value: appeared)
                }
            }
            .offset(y: -6)

            // The real "quick hide" control from Home: a red stop button that
            // instantly drops the privacy shield ("Screen paused"); tap to resume.
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(.red)
                .frame(width: 74, height: 74)
                .background(Color.chillDarkBackground.opacity(0.74), in: Circle())
                .overlay { Circle().stroke(.red.opacity(0.34), lineWidth: 1) }
                .offset(x: 96, y: 102 + bob(1, amount: 3.5))
                .scaleEffect(1 + bob(0, amount: 0.05))
                .shadow(color: .red.opacity(0.42), radius: 18, y: 8)
        }
        .shadow(color: Color.chillPrimary.opacity(0.34), radius: 30, y: 16)
    }

    // MARK: – Notice: staggered lines + pulsing badge

    private var noticeScene: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(.white.opacity(0.13))
                .frame(width: 252, height: 252)
                .overlay {
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .stroke(.white.opacity(0.26), lineWidth: 1.2)
                }

            VStack(spacing: 18) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(LinearGradient.chillBrand)
                    .symbolEffect(.bounce, options: .repeating.speed(0.5))
                    .scaleEffect(1 + bob(0, amount: 0.018))

                VStack(spacing: 9) {
                    let lines = [("Wellbeing only", "heart.text.square.fill"),
                                 ("Support is nearby", "person.2.fill"),
                                 ("No dosage advice", "checkmark.shield.fill")]
                    ForEach(Array(lines.enumerated()), id: \.offset) { i, pair in
                        BetaNoticeLine(text: pair.0, symbol: pair.1)
                            .opacity(appeared ? 1 : 0)
                            .offset(x: appeared ? 0 : -24)
                            .animation(.spring(response: 0.50, dampingFraction: 0.80).delay(Double(i) * 0.12 + 0.10), value: appeared)
                    }
                }
            }
        }
        .rotationEffect(.degrees(bob(1, amount: 1.2)))
    }

    // MARK: – Ready: sparkle orbit + person + logo bounce

    private var readyScene: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 230, height: 230)
                .overlay { Circle().stroke(.white.opacity(0.24), lineWidth: 1.5) }

            // Sparkle orbit
            ForEach(0..<8, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(i % 2 == 0 ? Color.chillPrimary : Color.chillMint)
                    .offset(y: -112)
                    .rotationEffect(.degrees(Double(i) * 45 + (phase * 14).truncatingRemainder(dividingBy: 360)))
                    .opacity(appeared ? 0.68 + bob(i, amount: 0.28) : 0)
                    .scaleEffect(appeared ? 0.80 + bob(i, amount: 0.26) : 0)
                    .animation(.spring(response: 0.66, dampingFraction: 0.66).delay(Double(i) * 0.06 + 0.28), value: appeared)
            }

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 110, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.chillSecondaryBlue, Color.chillPrimary],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .offset(y: -12)
                .scaleEffect(appeared ? 1 : 0.46)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.66, dampingFraction: 0.66).delay(0.08), value: appeared)

            ChillMateOnboardingLogo(checkmarkInPlace: checkmarkInPlace, size: 90)
                .offset(x: 72, y: 84)
                .scaleEffect(appeared ? 1 : 0.28)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.68, dampingFraction: 0.60).delay(0.18), value: appeared)
        }
        .shadow(color: Color.chillMint.opacity(0.30), radius: 30, y: 18)
    }

    // MARK: – Helpers

    private func bob(_ item: Int, amount: CGFloat) -> CGFloat {
        let raw = (phase * (0.30 + Double(item) * 0.035) + Double(item) * 0.27)
            .truncatingRemainder(dividingBy: 2)
        let normalized = raw < 0 ? raw + 2 : raw
        let tri = normalized <= 1 ? normalized : 2 - normalized
        return CGFloat(tri * 2 - 1) * amount
    }
}

private struct BetaNoticeLine: View {
    let text: String
    let symbol: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(LinearGradient.chillBrand)
                .frame(width: 26, height: 26)
                .background(Color.chillPrimary.opacity(0.18), in: Circle())
            Text(text)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)
        }
        .frame(width: 202, alignment: .leading)
    }
}

private struct MiniMetricBubble: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.70))
        }
        .frame(width: 86, height: 86)
        .background(.white.opacity(0.13), in: Circle())
        .overlay {
            Circle().stroke(.white.opacity(0.20), lineWidth: 1)
        }
    }
}

private struct ScoreRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.14), lineWidth: 18)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [tint, Color.chillSecondaryBlue], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.44), radius: 10)
            Circle()
                .fill(.white.opacity(0.06))
                .padding(30)
        }
    }
}

private struct TimelinePill: View {
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.20), in: Circle())
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white.opacity(0.14), in: Capsule())
        .overlay {
            Capsule().stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct ProfileIntroTile: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ProfileSetupIcon(systemImage: systemImage)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.chillText)

                Text(subtitle)
                    .font(.footnote)
                    .lineSpacing(2)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
    }
}

struct ProfileSetupHeroCard: View {
    let contentWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 64, height: 64)

                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text("Private")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.14), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Let’s make it yours")
                    .chillScaledFont(size: 36, weight: .bold, relativeTo: .largeTitle)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Add the details that help ChillMate feel personal, useful, and clear. Nothing has to be perfect right away.")
                    .font(.callout)
                    .lineSpacing(2)
                    .foregroundStyle(.white.opacity(0.80))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .frame(width: contentWidth, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.24),
                            Color.chillPrimary.opacity(0.20),
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.26), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 24, y: 14)
    }
}

struct ProfileSetupSectionHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(Color.chillSecondary)

            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Color.chillText)

            Text(subtitle)
                .font(.footnote)
                .lineSpacing(2)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A hairline separator between flat rows inside a setup card, inset to line up
/// under the row text (past the leading icon) the way iOS grouped lists do.
struct ProfileSetupRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 1)
            .padding(.leading, 50)
    }
}

struct ProfileSetupTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let systemImage: String
    var axis: Axis = .horizontal

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillMint)

                TextField(placeholder, text: $text, axis: axis)
                    .textFieldStyle(.plain)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.chillText)
                    .tint(Color.chillPrimary)
                    .lineLimit(axis == .vertical ? 1...4 : 1...1)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            Stepper(value: $value, in: range) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.chillMint)

                    Text("\(value) years old")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                }
            }
            .tint(.chillPrimary)
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupMeasurementRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            Stepper(value: $value, in: range, step: 1) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.chillMint)

                    Text("\(Int(value.rounded())) \(unit)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                }
            }
            .tint(.chillPrimary)
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupPickerRow<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillMint)

                content
                    .pickerStyle(.menu)
                    .tint(Color.chillText)
                    .font(.body.weight(.semibold))
                    .fixedSize()
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.chillText)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(.chillPrimary)
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupDateRow: View {
    let title: String
    @Binding var date: Date
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            DatePicker(title, selection: $date, displayedComponents: [.date])
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.chillText)
                .tint(.chillPrimary)
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color.chillMint)
            .frame(width: 38, height: 38)
            .background(Color.chillMint.opacity(0.16), in: Circle())
            .overlay {
                Circle()
                    .stroke(Color.chillMint.opacity(0.34), lineWidth: 1)
            }
    }
}
