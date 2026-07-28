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

        /// Resolved per access rather than cached, so the label follows the app's
        /// current language. The two highest severities used to be raw literals and
        /// rendered in English for every non-English user, while the lowest one
        /// translated correctly.
        var label: String {
            switch self {
            case .caution: String(localized: "Worth noting")
            case .serious: String(localized: "Significant risk")
            case .critical: String(localized: "High-risk combination")
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

extension SubstanceInteraction: Identifiable {
    /// Stable identity derived from the combination itself, so rows keep their
    /// identity across re-evaluations even though the warning text is re-localized
    /// on every access and the table is rebuilt each time it is read.
    var id: String {
        substances.map(\.rawValue).sorted().joined(separator: "+")
    }
}

enum SubstanceInteractionChecker {
    /// Computed rather than `static let` so every `String(localized:)` below resolves
    /// against the language in effect at call time. As a stored static, the whole
    /// table was localized once at first access and then frozen for the lifetime of
    /// the process, which would strand these warnings in the launch language.
    private static var interactions: [SubstanceInteraction] {[
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

        // MARK: Stimulant + alcohol
        SubstanceInteraction(
            substances: [.cocaine, .alcohol],
            level: .serious,
            warning: String(localized: "Cocaine and alcohol together form cocaethylene in the liver. It puts more strain on the heart than cocaine alone and stays in the body longer, raising the risk of chest pain and irregular heartbeat. Alcohol also masks how much cocaine you have taken.")
        ),
        SubstanceInteraction(
            substances: [.mdma, .alcohol],
            level: .serious,
            warning: String(localized: "Alcohol dehydrates you while MDMA raises your body temperature, and each masks how strongly the other is hitting. Together they increase the risk of overheating, dehydration, and a much harder comedown.")
        ),
        SubstanceInteraction(
            substances: [.threeMMC, .alcohol],
            level: .serious,
            warning: String(localized: "3-MMC masks how drunk you are, which makes it easy to keep drinking past your limit. The combination also raises heart rate and blood pressure and makes redosing harder to judge.")
        ),

        // MARK: Depressant stacking
        SubstanceInteraction(
            substances: [.cannabis, .alcohol],
            level: .caution,
            warning: String(localized: "Cannabis suppresses the urge to vomit, which is one of the body's defences against alcohol poisoning. Combined, impairment and dizziness also increase sharply. If someone cannot be woken, place them on their side and call emergency services.")
        ),
        SubstanceInteraction(
            substances: [.ghb, .poppers],
            level: .serious,
            warning: String(localized: "GHB and poppers both lower blood pressure. Together they can cause fainting, a fall, or losing consciousness at a moment when you cannot protect yourself.")
        ),
        SubstanceInteraction(
            substances: [.gbl, .poppers],
            level: .serious,
            warning: String(localized: "GBL and poppers both lower blood pressure. The drop can be sudden and cause fainting or a fall.")
        ),

        // MARK: Dissociative + empathogen
        SubstanceInteraction(
            substances: [.mdma, .ketamine],
            level: .caution,
            warning: String(localized: "MDMA and ketamine together deepen disorientation and make it harder to judge your surroundings, your limits, and whether the people around you still feel safe. Consent gets harder to give and to read.")
        ),

        // MARK: Psychedelics
        SubstanceInteraction(
            substances: [.psychedelics, .mdma],
            level: .serious,
            warning: String(localized: "Psychedelics and MDMA stack serotonergic and cardiac load, and the psychological effects become much less predictable. Overheating and a heavy, long comedown are both more likely.")
        ),
        SubstanceInteraction(
            substances: [.psychedelics, .cocaine],
            level: .caution,
            warning: String(localized: "Adding a stimulant to a psychedelic raises heart rate and commonly turns a manageable experience into anxiety or panic. It also makes it harder to sit still and let a difficult moment pass.")
        ),
        SubstanceInteraction(
            substances: [.psychedelics, .threeMMC],
            level: .caution,
            warning: String(localized: "Adding 3-MMC to a psychedelic raises heart rate and anxiety and makes the experience harder to steer. Panic is a common outcome.")
        ),

        // MARK: Erectile medication + stimulants
        //
        // Distinct from the poppers pairs above: those are a blood-pressure collapse,
        // these are cumulative cardiac load. Both Kamagra and Viagra are listed for
        // each stimulant because matching is by exact set membership.
        SubstanceInteraction(
            substances: [.viagra, .cocaine],
            level: .serious,
            warning: String(localized: "Viagra and cocaine pull your circulation in opposite directions while both put the heart under load. This raises the risk of chest pain and irregular heartbeat, especially alongside a long session.")
        ),
        SubstanceInteraction(
            substances: [.kamagra, .cocaine],
            level: .serious,
            warning: String(localized: "Kamagra and cocaine both put the heart under load while pulling your circulation in opposite directions, raising the risk of chest pain and irregular heartbeat.")
        ),
        SubstanceInteraction(
            substances: [.viagra, .mdma],
            level: .caution,
            warning: String(localized: "Viagra and MDMA together add cardiac strain and can lower blood pressure more than expected. Take breaks, keep cool, and stop if your chest feels tight.")
        ),
        SubstanceInteraction(
            substances: [.kamagra, .mdma],
            level: .caution,
            warning: String(localized: "Kamagra and MDMA together add cardiac strain and can lower blood pressure more than expected. Take breaks and stop if your chest feels tight.")
        ),
        SubstanceInteraction(
            substances: [.viagra, .threeMMC],
            level: .caution,
            warning: String(localized: "Viagra and 3-MMC together add cardiac strain during a session that is often already long. Watch for chest tightness and a racing heart that does not settle.")
        ),
        SubstanceInteraction(
            substances: [.kamagra, .threeMMC],
            level: .caution,
            warning: String(localized: "Kamagra and 3-MMC together add cardiac strain during a session that is often already long. Watch for chest tightness and a racing heart that does not settle.")
        ),
    ]}

    /// Warnings for the selected set, most severe first.
    ///
    /// The tie-break on `id` matters now that the table carries several entries at
    /// the same level: `sorted(by:)` is not guaranteed stable, so without it two
    /// equally-severe warnings could swap places between evaluations and make
    /// SwiftUI re-identify the rows.
    static func warnings(for selected: Set<Substance>) -> [SubstanceInteraction] {
        interactions
            .filter { $0.substances.isSubset(of: selected) }
            .sorted { first, second in
                first.level == second.level ? first.id < second.id : first.level > second.level
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
                    }
                }
                .padding(12)
                .background(interaction.level.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}
