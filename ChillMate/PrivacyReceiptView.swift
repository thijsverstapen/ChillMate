import Foundation
import SwiftUI
import UIKit
import ChillMateCore

/// The protections a person can switch on, and how many are.
///
/// The Security check this replaces counted "Apple Health sync" and "iCloud
/// backup" among five protections and told people to turn on the ones that were
/// off. Sharing data with Health is not a protection, and nudging somebody to
/// share more to raise a score is the opposite of what the screen was for. These
/// five each reduce what somebody holding the phone, or looking over a shoulder,
/// can see. File protection is not here because it cannot be off.
struct PrivacyProtections: Equatable {
    var appLock: Bool
    var secondPIN: Bool
    var hideFromScreenshots: Bool
    /// Lock Screen notifications say nothing specific: discreet wording, or no
    /// notifications at all.
    var quietLockScreen: Bool
    /// A running timer says "Timer" rather than the substance.
    var discreetTimer: Bool

    static let total = 5

    var onCount: Int {
        [appLock, secondPIN, hideFromScreenshots, quietLockScreen, discreetTimer].filter { $0 }.count
    }

    static func quietLockScreen(notificationsOn: Bool, discreet: Bool) -> Bool {
        !notificationsOn || discreet
    }
}

/// Everything about privacy in one place: what protects the data, where it goes,
/// and what happened to it lately. Every line that can be changed opens the
/// place that changes it.
///
/// Until 5.1.0 this was spread over five screens — this one, Security check,
/// Privacy timeline, Settings' Data map and Privacy & lock — which overlapped,
/// disagreed in places, and could not change anything.
struct PrivacyReceiptView: View {
    @AppStorage(DefaultsKey.requiresFaceID) private var requiresFaceID = false
    @AppStorage(DefaultsKey.requiresPIN) private var requiresPIN = false
    @AppStorage(DefaultsKey.screenPrivacyEnabled) private var screenPrivacyEnabled = true
    @AppStorage(WidgetSharedKey.discreetLockScreenTimer, store: WidgetSharedKey.suite) private var discreetLockScreenTimer = false
    @AppStorage(DefaultsKey.notificationsEnabled) private var notificationsEnabled = false
    @AppStorage(DefaultsKey.discreetNotifications) private var discreetNotifications = false
    @AppStorage(DefaultsKey.healthKitAutoSync) private var healthKitAutoSync = false
    @AppStorage(DefaultsKey.healthKitSleepReadWriteEnabled) private var healthSleepRead = false
    @AppStorage(DefaultsKey.healthKitHeartRateReadEnabled) private var healthHeartRateRead = false
    @AppStorage(DefaultsKey.healthKitHRVReadEnabled) private var healthHRVRead = false
    @AppStorage(DefaultsKey.iCloudSyncChoice) private var iCloudSyncChoice: String?
    @AppStorage(DefaultsKey.dataRetentionAutomatic) private var dataRetentionAutomatic = false
    @AppStorage(DefaultsKey.dataRetentionMonths) private var dataRetentionMonths = 0
    @AppStorage(DefaultsKey.lastOnDeviceRecoveryStatus) private var lastOnDeviceRecoveryStatus = ""
    @AppStorage(DefaultsKey.lastOnDeviceRecoverySnapshotTimestamp) private var lastSnapshot = 0.0
    @AppStorage(DefaultsKey.lastOnDeviceRecoveryRestoreTimestamp) private var lastRestore = 0.0
    @AppStorage(DefaultsKey.lastAppUseTimestamp) private var lastAppUse = 0.0
    @State private var hasDuressPIN = LocalSecurityService.hasDuressPIN()

    private var protections: PrivacyProtections {
        PrivacyProtections(
            appLock: requiresFaceID || requiresPIN,
            secondPIN: requiresPIN && hasDuressPIN,
            hideFromScreenshots: screenPrivacyEnabled,
            quietLockScreen: PrivacyProtections.quietLockScreen(notificationsOn: notificationsEnabled, discreet: discreetNotifications),
            discreetTimer: discreetLockScreenTimer
        )
    }

    /// What the store is doing right now, not what Settings will do after a restart.
    private var iCloudSyncOn: Bool {
        ICloudSyncPreference.isMirroringNow(storedChoice: iCloudSyncChoice)
    }

    private var healthReads: Bool { healthSleepRead || healthHeartRateRead || healthHRVRead }

    /// Built outside the view body: nesting `String(localized:)` inside an
    /// interpolation inside another `String(localized:)` defeats the
    /// localization gate's literal scanner, which stops at the first inner quote.
    private var lockStatus: String {
        let faceID = requiresFaceID ? String(localized: "on") : String(localized: "off")
        let pin = requiresPIN ? String(localized: "on") : String(localized: "off")
        return String(localized: "Face ID: \(faceID). PIN: \(pin).")
    }

    private var healthDetail: String {
        if healthKitAutoSync {
            return String(localized: "Writes when your nights happened and how long you slept, and nothing else about them. Reads only the categories you allowed.")
        }
        return healthReads
            ? String(localized: "Reads only the categories you allowed, and writes nothing.")
            : String(localized: "Apple Health sync is off.")
    }

    private var notificationsDetail: String {
        guard notificationsEnabled else { return String(localized: "Notifications are off, so nothing shows on your Lock Screen.") }
        return discreetNotifications
            ? String(localized: "Notifications are on, with discreet lock-screen wording.")
            : String(localized: "Notifications are on, showing full wording on the lock screen.")
    }

    private var retentionDetail: String {
        guard dataRetentionAutomatic, dataRetentionMonths > 0 else {
            return String(localized: "Off. Everything is kept until you delete it.")
        }
        // Formatted by Foundation, so "1 month" and "6 months" are right in every
        // language without a plural rule in the catalog.
        let period = DateComponentsFormatter.localizedString(from: DateComponents(month: dataRetentionMonths), unitsStyle: .full)
            ?? "\(dataRetentionMonths)"
        return String(localized: "Nights older than \(period) are deleted automatically.")
    }

    var body: some View {
        ZStack {
            DashboardBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    PageHeader(
                        title: String(localized: "Privacy"),
                        subtitle: String(localized: "Extra protections on: \(protections.onCount) of \(PrivacyProtections.total). Tap anything to change it."),
                        symbol: "lock.shield.fill",
                        tint: Color.chillPrimary
                    )

                    PrivacySectionTitle(String(localized: "Protections"))

                    PrivacyRowContent(
                        title: String(localized: "File protection"),
                        detail: String(localized: "While your iPhone is locked, ChillMate's files can't be read."),
                        symbol: "lock.doc.fill",
                        state: .always
                    )
                    settingsRow(.privacy, title: String(localized: "App lock"), detail: lockStatus, symbol: "faceid", state: .from(protections.appLock))
                    settingsRow(
                        .privacy,
                        title: String(localized: "Second PIN"),
                        detail: requiresPIN
                            ? String(localized: "Opens an empty ChillMate, for when someone makes you unlock it.")
                            : String(localized: "Needs a PIN lock first. Opens an empty ChillMate, for when someone makes you unlock it."),
                        symbol: "person.badge.shield.checkmark.fill",
                        state: .from(protections.secondPIN)
                    )
                    settingsRow(
                        .privacy,
                        title: String(localized: "Hide contents from screenshots"),
                        detail: String(localized: "Covers ChillMate in the App Switcher and while your screen is recorded or mirrored."),
                        symbol: "eye.slash.fill",
                        state: .from(protections.hideFromScreenshots)
                    )
                    settingsRow(.notifications, title: String(localized: "Discreet notifications"), detail: notificationsDetail, symbol: "bell.badge.fill", state: .from(protections.quietLockScreen))
                    settingsRow(
                        .privacy,
                        title: String(localized: "Discreet Lock Screen timer"),
                        detail: discreetLockScreenTimer
                            ? String(localized: "A running timer says “Timer”, never the substance.")
                            : String(localized: "A running dose timer shows the substance on your Lock Screen, in the Dynamic Island and on your watch face, where anyone nearby can read it."),
                        symbol: "lock.iphone",
                        state: .from(protections.discreetTimer)
                    )

                    PrivacySectionTitle(String(localized: "Where your data goes"))

                    PrivacyRowContent(
                        title: String(localized: "Saved on this iPhone"),
                        detail: String(localized: "Profile, logs, timers, STI tests, plans, risk checks, journal entries, trusted contact, and preferences."),
                        symbol: "iphone",
                        state: .always
                    )
                    settingsRow(
                        .iCloud,
                        title: String(localized: "iCloud sync"),
                        detail: iCloudSyncOn
                            ? String(localized: "A copy of everything is kept in your private iCloud.")
                            : String(localized: "Off. Nothing is copied to iCloud."),
                        symbol: "arrow.triangle.2.circlepath.icloud",
                        state: .sharing(iCloudSyncOn)
                    )
                    settingsRow(.permissions, title: String(localized: "Apple Health"), detail: healthDetail, symbol: "heart.text.square.fill", state: .sharing(healthKitAutoSync || healthReads))
                    settingsRow(
                        .watch,
                        title: String(localized: "Apple Watch"),
                        detail: String(localized: "If you pair one: your trusted contact, emergency number, running timers and today's score go straight to it, not through any server."),
                        symbol: "applewatch",
                        state: .info
                    )
                    settingsRow(
                        .shortcuts,
                        title: String(localized: "Siri"),
                        detail: String(localized: "Siri can say how many nights you logged, never what you logged."),
                        symbol: "mic.fill",
                        state: .info
                    )
                    systemSettingsRow(
                        title: String(localized: "Location"),
                        detail: String(localized: "Only when you ask: to add it to a log, or to put it in a message you are sending."),
                        symbol: "location.fill"
                    )
                    settingsRow(.account, title: String(localized: "Automatic deletion"), detail: retentionDetail, symbol: "clock.arrow.circlepath", state: .from(dataRetentionAutomatic && dataRetentionMonths > 0))

                    PrivacySectionTitle(String(localized: "Recent activity"))

                    PrivacyRowContent(
                        title: String(localized: "iPhone recovery backup"),
                        detail: activityDetail(lastOnDeviceRecoveryStatus, fallback: String(localized: "Automatic encrypted snapshot"), at: lastSnapshot),
                        symbol: "externaldrive.fill.badge.checkmark",
                        state: .info
                    )
                    PrivacyRowContent(
                        title: String(localized: "Recovery restore"),
                        detail: activityDetail("", fallback: String(localized: "Recovered after reinstall when available"), at: lastRestore),
                        symbol: "arrow.counterclockwise.circle.fill",
                        state: .info
                    )
                    PrivacyRowContent(
                        title: String(localized: "Last opened"),
                        detail: activityDetail("", fallback: String(localized: "Latest app activity saved locally"), at: lastAppUse),
                        symbol: "clock.fill",
                        state: .info
                    )

                    PrivacySectionTitle(String(localized: "Your data"))

                    linkRow(title: String(localized: "Recently deleted"), symbol: "trash.circle.fill") { RecentlyDeletedView() }
                    linkRow(title: String(localized: "Export or delete your data"), symbol: "person.crop.circle.badge.xmark") {
                        SettingsView(showsBackButton: false, openingPage: .account)
                    }
                    linkRow(title: String(localized: "Privacy Policy"), symbol: "hand.raised.square.fill") { PrivacyPolicyView() }
                    linkRow(title: String(localized: "Terms of Use"), symbol: "doc.text.fill") { TermsOfUseView() }
                }
                .padding(20)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(Text(verbatim: ""))
        .onAppear { hasDuressPIN = LocalSecurityService.hasDuressPIN() }
    }

    private func activityDetail(_ status: String, fallback: String, at timestamp: Double) -> String {
        let text = status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : status
        guard timestamp > 0 else { return text }
        let stamp = Date(timeIntervalSince1970: timestamp).formatted(date: .abbreviated, time: .shortened)
        return String(localized: "\(text) · \(stamp)")
    }

    private func settingsRow(_ page: SettingsSectionPage, title: String, detail: String, symbol: String, state: PrivacyRowState) -> some View {
        NavigationLink {
            SettingsView(showsBackButton: false, openingPage: page)
        } label: {
            PrivacyRowContent(title: title, detail: detail, symbol: symbol, state: state, trailing: .chevron)
        }
        .buttonStyle(ChillPlainButtonStyle())
    }

    /// For what only iOS Settings can change: Live Activities and location.
    private func systemSettingsRow(title: String, detail: String, symbol: String) -> some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            PrivacyRowContent(title: title, detail: detail, symbol: symbol, state: .info, trailing: .external)
        }
        .buttonStyle(ChillPlainButtonStyle())
        .accessibilityHint(Text("Opens iOS Settings"))
    }

    private func linkRow<Destination: View>(title: String, symbol: String, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            PrivacyRowContent(title: title, detail: nil, symbol: symbol, state: .info, trailing: .chevron)
        }
        .buttonStyle(ChillPlainButtonStyle())
    }
}

private enum PrivacyRowState {
    /// A protection that is on, off, or cannot be off.
    case on, off, always
    /// Data going somewhere, switched on. Shown in a neutral colour rather than
    /// a protection's green: sharing is a choice, not a score to raise.
    case sharingOn
    case info

    static func from(_ isOn: Bool) -> PrivacyRowState { isOn ? .on : .off }
    static func sharing(_ isOn: Bool) -> PrivacyRowState { isOn ? .sharingOn : .off }

    var label: String? {
        switch self {
        case .on, .sharingOn: String(localized: "On")
        case .off: String(localized: "Off")
        case .always: String(localized: "Always on")
        case .info: nil
        }
    }

    var tint: Color {
        switch self {
        case .on, .always: Color.chillMint
        case .off: Color.chillSecondary
        case .sharingOn, .info: Color.chillPrimary
        }
    }
}

private enum PrivacyRowTrailing {
    case none, chevron, external
}

private struct PrivacySectionTitle: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(Color.chillSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 6)
            .padding(.top, 14)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct PrivacyRowContent: View {
    let title: String
    let detail: String?
    let symbol: String
    let state: PrivacyRowState
    var trailing: PrivacyRowTrailing = .none

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(state.tint)
                .frame(width: 34, height: 34)
                .glassSurface(radius: 17, tint: state.tint.opacity(0.12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.chillText)
                    if let label = state.label {
                        Text(label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(state.tint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(state.tint.opacity(0.14), in: Capsule())
                    }
                }
                if let detail {
                    Text(detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            switch trailing {
            case .none:
                EmptyView()
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondary)
                    .accessibilityHidden(true)
            case .external:
                Image(systemName: "arrow.up.forward.app")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .contentShape(Rectangle())
        .glassSurface(radius: 22, tint: .black.opacity(0.04), interactive: trailing != .none)
        .accessibilityElement(children: .combine)
    }
}

/// Internal rather than file-private because `EvidenceLibrary` is internal and
/// exposes arrays of this type to SafetyAutopilot, DrugCheckingEducation and
/// ProfessionalHelperBridge.
struct EvidenceSource: Identifiable {
    let id = UUID()
    let title: String
    let note: String
    /// Optional so a malformed literal drops the row rather than trapping. These
    /// are the crisis and help links; a force unwrap here turns a future typo
    /// into a crash exactly where one is least acceptable.
    let url: URL?
}

/// Shared by SafetyAutopilot, DrugCheckingEducation and ProfessionalHelperBridge,
/// so it is internal rather than file-private.
enum EvidenceLibrary {
    static let coreSafety = [
        EvidenceSource(title: String(localized: "Soa Aids Nederland"), note: String(localized: "PEP/PrEP and sexual-health guidance."), url: staticURL("https://www.soaaids.nl")),
        EvidenceSource(title: String(localized: "GGD"), note: String(localized: "Dutch sexual-health services, STI testing, and local support."), url: staticURL("https://www.ggd.nl")),
        EvidenceSource(title: String(localized: "Drugsinfo"), note: String(localized: "Substance information from Trimbos."), url: staticURL("https://www.drugsinfo.nl"))
    ]

    static let netherlandsSupport = [
        EvidenceSource(title: String(localized: "GGD"), note: String(localized: "Sexual health, STI, PrEP, and PEP routes."), url: staticURL("https://www.ggd.nl")),
        EvidenceSource(title: String(localized: "113 Zelfmoordpreventie"), note: String(localized: "Crisis support in the Netherlands."), url: staticURL("https://www.113.nl")),
        EvidenceSource(title: String(localized: "Centrum Seksueel Geweld"), note: String(localized: "Support after sexual assault or consent concerns."), url: staticURL("https://centrumseksueelgeweld.nl")),
        EvidenceSource(title: String(localized: "Drugs Infolijn"), note: String(localized: "Questions about drugs and harm reduction."), url: staticURL("https://www.drugsinfo.nl/drugs/contact-met-de-drugs-infolijn/"))
    ]

    static let drugChecking = [
        EvidenceSource(title: String(localized: "Drugsinfo"), note: String(localized: "General substance information from Trimbos."), url: staticURL("https://www.drugsinfo.nl")),
        EvidenceSource(title: String(localized: "Trimbos drugs knowledge"), note: String(localized: "Monitoring, prevention, and harm-reduction information."), url: staticURL("https://www.trimbos.nl/kennis/drugs/")),
        EvidenceSource(title: String(localized: "Rijksoverheid drugs prevention"), note: String(localized: "Dutch government prevention information and official links."), url: staticURL("https://www.rijksoverheid.nl/onderwerpen/drugs/drugsgebruik-voorkomen"))
    ]

    static let privacy = [
        EvidenceSource(title: String(localized: "Apple HealthKit HIG"), note: String(localized: "HealthKit requires user permission for health information."), url: staticURL("https://developer.apple.com/design/human-interface-guidelines/healthkit/")),
        EvidenceSource(title: String(localized: "Apple HealthKit privacy"), note: String(localized: "Apple guidance for protecting health-related data."), url: staticURL("https://developer.apple.com/documentation/healthkit/protecting_user_privacy")),
        EvidenceSource(title: String(localized: "Configure HealthKit access"), note: String(localized: "HealthKit entitlements and usage descriptions."), url: staticURL("https://developer.apple.com/documentation/xcode/configuring-healthkit-access"))
    ]
}

struct EvidenceSourcesSection: View {
    let title: String
    let sources: [EvidenceSource]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CareSectionTitle(title: title, symbol: "link.circle.fill")

            ForEach(sources.filter { $0.url != nil }) { source in
                Link(destination: source.url ?? URL(fileURLWithPath: "/")) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.chillSecondaryBlue)
                            .frame(width: 34, height: 34)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.chillText)
                            Text(source.note)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.chillSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .glassSurface(radius: 18, tint: Color.chillSecondaryBlue.opacity(0.06), interactive: true)
                }
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08))
    }
}
