import SwiftData
import SwiftUI

/// The panic control, on every tab rather than only on Home.
///
/// It hides the app behind the privacy shield and takes an encrypted recovery
/// snapshot on the way out. Until 5.0.0 it lived in `DashboardView`'s toolbar and
/// nowhere else, so it was there while you looked at the dashboard and gone the
/// moment you opened your history or the care tools — screens with more on them
/// worth not being seen, and the ones somebody is more likely to be on when a
/// reason to hide walks into the room.
///
/// Each tab root has its own `NavigationStack` and More hides its navigation bar
/// altogether, so there is no single place to hang this from. The button owns its
/// own state and its own cover, which is what lets it be dropped into a toolbar
/// on two tabs and into an overlay on the third without three copies of the
/// behaviour.
struct PanicHideButton: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @State private var isPrivacyScreenActive = false

    var body: some View {
        Button(role: .destructive) {
            Task {
                _ = try? services.encryptedBackups
                    .refreshOnDeviceRecoverySnapshot(localContext: modelContext)
            }
            isPrivacyScreenActive = true
        } label: {
            Image(systemName: "xmark.octagon.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(.red)
                .frame(width: 36, height: 36)
                .glassSurface(radius: 18, tint: .white.opacity(0.34), interactive: true)
        }
        .buttonStyle(ChillPlainButtonStyle())
        .accessibilityLabel("Panic close app")
        // Voice Control matches what is written, and this control has no visible
        // text at all. These are what someone would actually say.
        .accessibilityInputLabels([
            String(localized: "Panic"),
            String(localized: "Hide"),
            String(localized: "Close app")
        ])
        .accessibilityHint(String(localized: "Hides everything on screen behind a neutral page."))
        .accessibilityIdentifier(AccessibilityID.panicButton)
        .sensoryFeedback(trigger: isPrivacyScreenActive) { _, active in
            active ? .impact(weight: .heavy) : nil
        }
        .fullScreenCover(isPresented: $isPrivacyScreenActive) {
            PrivacyShieldView(dismiss: { isPrivacyScreenActive = false })
        }
    }
}

extension View {
    /// Puts the panic control in this screen's navigation bar.
    func panicHideToolbar() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PanicHideButton()
            }
        }
    }

    /// Puts the panic control in the top-right corner, for screens that hide their
    /// navigation bar.
    func panicHideOverlay(topPadding: CGFloat = 18) -> some View {
        overlay(alignment: .topTrailing) {
            PanicHideButton()
                .padding(.trailing, 20)
                .padding(.top, topPadding)
        }
    }
}
