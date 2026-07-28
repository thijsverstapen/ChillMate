import Foundation
import SwiftUI

struct SecurityHealthCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DefaultsKey.requiresFaceID) private var requiresFaceID = false
    @AppStorage(DefaultsKey.requiresPIN) private var requiresPIN = false
    @AppStorage(DefaultsKey.localEncryptionEnabled) private var localEncryptionEnabled = true
    @AppStorage(DefaultsKey.iCloudBackupEnabled) private var iCloudBackupEnabled = false
    @AppStorage(DefaultsKey.discreetNotifications) private var discreetNotifications = false
    @AppStorage(DefaultsKey.healthKitAutoSync) private var healthKitAutoSync = false

    private var checks: [SecurityCheckItem] {
        [
            SecurityCheckItem(title: String(localized: "Local encryption"), detail: String(localized: "Device files use iOS data protection."), isOn: localEncryptionEnabled, symbol: "lock.fill", tint: Color.chillMint),
            SecurityCheckItem(title: String(localized: "App lock"), detail: String(localized: "Face ID or PIN before opening."), isOn: requiresFaceID || requiresPIN, symbol: "faceid", tint: Color.chillSecondaryBlue),
            SecurityCheckItem(title: String(localized: "Encrypted backup"), detail: String(localized: "iCloud backup is optional and encrypted before upload."), isOn: iCloudBackupEnabled, symbol: "icloud.fill", tint: Color.chillIconTeal),
            SecurityCheckItem(title: String(localized: "Discreet notifications"), detail: String(localized: "Lock-screen text stays vague."), isOn: discreetNotifications, symbol: "bell.slash.fill", tint: Color.chillIconPurple),
            SecurityCheckItem(title: String(localized: "Apple Health Sync"), detail: String(localized: "Health reads and writes only when you allow it."), isOn: healthKitAutoSync, symbol: "heart.fill", tint: Color.chillIconPink)
        ]
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(title: String(localized: "Security check"), subtitle: "\(checks.filter(\.isOn).count) of \(checks.count) protections are on. Turn on the ones that match how private you want ChillMate to be.", symbol: "checkmark.shield.fill", tint: Color.chillMint)
                        VStack(spacing: 10) { ForEach(checks) { SecurityCheckRow(item: $0) } }
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

private struct SecurityCheckItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let isOn: Bool
    let symbol: String
    let tint: Color
}

private struct SecurityCheckRow: View {
    let item: SecurityCheckItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(item.isOn ? item.tint : Color.chillTertiary)
                .frame(width: 36, height: 36)
                .glassSurface(radius: 18, tint: item.tint.opacity(0.10))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline).foregroundStyle(Color.chillText)
                Text(item.detail).font(.caption.weight(.semibold)).foregroundStyle(Color.chillSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassSurface(radius: 22, tint: item.tint.opacity(item.isOn ? 0.09 : 0.04))
    }
}
