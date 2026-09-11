import SwiftUI

/// The cover drawn over the app when it leaves the foreground.
///
/// Split out of `DashboardView.swift` unchanged.

struct PrivacyShieldView: View {
    let dismiss: () -> Void
    @State private var showUnlockButton = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 14) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(.white.opacity(0.38))

                    Text("Screen paused")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.46))
                }

                Spacer()

                if showUnlockButton {
                    Button(action: dismiss) {
                        Text("Resume")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(ChillPlainButtonStyle())
                    .transition(.opacity)
                }
            }
            .padding(.bottom, 48)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                showUnlockButton = true
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("Show unlock"))
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}
