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

                                if let reference = substance.reference {
                                    DrugReferenceSection(reference: reference, tint: substance.tint)
                                }

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
            .navigationTitle(Text(verbatim: ""))
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


/// Dose ladder and timings for one substance, with the source under them.
///
/// The attribution is not decoration. These are numbers someone may act on, so
/// the screen says where each came from and lets the reader go and check. The
/// heading says "commonly reported" rather than "recommended" for the same
/// reason: this describes what is reported, it does not endorse it.
private struct DrugReferenceSection: View {
    let reference: SubstanceReference
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Commonly reported ranges")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillText)

            Text("Not a recommendation. Strength and contents vary between batches, and neither is something ChillMate can see.")
                .font(.caption2)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let reason = reference.noDoseReason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(reference.doses.enumerated()), id: \.offset) { _, dose in
                VStack(alignment: .leading, spacing: 4) {
                    Text(dose.route.label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(tint)

                    DoseRow(label: String(localized: "Light"), value: dose.unit.range(dose.light))
                    DoseRow(label: String(localized: "Common"), value: dose.unit.range(dose.common))
                    DoseRow(label: String(localized: "Strong"), value: dose.unit.range(dose.strong))
                    DoseRow(
                        label: String(localized: "Heavy"),
                        value: String(localized: "\(dose.unit.from(dose.heavyFrom)) and above"),
                        isWarning: true
                    )
                }
                .padding(.top, 2)
            }

            if let timing = reference.timing {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Timing")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(tint)

                    DoseRow(label: String(localized: "Onset"), value: timing.onsetText)
                    DoseRow(label: String(localized: "Peak"), value: timing.peakText)
                    DoseRow(label: String(localized: "Total"), value: timing.totalText)
                }
                .padding(.top, 2)
            }

            if let redose = reference.redoseGuidance {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Before a second dose")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(tint)
                    Text(redose)
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }

            Text("Source: \(reference.source.name)")
                .font(.caption2)
                .foregroundStyle(Color.chillSecondary.opacity(0.85))
                .accessibilityLabel(Text("Source: \(reference.source.name)"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassSurface(radius: 18, tint: tint.opacity(0.06))
    }
}

private struct DoseRow: View {
    let label: String
    let value: String
    var isWarning = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.chillSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isWarning ? Color.chillIconOrange : Color.chillText)
        }
        .accessibilityElement(children: .combine)
    }
}
