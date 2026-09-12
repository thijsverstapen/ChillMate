import Foundation

public struct SubstanceInteraction: Sendable {
    public enum Level: Int, Comparable, Sendable {
        case caution = 1
        case serious = 2
        case critical = 3

        public static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }

        /// Resolved per access rather than cached, so the label follows the app's
        /// current language. The two highest severities used to be raw literals and
        /// rendered in English for every non-English user, while the lowest one
        /// translated correctly.
        public var label: String {
            switch self {
            case .caution: String(localized: "Worth noting", bundle: .main)
            case .serious: String(localized: "Significant risk", bundle: .main)
            case .critical: String(localized: "High-risk combination", bundle: .main)
            }
        }

        public var symbol: String {
            switch self {
            case .caution: "exclamationmark.circle.fill"
            case .serious: "exclamationmark.triangle.fill"
            case .critical: "exclamationmark.octagon.fill"
            }
        }
    }

    public let substances: Set<Substance>
    public let level: Level
    public let warning: String
}

extension SubstanceInteraction {
    /// How far this row's severity is corroborated by a published source.
    ///
    /// The wording of every warning on this screen is ChillMate's own. What this
    /// records is narrower, and checkable: how the *rating* compares with
    /// TripSit's drug combination chart, which is the reference most
    /// harm-reduction services work from.
    ///
    /// It is derived rather than stored, from a generated copy of the chart in
    /// `InteractionChart`, so it cannot be asserted by hand for a row that was
    /// never actually checked. `InteractionChartTests` re-runs the comparison
    /// over the whole table.
    public enum Corroboration: Sendable {
        /// The chart rates this pair at the same level.
        case matchesChart
        /// The chart rates it at the same level, but the pair had to be read
        /// against a near neighbour: 3-MMC against mephedrone, or the
        /// psychedelics group against the most severe of LSD and mushrooms.
        case matchesChartApproximately
        /// ChillMate rates it above the chart, deliberately. Being more cautious
        /// than the source is allowed; being less cautious is what
        /// `InteractionChartTests` refuses.
        case ratedAboveChart
        /// The chart has no entry for this pair. True of everything involving
        /// poppers, Viagra or Kamagra, which it does not cover at all.
        case notOnChart
    }

    public var corroboration: Corroboration {
        guard let entry = InteractionChart.entry(for: substances) else { return .notOnChart }
        let chart = InteractionChart.Grading(rawValue: level.rawValue)
        if chart == entry.grading {
            return entry.isApproximate ? .matchesChartApproximately : .matchesChart
        }
        return .ratedAboveChart
    }
}

extension SubstanceInteraction.Corroboration {
    /// One short line under the warning, saying where the rating comes from.
    public var label: String {
        switch self {
        case .matchesChart:
            String(localized: "Matches TripSit’s combination chart", bundle: .main)
        case .matchesChartApproximately:
            String(localized: "Matches TripSit’s chart for a closely related substance", bundle: .main)
        case .ratedAboveChart:
            String(localized: "Rated higher here than on TripSit’s chart", bundle: .main)
        case .notOnChart:
            String(localized: "Not on TripSit’s chart", bundle: .main)
        }
    }

    public var symbol: String {
        switch self {
        case .matchesChart: "checkmark.seal.fill"
        case .matchesChartApproximately: "checkmark.seal"
        case .ratedAboveChart: "arrow.up.circle"
        case .notOnChart: "questionmark.circle"
        }
    }
}

extension SubstanceInteraction: Identifiable {
    /// Stable identity derived from the combination itself, so rows keep their
    /// identity across re-evaluations even though the warning text is re-localized
    /// on every access and the table is rebuilt each time it is read.
    public var id: String {
        substances.map(\.rawValue).sorted().joined(separator: "+")
    }
}

public enum SubstanceInteractionChecker {
    /// Computed rather than `static let` so every `String(localized:)` below resolves
    /// against the language in effect at call time. As a stored static, the whole
    /// table was localized once at first access and then frozen for the lifetime of
    /// the process, which would strand these warnings in the launch language.
    private static var interactions: [SubstanceInteraction] {[
        SubstanceInteraction(
            substances: [.ghb, .alcohol],
            level: .critical,
            warning: String(localized: "GHB and alcohol together strongly increase the risk of unconsciousness and breathing problems. This combination has caused deaths. Seek immediate help if someone cannot be woken.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.gbl, .alcohol],
            level: .critical,
            warning: String(localized: "GBL converts to GHB in the body. Combined with alcohol, the risk of losing consciousness or stopping breathing rises sharply. This is a life-threatening combination.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.ghb, .gbl],
            level: .critical,
            warning: String(localized: "GHB and GBL are effectively the same substance. Combining them stacks the dose unpredictably and can cause sudden unconsciousness.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.poppers, .kamagra],
            level: .critical,
            warning: String(localized: "Poppers and Kamagra together can cause a sudden, dangerous drop in blood pressure. This can lead to fainting, stroke, or cardiac arrest. Do not combine these.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.poppers, .viagra],
            level: .critical,
            warning: String(localized: "Poppers and Viagra together can cause a dangerous blood pressure drop. This is a high-risk combination. Avoid it.", bundle: .main)
        ),
        // Raised from serious to critical in 5.0.0. TripSit's chart rates all
        // three of these as dangerous, and the reason it gives is specific:
        // both substances cause ataxia and vomiting, and someone who goes under
        // while unable to sit up is at severe risk of aspirating. ChillMate was
        // rating them one step lower, which is the one direction that is never
        // defensible. `InteractionChartTests` now refuses it.
        SubstanceInteraction(
            substances: [.ghb, .ketamine],
            level: .critical,
            warning: String(localized: "GHB and ketamine both take your balance and both bring on vomiting, and together they can put you under. Someone who is sick while too out of it to sit up can choke. If you use both, stay with someone who is not using, and put anyone unresponsive on their side.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.gbl, .ketamine],
            level: .critical,
            warning: String(localized: "GBL becomes GHB in the body, and with ketamine both your balance and your ability to notice trouble go. Vomiting while unable to sit up is how this combination kills. Stay with someone sober and put anyone unresponsive on their side.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.alcohol, .ketamine],
            level: .critical,
            warning: String(localized: "Alcohol and ketamine together bring a very high risk of vomiting and of going under. Being sick while too out of it to sit up is the danger, not the disorientation. Keep someone sober nearby and put anyone who cannot be woken on their side.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.cocaine, .mdma],
            level: .serious,
            warning: String(localized: "Cocaine and MDMA both strain the heart. Combined, the risk of irregular heartbeat and overheating is significantly higher.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.cocaine, .threeMMC],
            level: .serious,
            warning: String(localized: "Cocaine and 3-MMC together stack stimulant effects on the heart and raise the risk of cardiac problems and anxiety.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.mdma, .threeMMC],
            level: .critical,
            warning: String(localized: "Both push serotonin hard, and together they carry a real risk of serotonin syndrome: a climbing temperature, a racing heart, stiff or twitching muscles, confusion. A stimulant also deepens the damage MDMA does. Overheating and a rigid, agitated state need emergency help, not water and a sit-down.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.ghb, .cocaine],
            level: .caution,
            warning: String(localized: "Stimulants can mask GHB effects, making it harder to notice when a dose is too high. This increases the risk of accidental overdose.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.gbl, .cocaine],
            level: .caution,
            warning: String(localized: "Stimulants can mask GBL effects, making it harder to notice when a dose is too high.", bundle: .main)
        ),

        // MARK: Stimulant + alcohol
        SubstanceInteraction(
            substances: [.cocaine, .alcohol],
            level: .serious,
            warning: String(localized: "Cocaine and alcohol together form cocaethylene in the liver. It puts more strain on the heart than cocaine alone and stays in the body longer, raising the risk of chest pain and irregular heartbeat. Alcohol also masks how much cocaine you have taken.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.mdma, .alcohol],
            level: .serious,
            warning: String(localized: "Alcohol dehydrates you while MDMA raises your body temperature, and each masks how strongly the other is hitting. Together they increase the risk of overheating, dehydration, and a much harder comedown.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.threeMMC, .alcohol],
            level: .serious,
            warning: String(localized: "3-MMC masks how drunk you are, which makes it easy to keep drinking past your limit. The combination also raises heart rate and blood pressure and makes redosing harder to judge.", bundle: .main)
        ),

        // MARK: Depressant stacking
        SubstanceInteraction(
            substances: [.cannabis, .alcohol],
            level: .caution,
            warning: String(localized: "Cannabis suppresses the urge to vomit, which is one of the body's defences against alcohol poisoning. Combined, impairment and dizziness also increase sharply. If someone cannot be woken, place them on their side and call emergency services.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.ghb, .poppers],
            level: .serious,
            warning: String(localized: "GHB and poppers both lower blood pressure. Together they can cause fainting, a fall, or losing consciousness at a moment when you cannot protect yourself.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.gbl, .poppers],
            level: .serious,
            warning: String(localized: "GBL and poppers both lower blood pressure. The drop can be sudden and cause fainting or a fall.", bundle: .main)
        ),

        // MARK: Dissociative + empathogen
        SubstanceInteraction(
            substances: [.mdma, .ketamine],
            level: .caution,
            warning: String(localized: "MDMA and ketamine together deepen disorientation and make it harder to judge your surroundings, your limits, and whether the people around you still feel safe. Consent gets harder to give and to read.", bundle: .main)
        ),

        // MARK: Psychedelics
        SubstanceInteraction(
            substances: [.psychedelics, .mdma],
            level: .serious,
            warning: String(localized: "Psychedelics and MDMA stack serotonergic and cardiac load, and the psychological effects become much less predictable. Overheating and a heavy, long comedown are both more likely.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.psychedelics, .cocaine],
            level: .caution,
            warning: String(localized: "Adding a stimulant to a psychedelic raises heart rate and commonly turns a manageable experience into anxiety or panic. It also makes it harder to sit still and let a difficult moment pass.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.psychedelics, .threeMMC],
            level: .caution,
            warning: String(localized: "Adding 3-MMC to a psychedelic raises heart rate and anxiety and makes the experience harder to steer. Panic is a common outcome.", bundle: .main)
        ),

        // MARK: Erectile medication doubled up
        //
        // Selecting both used to produce no warning at all, which reads as approval
        // for what is really one dose taken twice.
        SubstanceInteraction(
            substances: [.viagra, .kamagra],
            level: .serious,
            warning: String(localized: "Kamagra is sildenafil, the same active ingredient as Viagra. Taking both stacks one dose on top of another and raises the risk of a blood pressure drop, headache, vision changes, and an erection that will not go down. An erection lasting more than four hours needs urgent medical care.", bundle: .main)
        ),

        // MARK: Erectile medication + stimulants
        //
        // Distinct from the poppers pairs above: those are a blood-pressure collapse,
        // these are cumulative cardiac load. Both Kamagra and Viagra are listed for
        // each stimulant because matching is by exact set membership.
        SubstanceInteraction(
            substances: [.viagra, .cocaine],
            level: .serious,
            warning: String(localized: "Viagra and cocaine pull your circulation in opposite directions while both put the heart under load. This raises the risk of chest pain and irregular heartbeat, especially alongside a long session.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.kamagra, .cocaine],
            level: .serious,
            warning: String(localized: "Kamagra and cocaine both put the heart under load while pulling your circulation in opposite directions, raising the risk of chest pain and irregular heartbeat.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.viagra, .mdma],
            level: .caution,
            warning: String(localized: "Viagra and MDMA together add cardiac strain and can lower blood pressure more than expected. Take breaks, keep cool, and stop if your chest feels tight.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.kamagra, .mdma],
            level: .caution,
            warning: String(localized: "Kamagra and MDMA together add cardiac strain and can lower blood pressure more than expected. Take breaks and stop if your chest feels tight.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.viagra, .threeMMC],
            level: .caution,
            warning: String(localized: "Viagra and 3-MMC together add cardiac strain during a session that is often already long. Watch for chest tightness and a racing heart that does not settle.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.kamagra, .threeMMC],
            level: .caution,
            warning: String(localized: "Kamagra and 3-MMC together add cardiac strain during a session that is often already long. Watch for chest tightness and a racing heart that does not settle.", bundle: .main)
        ),

        // Filling out the table: the checker previously held 30 of the 66 possible
        // pairs, so "nothing on file" was the answer more often than not. A no-match
        // still never means safe, but it should be rare rather than routine.

        SubstanceInteraction(
            substances: [.alcohol, .poppers],
            level: .serious,
            warning: String(localized: "Alcohol and poppers both widen blood vessels and drop blood pressure. Together that means dizziness, fainting, and a pounding heart, and alcohol makes it harder to notice you are already lightheaded. Sit down before you use poppers.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.alcohol, .viagra],
            level: .serious,
            warning: String(localized: "Alcohol lowers blood pressure and Viagra lowers it further. Together they cause dizziness, headache, and fainting, and alcohol works against the erection you took Viagra for. Keep the drinking light if you use both.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.alcohol, .kamagra],
            level: .serious,
            warning: String(localized: "Kamagra is the same drug as Viagra and often sold at an unverified dose. With alcohol it can drop your blood pressure enough to make you faint, especially when you stand up quickly.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.alcohol, .psychedelics],
            level: .caution,
            warning: String(localized: "Alcohol blunts and muddles a trip rather than smoothing it, and it adds nausea and dehydration. It also makes a difficult headspace harder to steer out of.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.cannabis, .cocaine],
            level: .serious,
            warning: String(localized: "Cannabis does not calm cocaine down. Together they push heart rate and blood pressure higher than either alone, and the mix raises the chance of panic and chest pain. Stop and rest if your heart is racing.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.cannabis, .ghb],
            level: .serious,
            warning: String(localized: "Both are sedating, and cannabis suppresses vomiting. That matters here: it can mask the nausea that warns you a GHB dose is too high, and it raises the risk of choking if you fall asleep.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.cannabis, .gbl],
            level: .serious,
            warning: String(localized: "GBL becomes GHB in the body. Cannabis adds sedation and suppresses the nausea that would normally warn you a dose is too high, so an overshoot can arrive without warning.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.cannabis, .ketamine],
            level: .serious,
            warning: String(localized: "Both cloud coordination and awareness. Together you are much more likely to fall, lose track of where you are, or vomit while too out of it to sit up. Stay seated and stay with someone.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.cannabis, .mdma],
            level: .caution,
            warning: String(localized: "Cannabis can stretch and sharpen an MDMA experience in ways people do not expect, including anxiety and paranoia. It also dulls the sense of overheating, so keep drinking water and taking breaks.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.cannabis, .poppers],
            level: .caution,
            warning: String(localized: "Both lower blood pressure. Expect dizziness and a head rush, particularly if you stand up straight after.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.cannabis, .psychedelics],
            level: .caution,
            warning: String(localized: "Cannabis can amplify psychedelics unpredictably, turning a manageable trip into an overwhelming one. If you are going to use it at all, leave it until the peak has passed.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.cannabis, .threeMMC],
            level: .caution,
            warning: String(localized: "Cannabis on top of a stimulant tends to add anxiety and a faster heartbeat rather than taking the edge off, and it blurs how hard the comedown is hitting you.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.cannabis, .kamagra],
            level: .caution,
            warning: String(localized: "Both can lower blood pressure a little. The usual result is dizziness or a headache rather than anything serious, but stand up slowly.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.cannabis, .viagra],
            level: .caution,
            warning: String(localized: "Both can lower blood pressure a little. Expect dizziness or a headache, and stand up slowly.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.cocaine, .ketamine],
            level: .serious,
            warning: String(localized: "Cocaine drives your heart rate and blood pressure up while ketamine leaves you far less able to notice how your body is doing. Both also damage the nose. This combination puts real strain on the heart.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.cocaine, .poppers],
            level: .serious,
            warning: String(localized: "Cocaine tightens blood vessels and poppers open them suddenly. Swinging between the two strains the heart and can trigger an irregular heartbeat or a blackout. Get help for chest pain that does not pass.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.ketamine, .poppers],
            level: .serious,
            warning: String(localized: "Poppers drop blood pressure sharply and ketamine already takes your balance and judgement. Fainting and falls are the real risk here. Never use poppers standing up on ketamine.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.ketamine, .psychedelics],
            level: .serious,
            warning: String(localized: "Together these can detach you from your surroundings completely. People lose track of where they are, panic, or injure themselves without registering it. Only do this somewhere safe with someone sober.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.ketamine, .threeMMC],
            level: .serious,
            warning: String(localized: "The stimulant hides how sedated you actually are, so it is easy to take more ketamine than you can handle. It also raises heart rate and blood pressure, and heavy ketamine use damages the bladder.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.ketamine, .kamagra],
            level: .caution,
            warning: String(localized: "Ketamine pushes blood pressure up and Kamagra pushes it down, and ketamine makes it hard to notice feeling faint. Stay seated if you feel your head go light.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.ketamine, .viagra],
            level: .caution,
            warning: String(localized: "Ketamine raises blood pressure while Viagra lowers it, and ketamine makes it hard to tell how you are doing. Stay seated if you feel lightheaded.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.mdma, .poppers],
            level: .serious,
            warning: String(localized: "MDMA already raises heart rate, blood pressure, and body temperature. Poppers drop blood pressure suddenly on top of that, which can cause fainting and puts extra strain on the heart. Sit down first, and keep cooling down.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.mdma, .ghb],
            level: .serious,
            warning: String(localized: "MDMA masks how sedated GHB is making you, which is exactly how people redose past the point of going under. When the MDMA fades the full GHB dose is still there. Do not redose to chase the feeling.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.mdma, .gbl],
            level: .serious,
            warning: String(localized: "GBL turns into GHB in the body, and MDMA hides how sedated you are becoming. That combination is how people redose into unconsciousness. Once the MDMA fades the full GBL dose is still working.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.ghb, .threeMMC],
            level: .serious,
            warning: String(localized: "3MMC masks the sedation GHB is causing, so it is easy to redose past a safe amount. When the stimulant wears off the GHB is still there, and it can arrive all at once.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.gbl, .threeMMC],
            level: .serious,
            warning: String(localized: "3MMC hides how sedated GBL is making you, which is how doses stack up unnoticed. The sedation lands hard once the stimulant fades.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.ghb, .psychedelics],
            level: .serious,
            warning: String(localized: "Psychedelics distort time, which makes it very easy to lose track of when you last dosed GHB. GHB has a narrow margin between a normal dose and unconsciousness. Have someone sober keep the timing.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.gbl, .psychedelics],
            level: .serious,
            warning: String(localized: "Psychedelics distort your sense of time, and GBL has a very narrow margin between a normal dose and going under. Losing track of the last dose is the danger. Have someone sober hold the timing.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.ghb, .viagra],
            level: .serious,
            warning: String(localized: "Both lower blood pressure, and GHB can take you under with little warning. Fainting during sex, with nobody realising you are unconscious rather than asleep, is the risk.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.ghb, .kamagra],
            level: .serious,
            warning: String(localized: "Both lower blood pressure, and Kamagra is often an unverified dose. GHB can take you under quickly, and it is easy for others to mistake that for sleep.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.gbl, .viagra],
            level: .serious,
            warning: String(localized: "Both lower blood pressure and GBL can take you under fast. Losing consciousness during sex can be mistaken for falling asleep, which delays help.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.gbl, .kamagra],
            level: .serious,
            warning: String(localized: "Both lower blood pressure, and Kamagra is often sold at an unverified strength. GBL can take you under quickly, and that is easily mistaken for sleep.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.poppers, .threeMMC],
            level: .serious,
            warning: String(localized: "3MMC tightens blood vessels and raises blood pressure while poppers drop it suddenly. Swinging between the two strains the heart and can cause fainting or an irregular heartbeat.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.poppers, .psychedelics],
            level: .caution,
            warning: String(localized: "The sudden head rush from poppers can be disorienting and frightening in an altered state, and the blood pressure drop still brings a real risk of fainting. Sit down before using them.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.psychedelics, .viagra],
            level: .caution,
            warning: String(localized: "Viagra raises heart rate and can add to the physical anxiety a trip already brings, making it harder to tell nerves from a real problem.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.psychedelics, .kamagra],
            level: .caution,
            warning: String(localized: "Kamagra is often an unverified dose, and the racing heart it can cause is easily mistaken for trip anxiety, or the other way round.", bundle: .main)
        ),

        // MARK: Benzodiazepines
        //
        // New in 5.0.0 along with the substance itself. All four ratings are the
        // ones TripSit's combination chart gives, and the wording follows the
        // chart's own notes: strong unpredictable potentiation, unconsciousness
        // arriving fast, and aspiration as the thing that actually kills.
        SubstanceInteraction(
            substances: [.benzodiazepines, .alcohol],
            level: .critical,
            warning: String(localized: "Benzodiazepines and alcohol strengthen each other strongly and unpredictably, and can take someone under very fast. Blacking out is near certain and choking on vomit is the real danger. If someone cannot be woken, put them on their side and call emergency services.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .ghb],
            level: .critical,
            warning: String(localized: "Benzodiazepines and GHB strengthen each other strongly and unpredictably, and unconsciousness can arrive with almost no warning. Someone who cannot be woken needs the recovery position and emergency services, not sleep.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .gbl],
            level: .critical,
            warning: String(localized: "GBL becomes GHB in the body, and with a benzodiazepine the two strengthen each other unpredictably. People go under fast and are easily mistaken for asleep. Put anyone unresponsive on their side and call emergency services.", bundle: .main)
        ),
        // The stimulant pairs. TripSit rates these low risk because the two sides
        // cancel each other's *effects* — which is exactly the mechanism that
        // makes them worth a row here. A stimulant hides how sedated you are, and
        // when it fades the benzo has not gone anywhere. This is the same masking
        // the table already documents for GHB with stimulants.
        SubstanceInteraction(
            substances: [.benzodiazepines, .cocaine],
            level: .caution,
            warning: String(localized: "Each hides the other. Cocaine masks how sedated the benzo is making you, so it is easy to take more of both, and when the cocaine fades the full benzo dose is still there. Neither cancels the other out. They just make each other harder to judge.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .threeMMC],
            level: .caution,
            warning: String(localized: "3-MMC masks the sedation, so you feel more in control than you are, and the benzo is still working long after the stimulant has gone. That gap is where people redose on both without meaning to.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .mdma],
            level: .caution,
            warning: String(localized: "The benzo blunts the MDMA and MDMA hides the sedation, which mostly means you can misjudge both. Taking a benzo to sleep afterwards is common; taking one during is how people lose the thread of what they have had.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .cannabis],
            level: .caution,
            warning: String(localized: "Both sedate, and together that is heavier than either alone: more drowsiness, worse coordination, bigger gaps in memory. Not usually dangerous on its own, but it stacks badly with anything else that slows breathing.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .psychedelics],
            level: .caution,
            warning: String(localized: "A benzodiazepine will flatten a difficult trip, which is why people carry one. It is still sedation on board, so it counts towards the total if anything else depressant follows, and it will blur what you remember of the night.", bundle: .main)
        ),

        // Benzodiazepines with the blood-pressure group. Not on TripSit's chart —
        // it covers none of these three — so the rating rests on low blood
        // pressure being a listed effect of diazepam in NHS medicines guidance,
        // on top of what poppers and sildenafil already do.
        SubstanceInteraction(
            substances: [.benzodiazepines, .poppers],
            level: .caution,
            warning: String(localized: "Benzodiazepines can lower blood pressure and poppers drop it sharply on top of that. The result is a head rush that turns into fainting, and a benzo makes you slower to notice it coming. Sit down before you use poppers.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .viagra],
            level: .caution,
            warning: String(localized: "Both can lower blood pressure, so expect dizziness and stand up slowly. The benzo also makes it harder to tell lightheadedness from the sedation itself.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .kamagra],
            level: .caution,
            warning: String(localized: "Both can lower blood pressure, and Kamagra is often sold at an unverified strength. Stand up slowly, and remember the benzo will blunt your sense of how faint you actually feel.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .ketamine],
            level: .caution,
            warning: String(localized: "Both make you unsteady and sedated, and together that can tip into losing consciousness at higher doses than you expect. Stay seated, stay with someone, and remember that vomiting while out of it is the danger.", bundle: .main)
        ),

        // MARK: Methamphetamine
        //
        // New in 5.0.0 with the substance. TripSit files methamphetamine under
        // "amphetamines", and that row covers nine of these thirteen pairs; those
        // nine take the chart's rating and follow its stated mechanism.
        //
        // The four it does not cover are marked in the table as not on the chart,
        // and each is rated by the same reasoning as an existing row: 3-MMC as a
        // second long stimulant, and poppers and the two sildenafil products as
        // the blood-pressure group.
        SubstanceInteraction(
            substances: [.methamphetamine, .alcohol],
            level: .serious,
            warning: String(localized: "Meth strips out the sedation you use to judge how drunk you are, so drinking runs well past where you would normally stop, including past the point you would usually pass out. Dehydration and liver strain both climb. Set an hourly limit before you start, because you will not feel either one arrive.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.methamphetamine, .ghb],
            level: .serious,
            warning: String(localized: "A stimulant lifts your breathing rate, which lets a larger GHB dose sit on board without feeling like one. When the meth fades first, and it can even after hours, the full GHB arrives at once and breathing is what it takes. Never redose GHB to match how alert you still feel.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.methamphetamine, .gbl],
            level: .serious,
            warning: String(localized: "GBL becomes GHB in the body, and meth masks how much sedation is waiting. If the stimulant wears off first, the whole dose lands together and can stop someone breathing. Keep the timing on paper, not in your head.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.methamphetamine, .benzodiazepines],
            level: .caution,
            warning: String(localized: "Each dulls the other, which is exactly the problem: if one wears off before the other, whatever is left arrives with nothing holding it back. Taking a benzo to come down works, but it is still a depressant on top of a heart that has been running hard.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.methamphetamine, .cocaine],
            level: .serious,
            warning: String(localized: "Two stimulants, one heart. The strain adds up and cocaine partly blocks what meth does, so people take more of both chasing an effect that will not come. Chest pain that does not pass needs help, not another line.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.methamphetamine, .threeMMC],
            level: .serious,
            warning: String(localized: "Both are long stimulants and together they keep a session going far past the point your heart, your temperature and your sleep can carry it. Neither lets you feel the other stacking up.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.methamphetamine, .mdma],
            level: .serious,
            warning: String(localized: "Both strain the heart and both raise your temperature, and meth deepens the damage MDMA does. Overheating is the sharp risk and thought loops are the common one. Keep cool, keep drinking water at a sensible rate, and stop if your chest feels tight.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.methamphetamine, .ketamine],
            level: .caution,
            warning: String(localized: "No surprise between them, but blood pressure goes up and ketamine takes your balance while meth keeps you moving. Injuries happen here that nobody feels at the time. Sit down for the ketamine.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.methamphetamine, .cannabis],
            level: .caution,
            warning: String(localized: "Cannabis does not take the edge off a stimulant. It raises anxiety and feeds thought loops, and on a long meth session that is the direction things already go.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.methamphetamine, .psychedelics],
            level: .caution,
            warning: String(localized: "A stimulant raises anxiety and locks you into thought loops, which is the hardest thing to steer out of in an altered state. Panic is the usual outcome rather than anything physical.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.methamphetamine, .poppers],
            level: .serious,
            warning: String(localized: "Meth tightens blood vessels and pushes blood pressure up; poppers drop it in seconds. Swinging between the two strains the heart and can trigger an irregular beat or a blackout. Sit down first, and get help for chest pain that does not pass.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.methamphetamine, .viagra],
            level: .serious,
            warning: String(localized: "Viagra and meth pull your circulation in opposite directions while both leave the heart working hard, over a session that tends to be a long one. Chest tightness or a heart that will not settle means stop.", bundle: .main)
        ),
        SubstanceInteraction(
            substances: [.methamphetamine, .kamagra],
            level: .serious,
            warning: String(localized: "Kamagra is sildenafil at an unverified strength, and meth already has the heart working hard for hours. The two pull circulation opposite ways. Stop if your chest tightens or your heart will not settle.", bundle: .main)
        ),
    ]}

    /// Warnings for the selected set, most severe first.
    ///
    /// `CombinationAssessment` merges these into the risk checker screen, so an
    /// entry added to the table above reaches users without further wiring. It
    /// drops any of its own preset lines that a row here already covers at an equal
    /// or higher level, which is why the level on each row is load-bearing and not
    /// just a colour.
    ///
    /// The tie-break on `id` matters now that the table carries several entries at
    /// the same level: `sorted(by:)` is not guaranteed stable, so without it two
    /// equally-severe warnings could swap places between evaluations and make
    /// SwiftUI re-identify the rows.
    public static func warnings(for selected: Set<Substance>) -> [SubstanceInteraction] {
        interactions
            .filter { $0.substances.isSubset(of: selected) }
            .sorted { first, second in
                first.level == second.level ? first.id < second.id : first.level > second.level
            }
    }
}
