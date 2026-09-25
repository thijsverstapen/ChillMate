import SwiftUI

/// Settings' control for whether ChillMate keeps a copy of its store in iCloud.
///
/// Sits above the encrypted-backup card on purpose. They are two different things
/// that both say "iCloud", and until 5.1.0 only the backup had a switch — so the
/// one visible iCloud setting read "off" while the other, invisible one was on.
/// Side by side, each explains itself against the other.
struct ICloudSyncCard: View {
    @AppStorage(DefaultsKey.iCloudSyncChoice) private var storedChoice: String?

    private var isOn: Binding<Bool> {
        Binding(
            get: { storedChoice == ICloudSyncPreference.Choice.on.rawValue },
            set: { storedChoice = ($0 ? ICloudSyncPreference.Choice.on : .off).rawValue }
        )
    }

    /// True when what Settings shows is not yet what the store is doing, because a
    /// running container cannot switch its CloudKit setting.
    private var awaitsRestart: Bool {
        guard let applied = ICloudSyncPreference.appliedThisSession else { return false }
        return applied.rawValue != (storedChoice ?? applied.rawValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: isOn.wrappedValue ? "icloud.fill" : "icloud.slash")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.chillPrimary)
                    .frame(width: 42, height: 42)
                    .glassSurface(radius: 21, tint: Color.chillPrimary.opacity(0.12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("iCloud sync")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)

                    Text(isOn.wrappedValue
                         ? String(localized: "A copy of everything is kept in your private iCloud, so your history can move to a new iPhone or come back after reinstalling. Unless you have turned on Advanced Data Protection, Apple holds the keys to it.")
                         : String(localized: "Off. Everything stays on this iPhone. Turn it on to keep a copy in your private iCloud, so your history can move to a new iPhone."))
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Toggle("iCloud sync", isOn: isOn)
                    .labelsHidden()
                    .tint(Color.chillPrimary)
            }

            if awaitsRestart {
                Label(
                    String(localized: "Takes effect after you close ChillMate from the app switcher and open it again."),
                    systemImage: "arrow.clockwise"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillText)
                .fixedSize(horizontal: false, vertical: true)
            }

            // Turning it off stops new copies; it does not remove the old one. Saying
            // so here, rather than letting the switch imply deletion, is the whole
            // difference between this card and the copy it replaces.
            if !isOn.wrappedValue {
                Text("Turning this off does not delete what is already in iCloud. You can remove it in iOS Settings, under your iCloud storage.")
                    .font(.caption)
                    .foregroundStyle(Color.chillTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: 24, tint: Color.chillPrimary.opacity(0.06))
    }
}
