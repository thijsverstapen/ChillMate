import SwiftUI
import ChillMateCore

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
                    Text("You can confirm your age in two private ways. The date of birth you enter stays on this device unless you turn on iCloud sync. The optional Apple Account check returns only a yes-or-no \"18 or older\" answer from Apple; it never shares your birthdate or name with the app.")
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
