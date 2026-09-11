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
    enum Corroboration: Sendable {
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

    var corroboration: Corroboration {
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
    var label: String {
        switch self {
        case .matchesChart:
            String(localized: "Matches TripSit’s combination chart")
        case .matchesChartApproximately:
            String(localized: "Matches TripSit’s chart for a closely related substance")
        case .ratedAboveChart:
            String(localized: "Rated higher here than on TripSit’s chart")
        case .notOnChart:
            String(localized: "Not on TripSit’s chart")
        }
    }

    var symbol: String {
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
        // Raised from serious to critical in 5.0.0. TripSit's chart rates all
        // three of these as dangerous, and the reason it gives is specific:
        // both substances cause ataxia and vomiting, and someone who goes under
        // while unable to sit up is at severe risk of aspirating. ChillMate was
        // rating them one step lower, which is the one direction that is never
        // defensible. `InteractionChartTests` now refuses it.
        SubstanceInteraction(
            substances: [.ghb, .ketamine],
            level: .critical,
            warning: String(localized: "GHB and ketamine both take your balance and both bring on vomiting, and together they can put you under. Someone who is sick while too out of it to sit up can choke. If you use both, stay with someone who is not using, and put anyone unresponsive on their side.")
        ),
        SubstanceInteraction(
            substances: [.gbl, .ketamine],
            level: .critical,
            warning: String(localized: "GBL becomes GHB in the body, and with ketamine both your balance and your ability to notice trouble go. Vomiting while unable to sit up is how this combination kills. Stay with someone sober and put anyone unresponsive on their side.")
        ),
        SubstanceInteraction(
            substances: [.alcohol, .ketamine],
            level: .critical,
            warning: String(localized: "Alcohol and ketamine together bring a very high risk of vomiting and of going under. Being sick while too out of it to sit up is the danger, not the disorientation. Keep someone sober nearby and put anyone who cannot be woken on their side.")
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
            level: .critical,
            warning: String(localized: "Both push serotonin hard, and together they carry a real risk of serotonin syndrome: a climbing temperature, a racing heart, stiff or twitching muscles, confusion. A stimulant also deepens the damage MDMA does. Overheating and a rigid, agitated state need emergency help, not water and a sit-down.")
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

        // MARK: Erectile medication doubled up
        //
        // Selecting both used to produce no warning at all, which reads as approval
        // for what is really one dose taken twice.
        SubstanceInteraction(
            substances: [.viagra, .kamagra],
            level: .serious,
            warning: String(localized: "Kamagra is sildenafil, the same active ingredient as Viagra. Taking both stacks one dose on top of another and raises the risk of a blood pressure drop, headache, vision changes, and an erection that will not go down. An erection lasting more than four hours needs urgent medical care.")
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

        // Filling out the table: the checker previously held 30 of the 66 possible
        // pairs, so "nothing on file" was the answer more often than not. A no-match
        // still never means safe, but it should be rare rather than routine.

        SubstanceInteraction(
            substances: [.alcohol, .poppers],
            level: .serious,
            warning: String(localized: "Alcohol and poppers both widen blood vessels and drop blood pressure. Together that means dizziness, fainting, and a pounding heart, and alcohol makes it harder to notice you are already lightheaded. Sit down before you use poppers.")
        ),
        SubstanceInteraction(
            substances: [.alcohol, .viagra],
            level: .serious,
            warning: String(localized: "Alcohol lowers blood pressure and Viagra lowers it further. Together they cause dizziness, headache, and fainting, and alcohol works against the erection you took Viagra for. Keep the drinking light if you use both.")
        ),
        SubstanceInteraction(
            substances: [.alcohol, .kamagra],
            level: .serious,
            warning: String(localized: "Kamagra is the same drug as Viagra and often sold at an unverified dose. With alcohol it can drop your blood pressure enough to make you faint, especially when you stand up quickly.")
        ),
        SubstanceInteraction(
            substances: [.alcohol, .psychedelics],
            level: .caution,
            warning: String(localized: "Alcohol blunts and muddles a trip rather than smoothing it, and it adds nausea and dehydration. It also makes a difficult headspace harder to steer out of.")
        ),
        SubstanceInteraction(
            substances: [.cannabis, .cocaine],
            level: .serious,
            warning: String(localized: "Cannabis does not calm cocaine down. Together they push heart rate and blood pressure higher than either alone, and the mix raises the chance of panic and chest pain. Stop and rest if your heart is racing.")
        ),
        SubstanceInteraction(
            substances: [.cannabis, .ghb],
            level: .serious,
            warning: String(localized: "Both are sedating, and cannabis suppresses vomiting. That matters here: it can mask the nausea that warns you a GHB dose is too high, and it raises the risk of choking if you fall asleep.")
        ),
        SubstanceInteraction(
            substances: [.cannabis, .gbl],
            level: .serious,
            warning: String(localized: "GBL becomes GHB in the body. Cannabis adds sedation and suppresses the nausea that would normally warn you a dose is too high, so an overshoot can arrive without warning.")
        ),
        SubstanceInteraction(
            substances: [.cannabis, .ketamine],
            level: .serious,
            warning: String(localized: "Both cloud coordination and awareness. Together you are much more likely to fall, lose track of where you are, or vomit while too out of it to sit up. Stay seated and stay with someone.")
        ),
        SubstanceInteraction(
            substances: [.cannabis, .mdma],
            level: .caution,
            warning: String(localized: "Cannabis can stretch and sharpen an MDMA experience in ways people do not expect, including anxiety and paranoia. It also dulls the sense of overheating, so keep drinking water and taking breaks.")
        ),
        SubstanceInteraction(
            substances: [.cannabis, .poppers],
            level: .caution,
            warning: String(localized: "Both lower blood pressure. Expect dizziness and a head rush, particularly if you stand up straight after.")
        ),
        SubstanceInteraction(
            substances: [.cannabis, .psychedelics],
            level: .caution,
            warning: String(localized: "Cannabis can amplify psychedelics unpredictably, turning a manageable trip into an overwhelming one. If you are going to use it at all, leave it until the peak has passed.")
        ),
        SubstanceInteraction(
            substances: [.cannabis, .threeMMC],
            level: .caution,
            warning: String(localized: "Cannabis on top of a stimulant tends to add anxiety and a faster heartbeat rather than taking the edge off, and it blurs how hard the comedown is hitting you.")
        ),
        SubstanceInteraction(
            substances: [.cannabis, .kamagra],
            level: .caution,
            warning: String(localized: "Both can lower blood pressure a little. The usual result is dizziness or a headache rather than anything serious, but stand up slowly.")
        ),
        SubstanceInteraction(
            substances: [.cannabis, .viagra],
            level: .caution,
            warning: String(localized: "Both can lower blood pressure a little. Expect dizziness or a headache, and stand up slowly.")
        ),
        SubstanceInteraction(
            substances: [.cocaine, .ketamine],
            level: .serious,
            warning: String(localized: "Cocaine drives your heart rate and blood pressure up while ketamine leaves you far less able to notice how your body is doing. Both also damage the nose. This combination puts real strain on the heart.")
        ),
        SubstanceInteraction(
            substances: [.cocaine, .poppers],
            level: .serious,
            warning: String(localized: "Cocaine tightens blood vessels and poppers open them suddenly. Swinging between the two strains the heart and can trigger an irregular heartbeat or a blackout. Get help for chest pain that does not pass.")
        ),
        SubstanceInteraction(
            substances: [.ketamine, .poppers],
            level: .serious,
            warning: String(localized: "Poppers drop blood pressure sharply and ketamine already takes your balance and judgement. Fainting and falls are the real risk here. Never use poppers standing up on ketamine.")
        ),
        SubstanceInteraction(
            substances: [.ketamine, .psychedelics],
            level: .serious,
            warning: String(localized: "Together these can detach you from your surroundings completely. People lose track of where they are, panic, or injure themselves without registering it. Only do this somewhere safe with someone sober.")
        ),
        SubstanceInteraction(
            substances: [.ketamine, .threeMMC],
            level: .serious,
            warning: String(localized: "The stimulant hides how sedated you actually are, so it is easy to take more ketamine than you can handle. It also raises heart rate and blood pressure, and heavy ketamine use damages the bladder.")
        ),
        SubstanceInteraction(
            substances: [.ketamine, .kamagra],
            level: .caution,
            warning: String(localized: "Ketamine pushes blood pressure up and Kamagra pushes it down, and ketamine makes it hard to notice feeling faint. Stay seated if you feel your head go light.")
        ),
        SubstanceInteraction(
            substances: [.ketamine, .viagra],
            level: .caution,
            warning: String(localized: "Ketamine raises blood pressure while Viagra lowers it, and ketamine makes it hard to tell how you are doing. Stay seated if you feel lightheaded.")
        ),
        SubstanceInteraction(
            substances: [.mdma, .poppers],
            level: .serious,
            warning: String(localized: "MDMA already raises heart rate, blood pressure, and body temperature. Poppers drop blood pressure suddenly on top of that, which can cause fainting and puts extra strain on the heart. Sit down first, and keep cooling down.")
        ),
        SubstanceInteraction(
            substances: [.mdma, .ghb],
            level: .serious,
            warning: String(localized: "MDMA masks how sedated GHB is making you, which is exactly how people redose past the point of going under. When the MDMA fades the full GHB dose is still there. Do not redose to chase the feeling.")
        ),
        SubstanceInteraction(
            substances: [.mdma, .gbl],
            level: .serious,
            warning: String(localized: "GBL turns into GHB in the body, and MDMA hides how sedated you are becoming. That combination is how people redose into unconsciousness. Once the MDMA fades the full GBL dose is still working.")
        ),
        SubstanceInteraction(
            substances: [.ghb, .threeMMC],
            level: .serious,
            warning: String(localized: "3MMC masks the sedation GHB is causing, so it is easy to redose past a safe amount. When the stimulant wears off the GHB is still there, and it can arrive all at once.")
        ),
        SubstanceInteraction(
            substances: [.gbl, .threeMMC],
            level: .serious,
            warning: String(localized: "3MMC hides how sedated GBL is making you, which is how doses stack up unnoticed. The sedation lands hard once the stimulant fades.")
        ),
        SubstanceInteraction(
            substances: [.ghb, .psychedelics],
            level: .serious,
            warning: String(localized: "Psychedelics distort time, which makes it very easy to lose track of when you last dosed GHB. GHB has a narrow margin between a normal dose and unconsciousness. Have someone sober keep the timing.")
        ),
        SubstanceInteraction(
            substances: [.gbl, .psychedelics],
            level: .serious,
            warning: String(localized: "Psychedelics distort your sense of time, and GBL has a very narrow margin between a normal dose and going under. Losing track of the last dose is the danger. Have someone sober hold the timing.")
        ),
        SubstanceInteraction(
            substances: [.ghb, .viagra],
            level: .serious,
            warning: String(localized: "Both lower blood pressure, and GHB can take you under with little warning. Fainting during sex, with nobody realising you are unconscious rather than asleep, is the risk.")
        ),
        SubstanceInteraction(
            substances: [.ghb, .kamagra],
            level: .serious,
            warning: String(localized: "Both lower blood pressure, and Kamagra is often an unverified dose. GHB can take you under quickly, and it is easy for others to mistake that for sleep.")
        ),
        SubstanceInteraction(
            substances: [.gbl, .viagra],
            level: .serious,
            warning: String(localized: "Both lower blood pressure and GBL can take you under fast. Losing consciousness during sex can be mistaken for falling asleep, which delays help.")
        ),
        SubstanceInteraction(
            substances: [.gbl, .kamagra],
            level: .serious,
            warning: String(localized: "Both lower blood pressure, and Kamagra is often sold at an unverified strength. GBL can take you under quickly, and that is easily mistaken for sleep.")
        ),
        SubstanceInteraction(
            substances: [.poppers, .threeMMC],
            level: .serious,
            warning: String(localized: "3MMC tightens blood vessels and raises blood pressure while poppers drop it suddenly. Swinging between the two strains the heart and can cause fainting or an irregular heartbeat.")
        ),
        SubstanceInteraction(
            substances: [.poppers, .psychedelics],
            level: .caution,
            warning: String(localized: "The sudden head rush from poppers can be disorienting and frightening in an altered state, and the blood pressure drop still brings a real risk of fainting. Sit down before using them.")
        ),
        SubstanceInteraction(
            substances: [.psychedelics, .viagra],
            level: .caution,
            warning: String(localized: "Viagra raises heart rate and can add to the physical anxiety a trip already brings, making it harder to tell nerves from a real problem.")
        ),
        SubstanceInteraction(
            substances: [.psychedelics, .kamagra],
            level: .caution,
            warning: String(localized: "Kamagra is often an unverified dose, and the racing heart it can cause is easily mistaken for trip anxiety, or the other way round.")
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
            warning: String(localized: "Benzodiazepines and alcohol strengthen each other strongly and unpredictably, and can take someone under very fast. Blacking out is near certain and choking on vomit is the real danger. If someone cannot be woken, put them on their side and call emergency services.")
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .ghb],
            level: .critical,
            warning: String(localized: "Benzodiazepines and GHB strengthen each other strongly and unpredictably, and unconsciousness can arrive with almost no warning. Someone who cannot be woken needs the recovery position and emergency services, not sleep.")
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .gbl],
            level: .critical,
            warning: String(localized: "GBL becomes GHB in the body, and with a benzodiazepine the two strengthen each other unpredictably. People go under fast and are easily mistaken for asleep. Put anyone unresponsive on their side and call emergency services.")
        ),
        // The stimulant pairs. TripSit rates these low risk because the two sides
        // cancel each other's *effects* — which is exactly the mechanism that
        // makes them worth a row here. A stimulant hides how sedated you are, and
        // when it fades the benzo has not gone anywhere. This is the same masking
        // the table already documents for GHB with stimulants.
        SubstanceInteraction(
            substances: [.benzodiazepines, .cocaine],
            level: .caution,
            warning: String(localized: "Each hides the other. Cocaine masks how sedated the benzo is making you, so it is easy to take more of both, and when the cocaine fades the full benzo dose is still there. Neither cancels the other out — they just make each other harder to judge.")
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .threeMMC],
            level: .caution,
            warning: String(localized: "3-MMC masks the sedation, so you feel more in control than you are, and the benzo is still working long after the stimulant has gone. That gap is where people redose on both without meaning to.")
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .mdma],
            level: .caution,
            warning: String(localized: "The benzo blunts the MDMA and MDMA hides the sedation, which mostly means you can misjudge both. Taking a benzo to sleep afterwards is common; taking one during is how people lose the thread of what they have had.")
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .cannabis],
            level: .caution,
            warning: String(localized: "Both sedate, and together that is heavier than either alone: more drowsiness, worse coordination, bigger gaps in memory. Not usually dangerous on its own, but it stacks badly with anything else that slows breathing.")
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .psychedelics],
            level: .caution,
            warning: String(localized: "A benzodiazepine will flatten a difficult trip, which is why people carry one. It is still sedation on board, so it counts towards the total if anything else depressant follows, and it will blur what you remember of the night.")
        ),

        // Benzodiazepines with the blood-pressure group. Not on TripSit's chart —
        // it covers none of these three — so the rating rests on low blood
        // pressure being a listed effect of diazepam in NHS medicines guidance,
        // on top of what poppers and sildenafil already do.
        SubstanceInteraction(
            substances: [.benzodiazepines, .poppers],
            level: .caution,
            warning: String(localized: "Benzodiazepines can lower blood pressure and poppers drop it sharply on top of that. The result is a head rush that turns into fainting, and a benzo makes you slower to notice it coming. Sit down before you use poppers.")
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .viagra],
            level: .caution,
            warning: String(localized: "Both can lower blood pressure, so expect dizziness and stand up slowly. The benzo also makes it harder to tell lightheadedness from the sedation itself.")
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .kamagra],
            level: .caution,
            warning: String(localized: "Both can lower blood pressure, and Kamagra is often sold at an unverified strength. Stand up slowly, and remember the benzo will blunt your sense of how faint you actually feel.")
        ),
        SubstanceInteraction(
            substances: [.benzodiazepines, .ketamine],
            level: .caution,
            warning: String(localized: "Both make you unsteady and sedated, and together that can tip into losing consciousness at higher doses than you expect. Stay seated, stay with someone, and remember that vomiting while out of it is the danger.")
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
