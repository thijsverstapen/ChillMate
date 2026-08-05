import Foundation
import SwiftUI

struct ConsentBoundariesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DefaultsKey.consentBoundaryWant) private var want = ""
    @AppStorage(DefaultsKey.consentBoundaryNo) private var no = ""
    @AppStorage(DefaultsKey.consentCheckInPhrase) private var checkInPhrase = ""
    @AppStorage(DefaultsKey.consentExitPlan) private var exitPlan = ""

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Boundaries"),
                            subtitle: String(localized: "Write down what you want, what is off-limits, how someone should check in, and how you can leave. This stays on-device."),
                            symbol: "hand.raised.fill",
                            tint: Color.chillMint
                        )

                        ConsentMiniCard()

                        BoundaryPromptField(title: String(localized: "What I want tonight"), placeholder: String(localized: "Examples: slower pace, condoms, checking in, staying with friends"), text: $want)
                        BoundaryPromptField(title: String(localized: "Hard no"), placeholder: String(localized: "Examples: no filming, no injection use, no certain acts, no pressure to continue"), text: $no)
                        BoundaryPromptField(title: String(localized: "Check-in phrase"), placeholder: String(localized: "Example: ask me 'green, yellow, or red?'"), text: $checkInPhrase)
                        BoundaryPromptField(title: String(localized: "Exit plan"), placeholder: String(localized: "Example: I can call my trusted contact, order a ride, or leave with a friend"), text: $exitPlan)

                        Text("Consent can be changed or withdrawn at any time. If a memory gap or consent concern appears later, use panic support, a trusted contact, a sexual-health service, a sexual-assault support centre, or emergency help.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .glassSurface(radius: 24, tint: Color.chillMint.opacity(0.08))
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(Text(verbatim: ""))
            .endEditingOnTap()
        }
    }
}

/// Shared with SafetyAutopilotView, so it is internal rather than file-private.
struct ConsentMiniCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CareSectionTitle(title: String(localized: "Consent basics"), symbol: "checkmark.shield.fill")
            ForEach([
                String(localized: "Clear is better than assumed."),
                String(localized: "Pressure, fear, blackout, or being unable to respond means stop."),
                String(localized: "A simple check-in phrase can make boundaries easier to protect.")
            ], id: \.self) { line in
                Label(line, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassSurface(radius: 26, tint: Color.chillMint.opacity(0.08))
    }
}

struct BoundaryPromptField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.chillText)
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.chillText)
                .padding(14)
                .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)
        }
        .padding(16)
        .glassSurface(radius: 26, tint: .black.opacity(0.04), interactive: true)
    }
}
