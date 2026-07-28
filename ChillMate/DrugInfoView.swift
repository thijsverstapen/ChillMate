import Foundation
import SwiftUI

struct DrugInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Substance info"),
                            subtitle: String(localized: "Neutral safety information, warning signs, and source links. ChillMate does not recommend substance use, amounts, or combinations."),
                            symbol: "pills.fill",
                            tint: Color.chillPrimary
                        )

                        MedicalSafetyDisclaimerCard(compact: true)

                        ForEach(Substance.allCases.filter { $0 != .unknown && $0 != .other }) { substance in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    Image(systemName: substance.symbolName)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(substance.tint)
                                        .frame(width: 38, height: 38)
                                        .glassSurface(radius: 19, tint: substance.tint.opacity(0.14))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(substance.localizedDisplayName)
                                            .font(.headline)
                                            .foregroundStyle(Color.chillText)
                                        Text("Safety reference")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.chillSecondary)
                                    }
                                }

                                Text(substance.informationSummary)
                                    .font(.callout)
                                    .foregroundStyle(Color.chillSecondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                DrugInfoMiniSection(title: String(localized: "Main risks"), rows: substance.mainRisks, tint: substance.tint)
                                DrugInfoMiniSection(title: String(localized: "Mixing risks"), rows: substance.mixingRisks, tint: .orange)
                                DrugInfoMiniSection(title: String(localized: "Seek help now if"), rows: substance.seekHelpSigns, tint: .red)

                                if let referenceURL = substance.referenceURL {
                                    Button {
                                        openURL(referenceURL)
                                    } label: {
                                        Label(substance.referenceLabel, systemImage: "link")
                                            .font(.caption.weight(.bold))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(substance.tint)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .glassSurface(radius: 24, tint: substance.tint.opacity(0.08))
                        }
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

private struct DrugInfoMiniSection: View {
    let title: String
    let rows: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillText)

            ForEach(rows, id: \.self) { row in
                Label(row, systemImage: "smallcircle.filled.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassSurface(radius: 18, tint: tint.opacity(0.06))
    }
}
