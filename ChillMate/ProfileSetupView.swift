import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AppHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \UserProfile.createdAt, order: .forward) private var profiles: [UserProfile]
    @AppStorage("lastOnDeviceRecoveryStatus") private var lastOnDeviceRecoveryStatus = ""
    @AppStorage("iCloudBackupEnabled") private var iCloudBackupEnabled = false
    @AppStorage("lastICloudBackupStatus") private var lastICloudBackupStatus = ""
    @AppStorage("lastICloudBackupTimestamp") private var lastICloudBackupTimestamp = 0.0
    @State private var didAttemptRecoveryRestore = false

    var body: some View {
        Group {
            if profiles.isEmpty {
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
        do {
            if try EncryptedBackupService.shared.refreshOnDeviceRecoverySnapshot(localContext: modelContext) {
                lastOnDeviceRecoveryStatus = "Encrypted on-device recovery backup updated."
            }
            if iCloudBackupEnabled {
                let date = try ICloudBackupService.shared.saveLatestBackup(localContext: modelContext)
                lastICloudBackupTimestamp = date.timeIntervalSince1970
                lastICloudBackupStatus = "Encrypted iCloud backup updated."
            }
        } catch {
            lastOnDeviceRecoveryStatus = "Encrypted on-device recovery backup could not update."
            if iCloudBackupEnabled {
                lastICloudBackupStatus = "Encrypted iCloud backup could not update."
            }
        }
    }
}

enum AppTab: String {
    case home
    case calendar
    case safeRoute
    case journal
    case more
}

private struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var activeCarePage: CareToolPage?
    @State private var isShowingShortcutLog = false
    @AppStorage("pendingAppDestination") private var pendingAppDestination = ""
    @AppStorage("lastSelectedTab") private var lastSelectedTab = AppTab.home.rawValue

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(openCalendarTab: {
                selectedTab = .calendar
            })
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppTab.home)

            CalendarOverviewView(showsDoneButton: false)
                .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
            .tag(AppTab.calendar)

            SafeRouteHomeView()
                .tabItem {
                    Label("Route", systemImage: "location.fill")
                }
                .tag(AppTab.safeRoute)

            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book.closed.fill")
                }
                .tag(AppTab.journal)

            MoreHubView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
                .tag(AppTab.more)
        }
        .tint(.chillPrimary)
        .fullScreenCover(item: $activeCarePage) { page in
            switch page {
            case .safetyAutopilot:
                SafetyAutopilotView()
            case .saferPlanning:
                SaferSessionPlanView()
            case .stdTests:
                STDTestsView()
            case .drugTimers:
                DrugTimerView()
            case .emergency:
                EmergencyNetherlandsView()
            case .drugInfo:
                DrugInfoView()
            case .aftercare:
                AftercareView()
            case .combinationRisk:
                CombinationRiskCheckerView()
            case .panicSupport:
                PanicSupportView()
            case .consentBoundaries:
                ConsentBoundariesView()
            case .recoveryMode:
                RecoveryModeView()
            case .privateInsights:
                PrivateInsightsView()
            case .helperBridge:
                ProfessionalHelperBridgeView()
            case .drugChecking:
                DrugCheckingEducationView()
            }
        }
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
    }

    private func restoreLastTabIfNeeded() {
        guard pendingAppDestination.isEmpty, let tab = AppTab(rawValue: lastSelectedTab) else {
            return
        }
        selectedTab = tab
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
            activeCarePage = .saferPlanning
        case .timers:
            selectedTab = .home
            activeCarePage = .drugTimers
        case .emergency:
            selectedTab = .home
            activeCarePage = .emergency
        case .panic:
            selectedTab = .home
            activeCarePage = .panicSupport
        case .journal:
            selectedTab = .journal
        case .safeRoute:
            selectedTab = .safeRoute
        }

        pendingAppDestination = ""
    }
}

private enum MoreHubPage: String, Identifiable, CaseIterable {
    case profile = "Profile"
    case settings = "Settings"
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
    case cravingDelay = "Craving delay"
    case drugChecking = "Drug checking"

    var id: String { rawValue }

    static let visiblePages: [MoreHubPage] = [
        .profile,
        .settings,
        .privacyReceipt,
        .emergencyCard,
        .supportDirectory
    ]

    var subtitle: String {
        switch self {
        case .settings:
            "Locks, alerts, look, and your data"
        case .profile:
            "Your details, photo, medication, and PrEP"
        case .safetyAutopilot:
            "A calm next step when things feel busy"
        case .privacyReceipt:
            "What is saved and what is protected"
        case .privacyTimeline:
            "Recent backup, restore, and lock activity"
        case .securityHealth:
            "See which privacy options are on"
        case .helperBridge:
            "A simple summary for a GP, GGD, or helper"
        case .recoveryMode:
            "Goals, cravings, and a fresh start"
        case .privateInsights:
            "Your patterns over time"
        case .unifiedTimeline:
            "Everything you saved, in one place"
        case .recentlyDeleted:
            "Things you recently removed"
        case .weeklyReflection:
            "A calm look at the last 7 days"
        case .emergencyCard:
            "Important help info in one card"
        case .supportDirectory:
            "Dutch help lines and support"
        case .cravingDelay:
            "Pause for 10 minutes before deciding"
        case .drugChecking:
            "Drug checking and safer-use basics"
        }
    }

    var symbol: String {
        switch self {
        case .settings:
            "gearshape.fill"
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
        case .cravingDelay:
            "pause.circle.fill"
        case .drugChecking:
            "checkmark.seal.text.page.fill"
        }
    }

    var tint: Color {
        switch self {
        case .settings:
            Color.chillVisibleBlue
        case .profile:
            Color.chillVisibleMint
        case .safetyAutopilot:
            Color.chillVisibleBlue
        case .privacyReceipt:
            Color.chillPrimary
        case .privacyTimeline:
            Color.chillVisibleTeal
        case .securityHealth:
            Color.chillVisibleMint
        case .helperBridge:
            Color.chillVisibleMint
        case .recoveryMode:
            Color.chillPrimary
        case .privateInsights:
            Color.chillVisibleBlue
        case .unifiedTimeline:
            Color.chillVisibleBlue
        case .recentlyDeleted:
            Color.chillVisibleOrange
        case .weeklyReflection:
            Color.chillVisiblePurple
        case .emergencyCard:
            .red
        case .supportDirectory:
            Color.chillVisibleBlue
        case .cravingDelay:
            Color.chillPrimary
        case .drugChecking:
            Color.chillVisibleBlue
        }
    }
}

private struct MoreHubView: View {
    @State private var activePage: MoreHubPage?
    @State private var searchText = ""

    private var filteredPages: [MoreHubPage] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return MoreHubPage.visiblePages
        }

        return MoreHubPage.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            DashboardBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(
                        title: "More",
                        subtitle: "The basics are here. Use search if you need something else.",
                        symbol: "ellipsis.circle.fill",
                        tint: Color.chillVisibleBlue
                    )

                    TestingOnlyNoticeCard()

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
                                .glassSurface(radius: 24, tint: .white.opacity(0.24))
                        }

                        ForEach(filteredPages) { page in
                            Button {
                                activePage = page
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: page.symbol)
                                        .font(.system(size: 17, weight: .black))
                                        .foregroundStyle(page.tint)
                                        .frame(width: 36, height: 36)
                                        .background(page.tint.opacity(0.14), in: Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(page.rawValue)
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
                            }
                            .buttonStyle(.plain)
                            .glassSurface(radius: 20, tint: page.tint.opacity(0.07), interactive: true)
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
        .fullScreenCover(item: $activePage) { page in
            switch page {
            case .settings:
                SettingsView(showsDoneButton: true)
            case .profile:
                ProfileOverviewView(showsDoneButton: true)
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
            case .cravingDelay:
                CravingDelayView()
            case .drugChecking:
                DrugCheckingEducationView()
            }
        }
    }
}

private enum ProfileSetupStep {
    case details
    case permissions
}

struct ProfileSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("healthKitAutoSync") private var healthKitAutoSync = false
    @AppStorage("healthKitSexualActivityWriteEnabled") private var healthKitSexualActivityWriteEnabled = false
    @AppStorage("healthKitSleepReadWriteEnabled") private var healthKitSleepReadWriteEnabled = false
    @AppStorage("healthKitHeartRateReadEnabled") private var healthKitHeartRateReadEnabled = false
    @AppStorage("healthKitHRVReadEnabled") private var healthKitHRVReadEnabled = false
    @AppStorage("healthKitWorkoutReadEnabled") private var healthKitWorkoutReadEnabled = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("locationServicesChecked") private var locationServicesChecked = false
    @AppStorage("iCloudBackupEnabled") private var iCloudBackupEnabled = false
    @AppStorage("lastICloudBackupStatus") private var lastICloudBackupStatus = ""
    @AppStorage("trustedContactName") private var trustedContactName = ""
    @AppStorage("trustedContactPhone") private var trustedContactPhone = ""
    @AppStorage("trustedContactMessage") private var trustedContactMessage = "Please come get me, I’m not okay at this moment."

    @State private var hasSeenIntroduction = false
    @State private var setupStep: ProfileSetupStep = .details
    @State private var name = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date.now) ?? Date.now
    @State private var sex: ProfileSex = .male
    @State private var sexualOrientation: SexualOrientation = .gay
    @State private var sexualRole: SexualRole = .versatile
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
                    GeometryReader { proxy in
                        let contentWidth = max(320, proxy.size.width - 40)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 22) {
                                if setupStep == .details {
                                    VStack(alignment: .leading, spacing: 16) {
                                        ProfileSetupSectionHeader(
                                            eyebrow: "Step 1 of 2",
                                            title: "Let’s set up your profile",
                                            subtitle: "Add what feels useful now. You can change it later."
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

                                        VStack(spacing: 12) {
                                            ProfileSetupTextField(
                                                title: "Name",
                                                placeholder: "Enter your name",
                                                text: $name,
                                                systemImage: "person.fill"
                                            )

                                            ProfileSetupDateRow(
                                                title: "Date of birth (\(calculatedAge))",
                                                date: $dateOfBirth,
                                                systemImage: "calendar"
                                            )

                                            if calculatedAge < 18 {
                                                Text("ChillMate is for adults. You need to be 18 or older to create an account.")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.red)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                        .padding(16)
                                        .glassSurface(radius: 28, tint: .white.opacity(0.28), interactive: true)
                                    }

                                    VStack(alignment: .leading, spacing: 16) {
                                        ProfileSetupSectionHeader(
                                            eyebrow: "Profile context",
                                            title: "Identity & preferences",
                                            subtitle: "This helps ChillMate make your overview feel more personal."
                                        )

                                        VStack(spacing: 12) {
                                            ProfileSetupPickerRow(
                                                title: "Sex",
                                                systemImage: "person.2.fill"
                                            ) {
                                                Picker("Sex", selection: $sex) {
                                                    ForEach(ProfileSex.allCases) { option in
                                                        Text(option.rawValue).tag(option)
                                                    }
                                                }
                                            }

                                            ProfileSetupPickerRow(
                                                title: "Sexual orientation",
                                                systemImage: "heart.fill"
                                            ) {
                                                Picker("Sexual orientation", selection: $sexualOrientation) {
                                                    ForEach(SexualOrientation.allCases) { option in
                                                        Text(option.rawValue).tag(option)
                                                    }
                                                }
                                            }

                                            if shouldShowSexualRole {
                                                ProfileSetupPickerRow(
                                                    title: "Role",
                                                    systemImage: "arrow.left.arrow.right"
                                                ) {
                                                    Picker("Role", selection: $sexualRole) {
                                                        ForEach(SexualRole.allCases.filter { $0 != .notApplicable }) { option in
                                                            Text(option.rawValue).tag(option)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .padding(16)
                                        .glassSurface(radius: 28, tint: .white.opacity(0.28), interactive: true)
                                    }

                                    VStack(alignment: .leading, spacing: 16) {
                                        ProfileSetupSectionHeader(
                                            eyebrow: "Home",
                                            title: "Home information",
                                            subtitle: "Optional. This helps the Route tab get you home faster."
                                        )

                                        VStack(spacing: 12) {
                                            ProfileSetupTextField(
                                                title: "Street",
                                                placeholder: "Street name",
                                                text: $homeStreet,
                                                systemImage: "house.fill"
                                            )

                                            ProfileSetupTextField(
                                                title: "House number",
                                                placeholder: "Number or addition",
                                                text: $homeHouseNumber,
                                                systemImage: "number"
                                            )

                                            ProfileSetupTextField(
                                                title: "Postal code",
                                                placeholder: "Postal code",
                                                text: $homePostalCode,
                                                systemImage: "envelope.fill"
                                            )

                                            ProfileSetupTextField(
                                                title: "City",
                                                placeholder: "City",
                                                text: $homeCity,
                                                systemImage: "building.2.fill"
                                            )

                                            ProfileSetupTextField(
                                                title: "Country",
                                                placeholder: "Country",
                                                text: $homeCountry,
                                                systemImage: "globe.europe.africa.fill"
                                            )
                                        }
                                        .padding(16)
                                        .glassSurface(radius: 28, tint: .white.opacity(0.28), interactive: true)
                                    }

                                    VStack(alignment: .leading, spacing: 16) {
                                        ProfileSetupSectionHeader(
                                            eyebrow: "Safety",
                                            title: "Emergency contact",
                                            subtitle: "Optional, but helpful. You can call or message this person from Emergency, Panic support, and Safe Route."
                                        )

                                        VStack(spacing: 12) {
                                            ProfileSetupTextField(
                                                title: "Contact name",
                                                placeholder: "Someone you trust",
                                                text: $trustedContactName,
                                                systemImage: "person.crop.circle.badge.checkmark"
                                            )

                                            ProfileSetupTextField(
                                                title: "Phone number",
                                                placeholder: "+31...",
                                                text: $trustedContactPhone,
                                                systemImage: "phone.fill"
                                            )

                                            ProfileSetupTextField(
                                                title: "Message",
                                                placeholder: "Short message to send if you need help",
                                                text: $trustedContactMessage,
                                                systemImage: "message.fill"
                                            )
                                        }
                                        .padding(16)
                                        .glassSurface(radius: 28, tint: Color.chillVisibleMint.opacity(0.08), interactive: true)
                                    }

                                    VStack(alignment: .leading, spacing: 16) {
                                        ProfileSetupSectionHeader(
                                            eyebrow: "Health context",
                                            title: "Body information",
                                            subtitle: "This helps with your profile and timer estimates."
                                        )

                                        VStack(spacing: 12) {
                                            ProfileSetupMeasurementRow(
                                                title: "Weight",
                                                value: $weightKg,
                                                range: 35...180,
                                                unit: "kg",
                                                systemImage: "scalemass.fill"
                                            )

                                            ProfileSetupMeasurementRow(
                                                title: "Height",
                                                value: $heightCm,
                                                range: 130...220,
                                                unit: "cm",
                                                systemImage: "ruler.fill"
                                            )
                                        }
                                        .padding(16)
                                        .glassSurface(radius: 28, tint: .white.opacity(0.28), interactive: true)
                                    }

                                    VStack(alignment: .leading, spacing: 16) {
                                        ProfileSetupSectionHeader(
                                            eyebrow: "Health context",
                                            title: "PrEP status",
                                            subtitle: "Optional. Add it if you want reminders or easier planning."
                                        )

                                        VStack(spacing: 12) {

                                            ProfileSetupToggleRow(
                                                title: "On PrEP",
                                                subtitle: isOnPrEP ? "Enabled" : "Not enabled",
                                                isOn: $isOnPrEP,
                                                systemImage: "cross.case.fill"
                                            )

                                            if isOnPrEP {
                                                ProfileSetupPickerRow(
                                                    title: "PrEP schedule",
                                                    systemImage: "clock.badge.checkmark.fill"
                                                ) {
                                                    Picker("PrEP schedule", selection: $prepSchedule) {
                                                        ForEach(PrEPSchedule.allCases) { option in
                                                            Text(option.rawValue).tag(option)
                                                        }
                                                    }
                                                }

                                                ProfileSetupDateRow(
                                                    title: "Since",
                                                    date: $prepStartDate,
                                                    systemImage: "calendar.badge.clock"
                                                )

                                                if prepSchedule == .daily && Calendar.current.dateComponents([.day], from: prepStartDate, to: .now).day ?? 0 < 7 {
                                                    Text("Daily PrEP needs about 7 days to reach maximum protection for receptive anal sex. Until then, use extra protection and follow medical advice.")
                                                        .font(.caption.weight(.semibold))
                                                        .foregroundStyle(.red)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                }
                                            }
                                        }
                                        .padding(16)
                                        .glassSurface(radius: 28, tint: .white.opacity(0.28), interactive: true)
                                    }

                                    ProfileSetupMedicationSection(
                                        isEnabled: $usesCurrentMedication,
                                        medications: $medications,
                                        name: $medicationName,
                                        dosage: $medicationDosage,
                                        takenAt: $medicationTakenAt,
                                        effectiveHours: $medicationEffectiveHours
                                    )

                                    GlassActionButton(prominent: true) {
                                        setupStep = .permissions
                                    } label: {
                                        Label("Continue to permissions", systemImage: "arrow.right.circle.fill")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .disabled(!canCreate)
                                    .opacity(canCreate ? 1 : 0.55)
                                } else {
                                    ProfilePermissionsPage(
                                        healthKitAutoSync: $healthKitAutoSync,
                                        notificationsEnabled: $notificationsEnabled,
                                        locationServicesChecked: $locationServicesChecked,
                                        iCloudBackupEnabled: $iCloudBackupEnabled,
                                        message: permissionMessage,
                                        isChecking: isCheckingPermissions,
                                        requestHealth: requestHealthPermission,
                                        requestNotifications: requestNotificationPermission,
                                        requestLocation: requestLocationPermission,
                                        requestICloud: requestICloudBackup,
                                        createProfile: finishSetup,
                                        back: {
                                            setupStep = .details
                                        }
                                    )
                                }
                            }
                            .frame(width: contentWidth, alignment: .leading)
                            .padding(20)
                            .padding(.bottom, 32)
                        }
                        .scrollIndicators(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                    }
                } else {
                    ProfileIntroductionView {
                        hasSeenIntroduction = true
                    }
                }
            }
            .navigationTitle("")
            .liquidGlassAlert(
                isPresented: $isShowingPermissionWarning,
                title: "Continue without everything on?",
                message: "ChillMate still works. Apple Health, notifications, location, and iCloud backup just make reminders, recovery, emergency messages, and restore easier.",
                primaryTitle: "Yes, continue",
                primaryAction: createProfile,
                secondaryTitle: "Review permissions"
            )
            .fileImporter(
                isPresented: $isShowingBackupImporter,
                allowedContentTypes: [UTType(filenameExtension: "cmbak") ?? .data, .data, .json],
                allowsMultipleSelection: false,
                onCompletion: handleBackupImport
            )
            .endEditingOnTap()
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
            medications: usesCurrentMedication ? medications : []
        )

        modelContext.insert(profile)
        try? modelContext.save()
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

private struct ProfilePermissionsPage: View {
    @Binding var healthKitAutoSync: Bool
    @Binding var notificationsEnabled: Bool
    @Binding var locationServicesChecked: Bool
    @Binding var iCloudBackupEnabled: Bool
    let message: String?
    let isChecking: Bool
    let requestHealth: () -> Void
    let requestNotifications: () -> Void
    let requestLocation: () -> Void
    let requestICloud: () -> Void
    let createProfile: () -> Void
    let back: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ProfileSetupSectionHeader(
                eyebrow: "Step 2 of 2",
                title: "Permissions",
                subtitle: "Choose which system features ChillMate can use. You can change these later in Settings."
            )

            VStack(spacing: 12) {
                PermissionSetupCard(
                    title: "Notifications",
                    subtitle: "Reminders for safe plans, STI results, aftercare, and private check-ins.",
                    symbol: "bell.badge.fill",
                    isOn: notificationsEnabled,
                    action: requestNotifications
                )

                PermissionSetupCard(
                    title: "Apple Health Sync",
                    subtitle: "Request read/write access for logs, sleep, heart rate, HRV, and workouts.",
                    symbol: "heart.text.square.fill",
                    isOn: healthKitAutoSync,
                    action: requestHealth
                )

                PermissionSetupCard(
                    title: "Location",
                    subtitle: "Attach a location to logs and include your current location in emergency messages.",
                    symbol: "location.fill",
                    isOn: locationServicesChecked,
                    action: requestLocation
                )

                PermissionSetupCard(
                    title: "iCloud Backup",
                    subtitle: "Save and restore encrypted ChillMate backups through iCloud Drive.",
                    symbol: "icloud.fill",
                    isOn: iCloudBackupEnabled,
                    action: requestICloud
                )
            }
            .padding(16)
            .glassSurface(radius: 28, tint: .white.opacity(0.28), interactive: true)

            if isChecking {
                Label("Checking permission", systemImage: "hourglass")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .padding(14)
                    .glassSurface(radius: 20, tint: .white.opacity(0.26))
            }

            if let message {
                Text(message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .glassSurface(radius: 20, tint: .white.opacity(0.26))
            }

            HStack(spacing: 12) {
                Button(action: back) {
                    Label("Back", systemImage: "chevron.left")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.chillPrimary)

                GlassActionButton(prominent: true, action: createProfile) {
                    Label("Create account", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }

            Text("Your profile stays private on this device. If iCloud Backup is on, ChillMate saves encrypted backup files to iCloud Drive.")
                .font(.footnote)
                .foregroundStyle(Color.chillSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
        }
    }
}

private struct ProfileSetupBackupImportCard: View {
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
                        Label("Restore iCloud", systemImage: "icloud.and.arrow.down.fill")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.chillPrimary)
                .disabled(isRestoringICloud || isImporting)

                Button(action: importAction) {
                    HStack {
                        if isImporting {
                            ProgressView()
                        }
                        Label("File", systemImage: "square.and.arrow.down.fill")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.chillVisibleBlue)
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
        .glassSurface(radius: 28, tint: Color.chillVisibleBlue.opacity(0.08), interactive: true)
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
                    Text(isOn ? "Enabled" : subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: isOn ? "checkmark.circle.fill" : "plus.circle.fill")
                    .foregroundStyle(isOn ? Color.chillMint : Color.chillPrimary)
            }
            .padding(14)
            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileSetupMedicationSection: View {
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
                eyebrow: "Medication",
                title: "Current medication",
                subtitle: "Turn this on only if you want ChillMate to remember medication for timers and risk checks."
            )

            VStack(spacing: 12) {
                ProfileSetupToggleRow(
                    title: "I use current medication",
                    subtitle: isEnabled ? "Medication fields are shown" : "No medication fields needed",
                    isOn: $isEnabled,
                    systemImage: "pills.fill"
                )

                if isEnabled {
                    ProfileSetupTextField(
                        title: "Medication name",
                        placeholder: "For example sertraline",
                        text: $name,
                        systemImage: "pills.fill"
                    )

                    ProfileSetupTextField(
                        title: "Dosage",
                        placeholder: "For example 50 mg",
                        text: $dosage,
                        systemImage: "number"
                    )

                    ProfileSetupDateRow(
                        title: "Last taken",
                        date: $takenAt,
                        systemImage: "clock.fill"
                    )

                    ProfileSetupMeasurementRow(
                        title: "Works for",
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

                    if medications.isEmpty {
                        Text("No medication saved yet.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Color.chillSecondary)
                                }
                                .padding(10)
                                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                        }
                    }
                }
            }
            .padding(16)
            .glassSurface(radius: 28, tint: .white.opacity(0.28), interactive: true)
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
}

@MainActor
private struct ProfileIntroductionView: View {
    let continueAction: () -> Void
    @State private var activePage = 0
    @State private var isCompleting = false
    @State private var dragOffset: CGFloat = 0

    private let pages = IntroPage.all
    private var currentPage: IntroPage {
        pages.enumerated().first { $0.offset == activePage }?.element ?? IntroPage.fallback
    }

    var body: some View {
        ZStack {
            IntroRootBackground(kind: currentPage.animation)
                .ignoresSafeArea()

            IntroSlideView(
                page: currentPage,
                index: activePage,
                isActive: true,
                isCompleting: isCompleting
            )
            .id(activePage)
            .offset(x: dragOffset)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            ))
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onChanged { value in
                        dragOffset = value.translation.width * 0.18
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 52
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            dragOffset = 0
                        }

                        if value.translation.width < -threshold {
                            advance()
                        } else if value.translation.width > threshold {
                            goBack()
                        }
                    }
            )
            .ignoresSafeArea()
            .scaleEffect(isCompleting ? 1.08 : 1)
            .blur(radius: isCompleting ? 10 : 0)
            .opacity(isCompleting ? 0.20 : 1)
            .animation(.easeInOut(duration: 0.44), value: isCompleting)

            IntroBottomControls(
                index: activePage,
                count: pages.count,
                isCompleting: isCompleting,
                actionTitle: activePage == pages.count - 1 ? "Set up my profile" : "Next",
                action: advance
            )
            .opacity(isCompleting ? 0 : 1)
            .offset(y: isCompleting ? 24 : 0)
            .animation(.easeInOut(duration: 0.28), value: isCompleting)
        }
    }

    private func advance() {
        if activePage == pages.count - 1 {
            withAnimation(.spring(response: 0.56, dampingFraction: 0.82)) {
                isCompleting = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
                continueAction()
            }
        } else {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                activePage += 1
            }
        }
    }

    private func goBack() {
        guard activePage > 0 else {
            return
        }

        withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
            activePage -= 1
        }
    }
}

private struct IntroBottomControls: View {
    let index: Int
    let count: Int
    let isCompleting: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            OnboardingProgress(index: index, count: count)

            Button(action: action) {
                HStack(spacing: 10) {
                    Text(actionTitle)
                        .font(.headline.weight(.bold))
                    Image(systemName: index == count - 1 ? "person.crop.circle.badge.checkmark" : "arrow.right")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(Color.chillDarkBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    LinearGradient(
                        colors: [Color.chillMint, Color.chillAccentTeal, Color.chillSecondaryBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.50), lineWidth: 1)
                }
                .shadow(color: Color.chillMint.opacity(0.35), radius: 24, x: 0, y: 14)
            }
            .buttonStyle(.plain)
            .disabled(isCompleting)
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
    }
}

private struct OnboardingProgress: View {
    let index: Int
    let count: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { item in
                Capsule()
                    .fill(item == index ? Color.chillMint : .white.opacity(0.30))
                    .frame(width: item == index ? 34 : 8, height: 5)
                    .shadow(color: item == index ? Color.chillMint.opacity(0.45) : .clear, radius: 8)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.80), value: index)
        .accessibilityLabel("Onboarding page \(index + 1) of \(count)")
    }
}

private struct IntroPage {
    let eyebrow: String
    let title: String
    let subtitle: String
    let animation: IntroAnimationKind

    static let fallback = IntroPage(
        eyebrow: "Summary",
        title: "A clear look at your last 3 months",
        subtitle: "See Chills, sleep, substances, and aftercare in one private overview.",
        animation: .summary
    )

    static let all = [
        fallback,
        IntroPage(
            eyebrow: "Daily score",
            title: "The app mood follows your day",
            subtitle: "After your first drug-use log, ChillMate gently adapts the background to your recovery score.",
            animation: .background
        ),
        IntroPage(
            eyebrow: "Log a Chill",
            title: "Save the parts you want to remember",
            subtitle: "Add time, sleep, substances, condoms, partners, and location when that context matters.",
            animation: .log
        ),
        IntroPage(
            eyebrow: "Care tools",
            title: "Plan safer and recover softer",
            subtitle: "Use plans, timers, drug info, risk checks, STI reminders, emergency shortcuts, and aftercare.",
            animation: .care
        ),
        IntroPage(
            eyebrow: "Privacy",
            title: "Private by default",
            subtitle: "Lock ChillMate with Face ID or a PIN. Your local data can stay encrypted on this iPhone.",
            animation: .privacy
        ),
        IntroPage(
            eyebrow: "Beta notice",
            title: "This is a Beta",
            subtitle: "The content has not been professionally reviewed yet. If you need real support, use Support in More.",
            animation: .notice
        ),
        IntroPage(
            eyebrow: "Quick exit",
            title: "Back to iPhone Home",
            subtitle: "This means the iPhone Home Screen. The red exit button closes ChillMate quickly.",
            animation: .exit
        ),
        IntroPage(
            eyebrow: "Ready",
            title: "Set up your private profile",
            subtitle: "Add only what feels useful. You can change everything later.",
            animation: .ready
        )
    ]
}

private enum IntroAnimationKind {
    case summary
    case background
    case log
    case care
    case privacy
    case notice
    case exit
    case ready
}

@MainActor
private struct IntroSlideView: View {
    let page: IntroPage
    let index: Int
    let isActive: Bool
    let isCompleting: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceSystemMotion
    @AppStorage("chillReducedMotion") private var chillReducedMotion = false
    @State private var checkmarkInPlace = false
    @State private var motionPhase = 0.0

    var body: some View {
        GeometryReader { proxy in
            let phase = motionPhase + Double(index)
            let topPadding = max(proxy.safeAreaInsets.top + 16, 58)
            let heroHeight = min(max(proxy.size.height * 0.38, 292), 338)
            let textHeight = min(max(proxy.size.height * 0.24, 188), 220)

            ZStack {
                IntroAtmosphere(kind: page.animation, index: index, phase: phase)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    OnboardingTopBar(checkmarkInPlace: checkmarkInPlace || isCompleting)
                        .padding(.horizontal, 24)
                        .padding(.top, topPadding)

                    Spacer(minLength: 14)

                    IntroHeroScene(
                        kind: page.animation,
                        phase: phase,
                        isActive: isActive,
                        isCompleting: isCompleting,
                        checkmarkInPlace: checkmarkInPlace || isCompleting
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: heroHeight)

                    Spacer(minLength: 0)

                    IntroTextBlock(page: page)
                        .frame(height: textHeight, alignment: .topLeading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 192)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(isActive ? 1 : 0.48)
                .offset(y: isActive ? 0 : 22)
                .scaleEffect(isActive ? 1 : 0.96)
                .animation(.easeOut(duration: 0.34), value: isActive)
            }
        }
        .onAppear {
            startMotion()
            if isActive {
                flyCheckmarkIn()
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                startMotion()
                flyCheckmarkIn()
            } else {
                checkmarkInPlace = false
            }
        }
    }

    private func flyCheckmarkIn() {
        checkmarkInPlace = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.70, dampingFraction: 0.62)) {
                checkmarkInPlace = true
            }
        }
    }

    private func startMotion() {
        guard !reduceSystemMotion && !chillReducedMotion else {
            motionPhase = 0.22
            return
        }

        motionPhase = 0
        withAnimation(.linear(duration: 9.0).repeatForever(autoreverses: false)) {
            motionPhase = .pi * 2
        }
    }
}

private struct OnboardingTopBar: View {
    let checkmarkInPlace: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ChillMateIntroWordmark(checkmarkInPlace: checkmarkInPlace)

            Spacer(minLength: 12)

            Text("Private Beta")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .padding(.horizontal, 13)
                .frame(height: 36)
                .background(.white.opacity(0.13), in: Capsule())
                .overlay {
                    Capsule().stroke(.white.opacity(0.20), lineWidth: 1)
                }
        }
        .frame(height: 42, alignment: .center)
    }
}

private struct IntroTextBlock: View {
    let page: IntroPage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(page.eyebrow.uppercased())
                .font(.caption.weight(.heavy))
                .tracking(2.4)
                .foregroundStyle(Color.chillMint)

            Text(page.title)
                .font(.system(size: 39, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineSpacing(1)
                .minimumScaleFactor(0.74)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.26), radius: 16, x: 0, y: 8)

            Text(page.subtitle)
                .font(.title3.weight(.semibold))
                .lineSpacing(4)
                .foregroundStyle(.white.opacity(0.86))
                .minimumScaleFactor(0.86)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct IntroRootBackground: View {
    let kind: IntroAnimationKind

    var body: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            LinearGradient(
                colors: [.black.opacity(0.10), .black.opacity(0.24), .black.opacity(0.68)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .animation(.easeInOut(duration: 0.42), value: kind)
    }

    private var backgroundColors: [Color] {
        switch kind {
        case .summary:
            [Color.chillDarkBackground, Color.chillPrimary.opacity(0.92), Color.chillMint.opacity(0.68)]
        case .background:
            [Color.chillDarkBackground, Color.chillPrimary.opacity(0.94), Color.chillVisibleAmber.opacity(0.72)]
        case .log:
            [Color.chillDarkBackground, Color.chillVisiblePink.opacity(0.66), Color.chillSecondaryBlue.opacity(0.78)]
        case .care:
            [Color.chillDarkBackground, Color.chillVisibleTeal.opacity(0.78), Color.chillMint.opacity(0.66)]
        case .privacy:
            [Color.chillDarkBackground, Color.chillSurfaceDark, Color.chillPrimary.opacity(0.84)]
        case .notice:
            [Color.chillDarkBackground, Color.chillVisibleOrange.opacity(0.62), Color.chillPrimary.opacity(0.76)]
        case .exit:
            [Color.chillDarkBackground, .black.opacity(0.92), Color.chillVisibleBlue.opacity(0.74)]
        case .ready:
            [Color.chillDarkBackground, Color.chillPrimary.opacity(0.94), Color.chillMint.opacity(0.76)]
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
        case .summary: "chart.bar.xaxis"
        case .background: "circle.lefthalf.filled"
        case .log: "heart.text.square.fill"
        case .care: "checkmark.shield.fill"
        case .privacy: "lock.shield.fill"
        case .notice: "exclamationmark.triangle.fill"
        case .exit: "xmark.octagon.fill"
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
        case .summary:
            colors = [Color.chillPrimary, Color.chillMint, Color.chillSecondaryBlue]
        case .background:
            colors = [Color.chillPrimary, Color.chillVisibleAmber, Color.chillMint]
        case .log:
            colors = [Color.chillVisiblePink, Color.chillSecondaryBlue, Color.chillMint]
        case .care:
            colors = [Color.chillVisibleTeal, Color.chillMint, Color.chillPrimary]
        case .privacy:
            colors = [Color.chillSurfaceDark, Color.chillPrimary, Color.chillMint]
        case .notice:
            colors = [Color.chillVisibleOrange, Color.chillPrimary, Color.chillMint]
        case .exit:
            colors = [.red, Color.chillPrimary, Color.chillSecondaryBlue]
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
        ZStack {
            Circle()
                .trim(from: 0.15, to: 0.86)
                .stroke(
                    LinearGradient(
                        colors: [Color.chillPrimary, Color.chillSecondaryBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: size * 0.15, lineCap: .round)
                )
                .frame(width: size * 0.76, height: size * 0.76)
                .rotationEffect(.degrees(-42))
                .shadow(color: Color.chillPrimary.opacity(0.44), radius: size * 0.16, x: 0, y: size * 0.08)

            ChillMateCheckmarkShape()
                .trim(from: 0, to: checkmarkInPlace ? 1 : 0.08)
                .stroke(
                    LinearGradient(
                        colors: [Color.chillMint, Color.chillAccentTeal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round, lineJoin: .round)
                )
                .frame(width: size * 0.48, height: size * 0.36)
                .rotationEffect(.degrees(checkmarkInPlace ? 0 : -28))
                .scaleEffect(checkmarkInPlace ? 1 : 0.54)
                .offset(x: checkmarkInPlace ? size * 0.07 : -size * 0.42, y: checkmarkInPlace ? size * 0.06 : size * 0.40)
                .opacity(checkmarkInPlace ? 1 : 0)
                .shadow(color: Color.chillMint.opacity(0.44), radius: size * 0.14, x: 0, y: size * 0.06)
        }
        .frame(width: size, height: size)
    }
}

private struct ChillMateCheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.52))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.40, y: rect.minY + rect.height * 0.78))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.88, y: rect.minY + rect.height * 0.20))
        return path
    }
}

private struct IntroHeroScene: View {
    let kind: IntroAnimationKind
    let phase: TimeInterval
    let isActive: Bool
    let isCompleting: Bool
    let checkmarkInPlace: Bool

    var body: some View {
        ZStack {
            switch kind {
            case .summary:
                summaryScene
            case .background:
                scoreScene
            case .log:
                logScene
            case .care:
                careScene
            case .privacy:
                privacyScene
            case .notice:
                noticeScene
            case .exit:
                quickExitScene
            case .ready:
                readyScene
            }
        }
        .scaleEffect(isCompleting ? 1.18 : (isActive ? 1 : 0.92))
        .opacity(isActive || isCompleting ? 1 : 0.48)
        .animation(.spring(response: 0.52, dampingFraction: 0.82), value: isActive)
        .animation(.spring(response: 0.56, dampingFraction: 0.76), value: isCompleting)
    }

    private var summaryScene: some View {
        ZStack {
            ChillMateOnboardingLogo(checkmarkInPlace: checkmarkInPlace, size: 130)
                .offset(y: -58 + bob(0, amount: 5))

            ScoreRing(progress: 0.74, tint: Color.chillMint)
                .frame(width: 214, height: 214)
                .offset(y: 54)

            ForEach(0..<4, id: \.self) { item in
                MiniMetricBubble(
                    title: ["Chills", "Sleep", "Care", "Score"][item],
                    value: ["12", "6h", "3", "82"][item],
                    symbol: ["heart.fill", "bed.double.fill", "cross.case.fill", "sparkles"][item],
                    tint: [Color.chillVisiblePink, Color.chillVisibleAmber, Color.chillVisibleTeal, Color.chillMint][item]
                )
                .offset(x: bubblePosition(item).x + bob(item, amount: 4), y: bubblePosition(item).y + bob(item + 1, amount: 4))
            }
        }
    }

    private var scoreScene: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.chillDarkBackground, Color.chillPrimary, Color.chillMint, Color.chillVisibleAmber],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 248, height: 248)
                .rotationEffect(.degrees(8 + Double(bob(2, amount: 2))))
                .shadow(color: Color.chillPrimary.opacity(0.42), radius: 38, y: 18)

            ScoreRing(progress: 0.88, tint: Color.chillVisibleAmber)
                .frame(width: 172, height: 172)

            VStack(spacing: 2) {
                Text("88")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                Text("steady")
                    .font(.caption.weight(.heavy))
            }
            .foregroundStyle(.white)
        }
    }

    private var logScene: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { item in
                TimelinePill(
                    title: ["Time", "Sleep", "Condom", "People", "Location"][item],
                    symbol: ["clock.fill", "bed.double.fill", "checkmark.shield.fill", "person.2.fill", "location.fill"][item],
                    tint: [Color.chillSecondaryBlue, Color.chillVisibleAmber, Color.chillMint, Color.chillVisiblePink, Color.chillVisibleTeal][item]
                )
                .offset(x: CGFloat(item % 2 == 0 ? -52 : 48), y: CGFloat(-128 + item * 58) + bob(item, amount: 4))
            }

            Image(systemName: "plus")
                .font(.system(size: 44, weight: .black))
                .foregroundStyle(Color.chillDarkBackground)
                .frame(width: 82, height: 82)
                .background(Color.chillMint, in: Circle())
                .shadow(color: Color.chillMint.opacity(0.44), radius: 28, y: 14)
                .offset(x: 94, y: 98 + bob(1, amount: 5))
        }
    }

    private var careScene: some View {
        ZStack {
            ChillMateOnboardingLogo(checkmarkInPlace: checkmarkInPlace, size: 108)
                .offset(y: bob(0, amount: 4))

            ForEach(0..<6, id: \.self) { item in
                let point = orbitPosition(item)
                CareOrbitIcon(
                    symbol: ["timer", "pills.fill", "checkmark.shield.fill", "cross.case.fill", "phone.fill", "figure.mind.and.body"][item],
                    tint: [Color.chillVisibleAmber, Color.chillVisibleBlue, Color.chillMint, Color.chillVisibleTeal, Color.chillVisiblePink, Color.chillPrimary][item]
                )
                .offset(x: point.x + bob(item, amount: 5), y: point.y + bob(item + 2, amount: 4))
            }
        }
    }

    private var privacyScene: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.chillSurfaceDark.opacity(0.88), Color.chillPrimary.opacity(0.32), Color.white.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 238, height: 260)
                .overlay {
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .stroke(.white.opacity(0.24), lineWidth: 1.2)
                }

            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.chillDarkBackground.opacity(0.78))
                        .frame(width: 96, height: 96)
                    ChillMateOnboardingLogo(checkmarkInPlace: checkmarkInPlace, size: 72)
                }

                ForEach(0..<3, id: \.self) { item in
                    HStack(spacing: 9) {
                        Image(systemName: ["faceid", "lock.fill", "key.fill"][item])
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle([Color.chillSecondaryBlue, Color.chillMint, Color.chillAccentTeal][item])
                        Capsule()
                            .fill(.white.opacity(0.24))
                            .frame(width: CGFloat([82, 124, 102][item]), height: 7)
                    }
                    .frame(width: 156, alignment: .leading)
                }
            }
            .offset(y: -6)

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(Color.chillMint)
                .frame(width: 76, height: 76)
                .background(Color.chillDarkBackground.opacity(0.72), in: Circle())
                .overlay {
                    Circle().stroke(Color.chillMint.opacity(0.32), lineWidth: 1)
                }
                .offset(x: 96, y: 104 + bob(1, amount: 3))
        }
        .shadow(color: Color.chillPrimary.opacity(0.34), radius: 30, y: 16)
    }

    private var noticeScene: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(.white.opacity(0.15))
                .frame(width: 252, height: 248)
                .overlay {
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .stroke(.white.opacity(0.26), lineWidth: 1.2)
                }

            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(Color.chillMint)
                    Text("BETA")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.chillPrimary.opacity(0.34), in: Capsule())

                VStack(spacing: 9) {
                    BetaNoticeLine(text: "Not reviewed yet", symbol: "exclamationmark.triangle.fill")
                    BetaNoticeLine(text: "Support is nearby", symbol: "heart.text.square.fill")
                    BetaNoticeLine(text: "You stay in control", symbol: "checkmark.shield.fill")
                }
            }
        }
        .rotationEffect(.degrees(Double(bob(1, amount: 1.5))))
    }

    private var quickExitScene: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(.white.opacity(0.14))
                .frame(width: 154, height: 224)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(.black.opacity(0.65))
                        .frame(width: 62, height: 17)
                        .padding(.top, 14)
                }
                .overlay {
                    VStack(spacing: 12) {
                        Circle()
                            .fill(.red)
                            .frame(width: 48, height: 48)
                            .overlay {
                                Image(systemName: "xmark")
                                    .font(.system(size: 24, weight: .black))
                                    .foregroundStyle(.white)
                            }
                        ForEach(0..<3, id: \.self) { item in
                            Capsule()
                                .fill(.white.opacity(0.20))
                                .frame(width: CGFloat(74 + item * 14), height: 8)
                        }
                    }
                    .padding(.top, 42)
                }
                .offset(x: isActive ? -72 : -24, y: -2)

            Image(systemName: "arrow.right")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Color.chillMint)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.14), in: Circle())
                .overlay {
                    Circle().stroke(.white.opacity(0.22), lineWidth: 1)
                }
                .offset(x: 10, y: 10)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.chillDarkBackground.opacity(0.70))
                .frame(width: 128, height: 164)
                .overlay {
                    VStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { row in
                            HStack(spacing: 10) {
                                ForEach(0..<3, id: \.self) { column in
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(homeIconColor(row: row, column: column))
                                        .frame(width: 22, height: 22)
                                }
                            }
                        }
                        Capsule()
                            .fill(.white.opacity(0.52))
                            .frame(width: 58, height: 5)
                    }
                }
                .offset(x: isActive ? 88 : 46, y: 42)
                .opacity(isActive ? 1 : 0.42)
        }
    }

    private var readyScene: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: 230, height: 230)
                .overlay {
                    Circle().stroke(.white.opacity(0.26), lineWidth: 1.5)
                }

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 112, weight: .black))
                .foregroundStyle(Color.chillSecondaryBlue)
                .offset(y: -12)

            ChillMateOnboardingLogo(checkmarkInPlace: checkmarkInPlace, size: 92)
                .offset(x: 72, y: 86)
        }
        .shadow(color: Color.chillMint.opacity(0.28), radius: 28, y: 16)
    }

    private func bubblePosition(_ item: Int) -> CGPoint {
        switch item {
        case 0: CGPoint(x: -104, y: -10)
        case 1: CGPoint(x: 106, y: 2)
        case 2: CGPoint(x: -82, y: 132)
        default: CGPoint(x: 94, y: 126)
        }
    }

    private func orbitPosition(_ item: Int) -> CGPoint {
        switch item {
        case 0: CGPoint(x: 0, y: -98)
        case 1: CGPoint(x: 112, y: -48)
        case 2: CGPoint(x: 112, y: 58)
        case 3: CGPoint(x: 0, y: 108)
        case 4: CGPoint(x: -112, y: 58)
        default: CGPoint(x: -112, y: -48)
        }
    }

    private func homeIconColor(row: Int, column: Int) -> Color {
        let palette = [
            Color.chillPrimary,
            Color.chillSecondaryBlue,
            Color.chillMint,
            Color.chillVisiblePink,
            Color.chillVisibleAmber,
            Color.chillVisibleTeal,
            Color.chillVisiblePurple,
            Color.chillAccentTeal,
            Color.chillVisibleBlue
        ]
        return palette[(row * 3 + column) % palette.count]
    }

    private func bob(_ item: Int, amount: CGFloat) -> CGFloat {
        let raw = (phase * (0.30 + Double(item) * 0.035) + Double(item) * 0.27)
            .truncatingRemainder(dividingBy: 2)
        let normalized = raw < 0 ? raw + 2 : raw
        let triangle = normalized <= 1 ? normalized : 2 - normalized
        return CGFloat(triangle * 2 - 1) * amount
    }
}

private struct BetaNoticeLine: View {
    let text: String
    let symbol: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.chillMint)
                .frame(width: 26, height: 26)
                .background(.white.opacity(0.12), in: Circle())
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
                .stroke(.white.opacity(0.18), lineWidth: 18)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [tint, Color.chillSecondaryBlue], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(.white.opacity(0.08))
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

private struct CareOrbitIcon: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 58, height: 58)
            .background(.white.opacity(0.15), in: Circle())
            .overlay {
                Circle().stroke(.white.opacity(0.22), lineWidth: 1)
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
        .glassSurface(radius: 28, tint: .white.opacity(0.28), interactive: true)
    }
}

private struct ProfileSetupHeroCard: View {
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
                    .font(.system(size: 36, weight: .bold))
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

private struct ProfileSetupSectionHeader: View {
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

private struct ProfileSetupTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondary)

                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.chillText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(Color.chillPrimary.opacity(0.28), lineWidth: 1.2)
                    }
            }
        }
        .padding(14)
        .background(.white.opacity(0.32), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.42), lineWidth: 1)
        }
    }
}

private struct ProfileSetupStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            Stepper(value: $value, in: range) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.chillSecondary)

                    Text("\(value) years old")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                }
            }
            .tint(.chillPrimary)
        }
        .padding(14)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct ProfileSetupMeasurementRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            Stepper(value: $value, in: range, step: 1) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.chillSecondary)

                    Text("\(Int(value.rounded())) \(unit)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                }
            }
            .tint(.chillPrimary)
        }
        .padding(14)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct ProfileSetupPickerRow<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.chillText)

            Spacer()

            content
                .pickerStyle(.menu)
                .tint(.chillPrimary)
        }
        .padding(14)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct ProfileSetupToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.chillText)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                }
            }
            .tint(.chillPrimary)
        }
        .padding(14)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct ProfileSetupDateRow: View {
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
        .padding(14)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct ProfileSetupIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color.chillPrimary)
            .frame(width: 38, height: 38)
            .background(.white.opacity(0.24), in: Circle())
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.24), lineWidth: 1)
            }
    }
}
