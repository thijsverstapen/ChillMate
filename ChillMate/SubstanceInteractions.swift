import SwiftUI

struct SubstanceInteraction {
    enum Level: Int, Comparable {
        case caution = 1
        case serious = 2
        case critical = 3

        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }

        var color: Color {
            switch self {
            case .caution: .yellow
            case .serious: .orange
            case .critical: .red
            }
        }

        var label: String {
            switch self {
            case .caution: String(localized: "Worth noting")
            case .serious: "Significant risk"
            case .critical: "High-risk combination"
            }
        }

        var symbol: String {
            switch self {
            case .caution: "exclamationmark.circle.fill"
            case .serious: "exclamationmark.triangle.fill"
            case .critical: "exclamationmark.octagon.fill"
            }
        }
    }

    let substances: Set<Substance>
    let level: Level
    let warning: String
}

enum SubstanceInteractionChecker {
    private static let interactions: [SubstanceInteraction] = [
        SubstanceInteraction(
            substances: [.ghb, .alcohol],
            level: .critical,
            warning: String(localized: "GHB and alcohol together strongly increase the risk of unconsciousness and breathing problems. This combination has caused deaths. Seek immediate help if someone cannot be woken.")
        ),
        SubstanceInteraction(
            substances: [.gbl, .alcohol],
            level: .critical,
            warning: String(localized: "GBL converts to GHB in the body. Combined with alcohol, the risk of losing consciousness or stopping breathing rises sharply. This is a life-threatening combination.")
        ),
        SubstanceInteraction(
            substances: [.ghb, .gbl],
            level: .critical,
            warning: String(localized: "GHB and GBL are effectively the same substance. Combining them stacks the dose unpredictably and can cause sudden unconsciousness.")
        ),
        SubstanceInteraction(
            substances: [.poppers, .kamagra],
            level: .critical,
            warning: String(localized: "Poppers and Kamagra together can cause a sudden, dangerous drop in blood pressure. This can lead to fainting, stroke, or cardiac arrest. Do not combine these.")
        ),
        SubstanceInteraction(
            substances: [.poppers, .viagra],
            level: .critical,
            warning: String(localized: "Poppers and Viagra together can cause a dangerous blood pressure drop. This is a high-risk combination. Avoid it.")
        ),
        SubstanceInteraction(
            substances: [.ghb, .ketamine],
            level: .serious,
            warning: String(localized: "GHB and ketamine combine depressant and dissociative effects. This increases the risk of losing the ability to respond to problems around you.")
        ),
        SubstanceInteraction(
            substances: [.gbl, .ketamine],
            level: .serious,
            warning: String(localized: "GBL and ketamine together carry a higher risk of losing control and difficulty getting help.")
        ),
        SubstanceInteraction(
            substances: [.alcohol, .ketamine],
            level: .serious,
            warning: String(localized: "Alcohol and ketamine together combine depressant effects and can cause deeper disorientation and breathing problems.")
        ),
        SubstanceInteraction(
            substances: [.cocaine, .mdma],
            level: .serious,
            warning: String(localized: "Cocaine and MDMA both strain the heart. Combined, the risk of irregular heartbeat and overheating is significantly higher.")
        ),
        SubstanceInteraction(
            substances: [.cocaine, .threeMMC],
            level: .serious,
            warning: String(localized: "Cocaine and 3-MMC together stack stimulant effects on the heart and raise the risk of cardiac problems and anxiety.")
        ),
        SubstanceInteraction(
            substances: [.mdma, .threeMMC],
            level: .serious,
            warning: String(localized: "MDMA and 3-MMC together increase stimulant and serotonergic load. The combination raises heart rate, temperature, and the chance of a difficult crash.")
        ),
        SubstanceInteraction(
            substances: [.ghb, .cocaine],
            level: .caution,
            warning: String(localized: "Stimulants can mask GHB effects, making it harder to notice when a dose is too high. This increases the risk of accidental overdose.")
        ),
        SubstanceInteraction(
            substances: [.gbl, .cocaine],
            level: .caution,
            warning: String(localized: "Stimulants can mask GBL effects, making it harder to notice when a dose is too high.")
        ),
    ]

    static func warnings(for selected: Set<Substance>) -> [SubstanceInteraction] {
        interactions
            .filter { $0.substances.isSubset(of: selected) }
            .sorted { $0.level > $1.level }
    }
}

struct SubstanceInteractionCard: View {
    let warnings: [SubstanceInteraction]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(warnings.enumerated()), id: \.offset) { _, interaction in
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
                    }
                }
                .padding(12)
                .background(interaction.level.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}
