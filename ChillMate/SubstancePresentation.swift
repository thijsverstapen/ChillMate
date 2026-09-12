import SwiftUI
import ChillMateCore

/// How substances and interaction severities look, kept apart from what they are.
///
/// `Substance.swift` and `SubstanceInteractions.swift` are the app's domain: what
/// a substance is, how two of them combine, what the published sources say. Both
/// imported SwiftUI, for one colour each and for two views that happened to be
/// written at the bottom of the same file. That import is what stops the domain
/// from being ordinary Swift that anything can compile and anything can test.
///
/// Nothing here decides anything. Every value is a rendering of a decision made
/// somewhere else, which is the point of the split: a severity is a severity
/// whether or not there is a screen.

extension Substance {

    var tint: Color {
        switch self {
        case .cannabis:
            Color.chillMint
        case .alcohol:
            .orange
        case .mdma:
            Color.chillMint
        case .threeMMC:
            .red
        case .ketamine:
            Color.chillPrimary
        case .ghb:
            Color.chillSecondaryBlue
        case .gbl:
            Color.chillMint
        case .cocaine:
            Color.chillSecondaryBlue
        case .poppers:
            Color.chillMint
        case .kamagra:
            Color.chillSecondaryBlue
        case .viagra:
            .indigo
        case .psychedelics:
            .indigo
        case .benzodiazepines:
            .purple
        case .methamphetamine:
            .pink
        case .unknown:
            .gray
        case .other:
            .teal
        }
    }
}

extension SubstanceInteraction.Level {

    var color: Color {
            switch self {
            case .caution: .yellow
            case .serious: .orange
            case .critical: .red
            }
        }
}

struct SubstanceInteractionCard: View {
    let warnings: [SubstanceInteraction]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(warnings) { interaction in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: interaction.level.symbol)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(interaction.level.color)
                        .frame(width: 28)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(interaction.level.label)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(interaction.level.color)

                        Text(interaction.warning)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.chillText.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)

                        // Where the rating comes from, per row. Without it every
                        // warning carries the same apparent authority, and they do
                        // not all rest on the same thing: some match a published
                        // chart, some sit deliberately above it, and the ones
                        // involving poppers or sildenafil are not on it at all.
                        Label(interaction.corroboration.label, systemImage: interaction.corroboration.symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
                .padding(12)
                .background(interaction.level.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityElement(children: .combine)
            }

            InteractionSourceFooter()
        }
    }
}

/// Names the source the ratings above are checked against, and links to it.
///
/// The screen used to assert severities with no attribution at all, which is a
/// lot of authority to take on for content a user may act on at four in the
/// morning. Saying whose chart it is also gives someone a way to go and read the
/// full entry, which is always longer than what fits here.
struct InteractionSourceFooter: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ratings are checked against TripSit’s drug combination chart. Where ChillMate rates something higher, the row says so.")
                .font(.caption2)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: URL(string: "https://combo.tripsit.me")!) {
                Label("Open TripSit’s chart", systemImage: "arrow.up.right.square")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(Color.chillPrimary)

            Text("No chart can tell you a combination is safe. A missing entry means nobody has rated it, not that nothing happens.")
                .font(.caption2)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}
