import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var page = 0

    var body: some View {
        ZStack {
            DashboardBackdrop()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    OnboardingWelcomePage().tag(0)
                    OnboardingPrivacyPage().tag(1)
                    OnboardingHealthPage().tag(2)
                    OnboardingReadyPage {
                        hasCompletedOnboarding = true
                    }.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        }
    }
}

private struct OnboardingWelcomePage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 40)

                VStack(alignment: .leading, spacing: 14) {
                    ZStack {
                        Circle()
                            .trim(from: 0.14, to: 0.87)
                            .stroke(LinearGradient.chillBrand, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 64, height: 64)
                            .rotationEffect(.degrees(-42))
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(Color.chillMint)
                    }

                    Text("Welcome to ChillMate")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("A private health companion for chemsex harm reduction. No accounts, no tracking, nothing leaves your phone.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    OnboardingFeatureRow(
                        symbol: "lock.shield.fill",
                        title: "Fully private",
                        detail: "Everything stays on your device. ChillMate never sends your data anywhere.",
                        tint: .cyan
                    )
                    OnboardingFeatureRow(
                        symbol: "heart.text.square.fill",
                        title: "Harm reduction tools",
                        detail: "Log Chills, check-ins, STI tests, aftercare, recovery, and timers in one place.",
                        tint: Color.chillMint
                    )
                    OnboardingFeatureRow(
                        symbol: "chart.xyaxis.line",
                        title: "Patterns without judgment",
                        detail: "See what your data says about your health, privately, at your own pace.",
                        tint: Color.chillSecondaryBlue
                    )
                }

                Spacer(minLength: 80)
            }
            .padding(28)
        }
    }
}

private struct OnboardingPrivacyPage: View {
    @AppStorage("requiresFaceID") private var requiresFaceID = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 40)

                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(Color.chillPrimary)
                        .frame(width: 72, height: 72)
                        .glassSurface(radius: 36, tint: Color.chillPrimary.opacity(0.16))

                    Text("Your data, locked down")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("ChillMate stores everything locally with full iOS data protection. You can add Face ID and a PIN to make sure only you can open it.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    OnboardingFeatureRow(symbol: "faceid", title: "Face ID lock", detail: "Requires Face ID every time the app opens.", tint: Color.chillPrimary)
                    OnboardingFeatureRow(symbol: "iphone.lock", title: "Panic button", detail: "One tap replaces the screen with a black decoy — useful in crowded spaces.", tint: .orange)
                    OnboardingFeatureRow(symbol: "icloud.fill", title: "Encrypted iCloud backup", detail: "Optional. Your data is encrypted before it leaves the app.", tint: .cyan)
                }

                if !requiresFaceID {
                    GlassActionButton(prominent: true) {
                        enableFaceID()
                    } label: {
                        Label("Enable Face ID lock", systemImage: "faceid")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.chillMint)
                        Text("Face ID lock is on")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.chillText)
                    }
                    .padding(14)
                    .glassSurface(radius: 20, tint: Color.chillMint.opacity(0.10))
                }

                if let message {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .padding(12)
                        .glassSurface(radius: 16, tint: .white.opacity(0.12))
                }

                Spacer(minLength: 80)
            }
            .padding(28)
        }
    }

    private func enableFaceID() {
        Task {
            do {
                let success = try await AppAuthenticator.authenticate(reason: "Protect ChillMate with Face ID")
                await MainActor.run {
                    requiresFaceID = success
                    message = success ? nil : "Face ID could not be enabled. You can turn it on later in Settings."
                }
            } catch {
                await MainActor.run {
                    message = "Face ID not available. You can set up a PIN in Settings."
                }
            }
        }
    }
}

private struct OnboardingHealthPage: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 40)

                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(Color.chillPrimary)
                        .frame(width: 72, height: 72)
                        .glassSurface(radius: 36, tint: Color.chillPrimary.opacity(0.16))

                    Text("Private check-ins")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("ChillMate can send discreet reminders — a private check-in, aftercare nudge, or daily affirmation. They use vague lock-screen wording. You can turn them all off anytime.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    OnboardingFeatureRow(symbol: "eye.slash.fill", title: "Discreet wording", detail: "Lock screen shows 'ChillMate — private check-in'. No specifics visible.", tint: Color.chillSecondary)
                    OnboardingFeatureRow(symbol: "sparkles", title: "Daily affirmations", detail: "Optional. A short supportive message each morning.", tint: Color.chillMint)
                    OnboardingFeatureRow(symbol: "exclamationmark.triangle.fill", title: "Risk alerts", detail: "Private warning when patterns suggest a health check-in is worth having.", tint: .orange)
                }

                if !notificationsEnabled {
                    GlassActionButton(prominent: true) {
                        enableNotifications()
                    } label: {
                        Label("Enable notifications", systemImage: "bell.badge.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.chillMint)
                        Text("Notifications are on")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.chillText)
                    }
                    .padding(14)
                    .glassSurface(radius: 20, tint: Color.chillMint.opacity(0.10))
                }

                if let message {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .padding(12)
                        .glassSurface(radius: 16, tint: .white.opacity(0.12))
                }

                Spacer(minLength: 80)
            }
            .padding(28)
        }
    }

    private func enableNotifications() {
        Task {
            do {
                let granted = try await NotificationService.shared.requestAuthorization()
                await MainActor.run {
                    notificationsEnabled = granted
                    if granted {
                        NotificationService.shared.scheduleCheckInReminder()
                    }
                    message = granted ? nil : "Notification permission was not granted. You can enable it later in Settings."
                }
            } catch {
                await MainActor.run {
                    message = "Could not request notification permission."
                }
            }
        }
    }
}

private struct OnboardingReadyPage: View {
    let complete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 40)

                VStack(alignment: .leading, spacing: 14) {
                    Text("You're set")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("ChillMate is ready. Start by adding your first log, planning a session, or just exploring the tools.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    OnboardingFeatureRow(symbol: "plus.circle.fill", title: "Log a Chill", detail: "Tap the + button on the dashboard to record sessions, sleep, and aftercare.", tint: Color.chillPrimary)
                    OnboardingFeatureRow(symbol: "checkmark.shield.fill", title: "Plan ahead", detail: "Use the Plan tool to set limits and prep before a session.", tint: Color.chillMint)
                    OnboardingFeatureRow(symbol: "gear", title: "Settings & privacy", detail: "Face ID, notifications, Apple Watch, HealthKit, and backup — all in Settings.", tint: Color.chillSecondaryBlue)
                }

                GlassActionButton(prominent: true) {
                    complete()
                } label: {
                    Label("Open ChillMate", systemImage: "arrow.right.circle.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 80)
            }
            .padding(28)
        }
    }
}

private struct OnboardingFeatureRow: View {
    let symbol: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .glassSurface(radius: 21, tint: tint.opacity(0.14))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .glassSurface(radius: 22, tint: .white.opacity(0.18))
    }
}
