import Foundation
import SwiftUI

struct PrivacyReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DefaultsKey.requiresFaceID) private var requiresFaceID = false
    @AppStorage(DefaultsKey.requiresPIN) private var requiresPIN = false
    @AppStorage(DefaultsKey.localEncryptionEnabled) private var localEncryptionEnabled = true
    @AppStorage(DefaultsKey.healthKitAutoSync) private var healthKitAutoSync = false
    @AppStorage(DefaultsKey.notificationsEnabled) private var notificationsEnabled = false
    @AppStorage(DefaultsKey.discreetNotifications) private var discreetNotifications = false
    @AppStorage(DefaultsKey.iCloudBackupEnabled) private var iCloudBackupEnabled = false

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        PageHeader(
                            title: String(localized: "Privacy"),
                            subtitle: String(localized: "A simple view of what ChillMate keeps on this iPhone and which protections are turned on."),
                            symbol: "lock.shield.fill",
                            tint: Color.chillPrimary
                        )

                        PrivacyReceiptRow(title: String(localized: "Saved on this iPhone"), detail: String(localized: "Profile, logs, timers, STI tests, plans, risk checks, journal entries, trusted contact, and preferences."), symbol: "iphone", isEnabled: true)
                        PrivacyReceiptRow(title: String(localized: "Encrypted files"), detail: "Strong iPhone file protection is \(localEncryptionEnabled ? "on" : "available but off in settings").", symbol: "lock.doc.fill", isEnabled: localEncryptionEnabled)
                        PrivacyReceiptRow(title: String(localized: "App lock"), detail: "Face ID: \(requiresFaceID ? "on" : "off"). PIN: \(requiresPIN ? "on" : "off").", symbol: "faceid", isEnabled: requiresFaceID || requiresPIN)
                        PrivacyReceiptRow(title: String(localized: "Apple Health"), detail: healthKitAutoSync ? "ChillMate can read and write only the Health categories you allowed." : "Apple Health sync is off.", symbol: "heart.text.square.fill", isEnabled: healthKitAutoSync)
                        PrivacyReceiptRow(title: String(localized: "Notifications"), detail: notificationsEnabled ? "Notifications are on. Discreet lock-screen wording is \(discreetNotifications ? "on" : "off")." : "Notifications are off.", symbol: "bell.badge.fill", isEnabled: notificationsEnabled)
                        PrivacyReceiptRow(title: String(localized: "iCloud backup"), detail: iCloudBackupEnabled ? "Encrypted backup files can be saved to iCloud Drive." : "iCloud backup is off. Local encrypted recovery stays on this iPhone.", symbol: "icloud.fill", isEnabled: iCloudBackupEnabled)

                        Text("More privacy tools")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.chillSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 14)

                        VStack(spacing: 8) {
                            PrivacyNavRow(title: String(localized: "Security check"), symbol: "checkmark.shield.fill", tint: Color.chillMint) {
                                SecurityHealthCheckView()
                            }
                            PrivacyNavRow(title: String(localized: "Privacy timeline"), symbol: "clock.badge.checkmark.fill", tint: Color.chillIconTeal) {
                                PrivacyTimelineView()
                            }
                            PrivacyNavRow(title: String(localized: "Recently deleted"), symbol: "trash.circle.fill", tint: Color.chillIconOrange) {
                                RecentlyDeletedView()
                            }
                            PrivacyNavRow(title: String(localized: "Privacy Policy"), symbol: "hand.raised.square.fill", tint: Color.chillIconTeal) {
                                PrivacyPolicyView()
                            }
                            PrivacyNavRow(title: String(localized: "Terms of Use"), symbol: "doc.text.fill", tint: Color.chillIconPurple) {
                                TermsOfUseView()
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(Text(verbatim: ""))
        }
    }
}

private struct PrivacyNavRow<Destination: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        // Sub-pages are plain content (no own NavigationStack), so they push
        // onto the shared More-hub stack and get the native back button and
        // interactive swipe-back for free.
        NavigationLink {
            destination()
        } label: {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
            }
            .padding(16)
            .contentShape(Rectangle())
            .glassSurface(radius: 22, tint: tint.opacity(0.12), interactive: true)
        }
        .buttonStyle(ChillPlainButtonStyle())
    }
}

private struct PrivacyReceiptRow: View {
    let title: String
    let detail: String
    let symbol: String
    let isEnabled: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isEnabled ? Color.chillPrimary : Color.chillSecondary)
                .frame(width: 34, height: 34)
                .glassSurface(radius: 17, tint: (isEnabled ? Color.chillPrimary : Color.black).opacity(0.10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.chillText)
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassSurface(radius: 22, tint: .black.opacity(0.04))
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
