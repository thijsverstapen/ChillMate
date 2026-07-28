import Foundation
import SwiftUI

struct DrugCheckingEducationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Checking info"),
                            subtitle: String(localized: "Neutral support information for the Netherlands. Test results and online information reduce uncertainty, but they cannot make use risk-free."),
                            symbol: "checkmark.seal.text.page.fill",
                            tint: Color.chillSecondaryBlue
                        )

                        MedicalSafetyDisclaimerCard(compact: true)

                        DrugCheckingPrincipleCard(
                            title: String(localized: "Assume strength can vary"),
                            detail: String(localized: "Strength and contents can differ between batches. If you feel pressure to continue, pause and consider support before doing anything else."),
                            symbol: "waveform.path.ecg"
                        )
                        DrugCheckingPrincipleCard(
                            title: String(localized: "Do not mix to compensate"),
                            detail: String(localized: "Mixing stimulants, depressants, poppers with erection medication, or unknown substances can change risk faster than expected."),
                            symbol: "exclamationmark.triangle.fill"
                        )
                        DrugCheckingPrincipleCard(
                            title: String(localized: "Use the app as a pause point"),
                            detail: String(localized: "Check-ins, craving delay, risk checker, and the plan page are meant to slow decisions down, not approve a substance, amount, or combination."),
                            symbol: "pause.circle.fill"
                        )

                        EvidenceSourcesSection(title: String(localized: "Dutch information sources"), sources: EvidenceLibrary.drugChecking)
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
        }
    }
}

private struct DrugCheckingPrincipleCard: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.chillSecondaryBlue)
                .frame(width: 42, height: 42)
                .glassSurface(radius: 21, tint: Color.chillSecondaryBlue.opacity(0.12))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassSurface(radius: 26, tint: Color.chillSecondaryBlue.opacity(0.08))
    }
}
