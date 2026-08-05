import Foundation
import SwiftUI
import UIKit

struct PanicSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DefaultsKey.trustedContactName) private var trustedContactName = ""
    @AppStorage(DefaultsKey.trustedContactPhone) private var trustedContactPhone = ""
    @State private var isBreathing = false
    @State private var breathStep = 0
    @State private var completedGroundingSteps: Set<Int> = []

    private let breathingSteps = ["Breathe in", "Hold gently", "Breathe out", "Rest"]
    private let groundingSteps = [
        String(localized: "Name 5 things you can see."),
        String(localized: "Touch 4 things and notice texture."),
        String(localized: "Listen for 3 sounds."),
        String(localized: "Notice 2 smells, or name 2 safe places."),
        String(localized: "Notice 1 taste, or take one slow sip of water.")
    ]

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Panic support"),
                            subtitle: String(localized: "A low-stimulation space for anxiety, panic, or feeling unwell. Start the breathing timer, check off grounding steps, then call help if you need another person."),
                            symbol: "lungs.fill",
                            tint: Color.chillPrimary
                        )
                        .sensoryFeedback(.impact(flexibility: .soft), trigger: breathStep)

                        VStack(spacing: 18) {
                            ZStack {
                                Circle()
                                    .fill(Color.chillPrimary.opacity(0.18))
                                    .frame(width: isBreathing ? 174 : 118, height: isBreathing ? 174 : 118)

                                Circle()
                                    .stroke(Color.chillMint.opacity(0.70), lineWidth: 8)
                                    .frame(width: 150, height: 150)

                                VStack(spacing: 6) {
                                    Text(isBreathing ? breathingSteps[breathStep] : String(localized: "Ready"))
                                        .font(.title3.bold())
                                        .foregroundStyle(Color.chillText)
                                    Text("You’re safe right now")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.chillSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Button(isBreathing ? "Stop breathing timer" : "Start breathing timer") {
                                toggleBreathing()
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .buttonStyle(ChillPillButtonStyle(prominent: true))
                        }
                        .padding(18)
                        .glassSurface(radius: 30, tint: .white.opacity(0.18), interactive: true)

                        VStack(alignment: .leading, spacing: 12) {
                            CareSectionTitle(title: String(localized: "Fast actions"), symbol: "phone.fill")

                            Button(action: callTrustedContact) {
                                Label(trustedContactName.isEmpty ? "Call trusted contact" : "Call \(trustedContactName)", systemImage: "person.crop.circle.badge.checkmark")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: true))
                            .disabled(trustedContactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(trustedContactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)

                            Button(role: .destructive, action: callEmergencyServices) {
                                Label("Call emergency services \(EmergencyContactInfo.number)", systemImage: "sos.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: true, tint: .red))
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: .white.opacity(0.18), interactive: true)

                        panicSupportViewContinued
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(Text(verbatim: ""))
        }
    }

    /// Second half of `PanicSupportView`'s body, which ran to 137 lines.
    ///
    /// Split purely for readability: these are the same views in the same
    /// order, still direct children of the same container.
    @ViewBuilder
    private var panicSupportViewContinued: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    CareSectionTitle(title: String(localized: "Grounding steps"), symbol: "hand.raised.fill")

                    Spacer()

                    Button("Renew") {
                        completedGroundingSteps.removeAll()
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillPrimary)
                    .disabled(completedGroundingSteps.isEmpty)
                    .opacity(completedGroundingSteps.isEmpty ? 0.45 : 1)
                }

                ForEach(Array(groundingSteps.enumerated()), id: \.offset) { index, step in
                    Button {
                        if completedGroundingSteps.contains(index) {
                            completedGroundingSteps.remove(index)
                        } else {
                            completedGroundingSteps.insert(index)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: completedGroundingSteps.contains(index) ? "checkmark.circle.fill" : "circle")
                                .font(.headline)
                                .foregroundStyle(completedGroundingSteps.contains(index) ? Color.chillMint : Color.chillSecondary)

                            Text(step)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(completedGroundingSteps.contains(index) ? Color.chillSecondary : Color.chillText)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassSurface(radius: 18, tint: (completedGroundingSteps.contains(index) ? Color.chillMint : Color.chillPrimary).opacity(0.08), interactive: true)
                    }
                    .buttonStyle(ChillPlainButtonStyle())
                }
            }
            .padding(16)
            .glassSurface(radius: 28, tint: .white.opacity(0.16), interactive: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("References")
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
                Link(String(localized: "Mind: panic attacks and grounding"), destination: URL(string: "https://www.mind.org.uk/information-support/types-of-mental-health-problems/anxiety-and-panic-attacks/panic-attacks")!)
                Link(String(localized: "NHS: breathing exercises for stress"), destination: URL(string: "https://www.nhs.uk/mental-health/self-help/guides-tools-and-activities/breathing-exercises-for-stress/")!)
                Link(String(localized: "Government.nl: emergency number 112"), destination: URL(string: "https://www.government.nl/topics/emergency-number-112")!)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.chillPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassSurface(radius: 24, tint: .black.opacity(0.04))

            EmergencyRedFlagCard()
    }

    private func toggleBreathing() {
        isBreathing.toggle()
        if isBreathing {
            Task {
                while isBreathing {
                    await MainActor.run {
                        breathStep = (breathStep + 1) % breathingSteps.count
                    }
                    try? await Task.sleep(for: .seconds(4))
                }
            }
        }
    }

    private func callTrustedContact() {
        let phone = trustedContactPhone.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "tel://\(phone)") else { return }
        UIApplication.shared.open(url)
    }

    private func callEmergencyServices() {
        guard let url = EmergencyContactInfo.dialURL else { return }
        UIApplication.shared.open(url)
    }
}
