import Foundation

/// Commonly reported dose ranges and durations, carrying the source they came
/// from.
///
/// **This is reference material, not advice, and the app must never present it as
/// a recommendation.** Every figure here was transcribed from a named public
/// harm-reduction reference and is shown on screen with that attribution, so a
/// reader can check it rather than trust it. Nothing is computed for the
/// individual: there is no personalised dose anywhere in ChillMate and there
/// should not be, because the two variables that decide whether a dose is
/// dangerous — what the substance actually is, and what it is cut with — are
/// exactly the two this app cannot see.
///
/// Ranges are stored as numbers and formatted through `Measurement`, so units and
/// separators follow the reader's locale for free and none of this needs a
/// translation.
///
/// Sources:
/// - PsychonautWiki substance summaries, fetched 8 and 11 September 2026 (dose
///   and duration for the eight substances that have them, and every
///   after-effects window in this file)
/// - Drugs and Me, fetched 8 September 2026 (the GHB and GBL ladders)
/// - NHS medicines guidance, fetched 11 September 2026 (sildenafil)
/// - WHO opioid overdose fact sheet (the overdose triad)
struct SubstanceReference: Sendable {

    /// Where a figure came from. Shown next to the figures it justifies.
    struct Source: Sendable {
        let name: String
        let url: URL?
    }

    enum Unit: Sendable {
        case milligrams
        case grams
        case millilitres
    }

    /// One route's dose ladder. `heavy` is the point at which reported harm rises
    /// sharply — it is displayed as a warning, never as another option.
    struct Doses: Sendable {
        let route: Route
        let unit: Unit
        let light: ClosedRange<Double>
        let common: ClosedRange<Double>
        let strong: ClosedRange<Double>
        /// Doses at or above this are reported as heavy.
        let heavyFrom: Double
    }

    enum Route: Sendable {
        case oral
        case insufflated
        case smoked
        case inhaled

        var label: String {
            switch self {
            case .oral: String(localized: "Swallowed")
            case .insufflated: String(localized: "Snorted")
            case .smoked: String(localized: "Smoked")
            case .inhaled: String(localized: "Inhaled")
            }
        }
    }

    /// Phase timings in minutes, for one route.
    ///
    /// Carrying the route is not decoration. Smoked cannabis comes up inside ten
    /// minutes and is done in a few hours; swallowed cannabis takes twenty to
    /// sixty minutes and runs four to ten. This app stored the smoked figures and
    /// showed them next to an oral dose row, so anyone reading about an edible was
    /// told it arrives in under ten minutes — which is exactly the belief that
    /// makes people take a second one.
    struct Timing: Sendable {
        /// Nil where the substance has one meaningful route, or where the
        /// published figures do not separate them.
        let route: Route?
        let onset: ClosedRange<Double>
        let peak: ClosedRange<Double>
        let total: ClosedRange<Double>

        /// How long the source reports effects lingering *after* the total
        /// duration ends, in minutes from the end of `total`.
        ///
        /// This is the half of the curve the app never showed. A night is planned
        /// around `total` — six hours, home by four — and then the next day is a
        /// write-off for reasons nobody connected to the dose, because the figure
        /// that would have connected them was on a wiki and not in the app.
        ///
        /// Nil means the source publishes no window, which is not the same as
        /// there being none. The screen says which of the two it is.
        let afterEffects: ClosedRange<Double>?
    }

    let doses: [Doses]
    let timings: [Timing]
    let source: Source

    /// A note explaining why a substance carries no dose ladder, when it does not.
    let noDoseReason: String?

    /// What is published about waiting before a second dose, where anything is.
    ///
    /// Nil is a deliberate answer, not an omission. Redosing guidance is well
    /// documented for GHB and MDMA and thin for the rest, and CLAUDE.md's rule is
    /// that new safety claims need a source. A confident sentence about cocaine
    /// redosing would be this app inventing one.
    let redoseGuidance: String?

    /// What the source says about the period after the effects end, where it says
    /// something a duration cannot carry.
    ///
    /// Same rule as `redoseGuidance`: nil unless a named source states it.
    let comedownNote: String?

    /// Where the after-effects figures came from, when that is not where the
    /// doses came from.
    ///
    /// GHB's and GBL's ladders are Drugs and Me's and their after-effects windows
    /// are PsychonautWiki's. Leaving this nil would print the wrong name under a
    /// figure, which is worse than printing none: the whole point of attribution
    /// is that a reader can go and check, and they would check the wrong page.
    let afterEffectsSource: Source?
}

extension SubstanceReference.Source {

    static let psychonautWiki = Self(
        name: "PsychonautWiki",
        url: URL(string: "https://psychonautwiki.org")
    )

    static let drugsAndMe = Self(
        name: "Drugs and Me",
        url: URL(string: "https://www.drugsand.me")
    )

    static let nhs = Self(
        name: "NHS",
        url: URL(string: "https://www.nhs.uk/medicines/sildenafil-viagra/")
    )
}

extension Substance {

    /// Sourced dose and duration reference, where one exists for this substance.
    ///
    /// Nil for `unknown` and `other` by definition, and for `psychedelics` because
    /// it is a category rather than a substance: LSD and psilocybin do not share a
    /// scale, and a single range across them would be worse than none.
    var reference: SubstanceReference? {
        switch self {

        case .alcohol:
            SubstanceReference(
                doses: [.init(route: .oral, unit: .grams,
                              light: 10...20, common: 20...30, strong: 30...40, heavyFrom: 40)],
                timings: [.init(route: nil, onset: 2...5, peak: 30...90, total: 90...300,
                                afterEffects: 360...2880)],
                source: .psychonautWiki,
                noDoseReason: nil,
                redoseGuidance: nil,
                comedownNote: nil,
                afterEffectsSource: nil
            )

        case .cannabis:
            SubstanceReference(
                doses: [
                    .init(route: .smoked, unit: .milligrams,
                          light: 0.4...2, common: 2...4, strong: 4...10, heavyFrom: 10),
                    .init(route: .oral, unit: .milligrams,
                          light: 2.5...5, common: 5...10, strong: 10...25, heavyFrom: 25)
                ],
                timings: [
                    .init(route: .smoked, onset: 0.1...10, peak: 15...45, total: 150...300,
                          afterEffects: 45...180),
                    // Added 11 September 2026. These were missing, and the smoked
                    // figures were shown beside an oral dose row — telling anyone
                    // reading about an edible that it arrives in under ten minutes.
                    .init(route: .oral, onset: 20...60, peak: 60...150, total: 240...600,
                          afterEffects: 360...720)
                ],
                source: .psychonautWiki,
                noDoseReason: nil,
                redoseGuidance: String(localized: "Smoked, you know inside ten minutes. Swallowed, it can take a full hour — so an edible that seems not to be working usually is, and a second one lands on top of the first for the next several hours."),
                comedownNote: nil,
                afterEffectsSource: nil
            )

        case .mdma:
            SubstanceReference(
                doses: [.init(route: .oral, unit: .milligrams,
                              light: 20...80, common: 80...120, strong: 120...150, heavyFrom: 150)],
                timings: [.init(route: nil, onset: 30...45, peak: 90...150, total: 180...360,
                                afterEffects: 720...2880)],
                source: .psychonautWiki,
                noDoseReason: nil,
                redoseGuidance: String(localized: "Give it 60 to 90 minutes before deciding anything. Eating beforehand delays the onset, which is what makes people take more too early."),
                // PsychonautWiki records the low after MDMA as tending to skip a
                // day. That single fact is why people do not connect the two: the
                // day after is fine, so the day that is not fine gets put down to
                // sleep, or work, or nothing in particular.
                comedownNote: String(localized: "The low tends to skip a day. PsychonautWiki reports the day after often feeling fine — sometimes better than fine — with the dip landing the day after that, which is why people do not link it to the night. If you know it is coming you can put something gentle in that day rather than something demanding."),
                afterEffectsSource: nil
            )

        case .threeMMC:
            SubstanceReference(
                doses: [
                    .init(route: .insufflated, unit: .milligrams,
                          light: 10...20, common: 20...40, strong: 40...60, heavyFrom: 120),
                    .init(route: .oral, unit: .milligrams,
                          light: 25...50, common: 50...150, strong: 150...250, heavyFrom: 350)
                ],
                timings: [
                    .init(route: .insufflated, onset: 5...10, peak: 60...90, total: 150...270,
                          afterEffects: 60...90),
                    .init(route: .oral, onset: 10...30, peak: 120...180, total: 240...360,
                          afterEffects: 120...240)
                ],
                source: .psychonautWiki,
                noDoseReason: nil,
                redoseGuidance: nil,
                comedownNote: nil,
                afterEffectsSource: nil
            )

        case .ketamine:
            SubstanceReference(
                doses: [
                    .init(route: .insufflated, unit: .milligrams,
                          light: 5...10, common: 10...30, strong: 30...75, heavyFrom: 150),
                    .init(route: .oral, unit: .milligrams,
                          light: 50...100, common: 100...300, strong: 300...450, heavyFrom: 450)
                ],
                timings: [
                    .init(route: .insufflated, onset: 1...3, peak: 15...45, total: 60...120,
                          afterEffects: 120...720),
                    .init(route: .oral, onset: 10...30, peak: 45...90, total: 60...140,
                          afterEffects: 240...480)
                ],
                source: .psychonautWiki,
                noDoseReason: nil,
                redoseGuidance: nil,
                comedownNote: nil,
                afterEffectsSource: nil
            )

        case .ghb:
            SubstanceReference(
                doses: [.init(route: .oral, unit: .grams,
                              light: 0.5...1, common: 1...2.5, strong: 2.5...4, heavyFrom: 4)],
                timings: [.init(route: nil, onset: 5...30, peak: 45...90, total: 90...150,
                                afterEffects: 120...240)],
                source: .drugsAndMe,
                noDoseReason: nil,
                redoseGuidance: String(localized: "Wait at least 90 minutes before a second dose, and longer if you rarely use it. Redosing before the first dose has fully arrived is the most common way people go under."),
                comedownNote: nil,
                afterEffectsSource: .psychonautWiki
            )

        case .gbl:
            SubstanceReference(
                doses: [.init(route: .oral, unit: .millilitres,
                              light: 0.3...0.9, common: 0.9...1.5, strong: 1.5...3, heavyFrom: 3)],
                timings: [.init(route: nil, onset: 3...10, peak: 30...45, total: 60...120,
                                afterEffects: 60...180)],
                source: .drugsAndMe,
                noDoseReason: nil,
                redoseGuidance: String(localized: "Wait at least 90 minutes before a second dose, and longer if you rarely use it. Redosing before the first dose has fully arrived is the most common way people go under."),
                comedownNote: nil,
                afterEffectsSource: .psychonautWiki
            )

        case .cocaine:
            SubstanceReference(
                doses: [.init(route: .insufflated, unit: .milligrams,
                              light: 10...30, common: 30...60, strong: 60...90, heavyFrom: 90)],
                // PsychonautWiki's after-effects cell for cocaine holds words, not
                // hours: "psychological craving and compulsive redosing". There is
                // no window to draw, so none is drawn, and `comedownNote` carries
                // what the source does say instead.
                timings: [.init(route: nil, onset: 3...10, peak: 7.5...16, total: 10...90,
                                afterEffects: nil)],
                source: .psychonautWiki,
                noDoseReason: nil,
                // No published interval exists, and inventing one would be worse
                // than saying so. What *is* published is the behaviour: PsychonautWiki
                // records compulsive redosing as more prevalent with cocaine than
                // with any other common stimulant, and cravings arriving almost
                // immediately on the comedown. Paired with a total duration as short
                // as ten minutes, that is the whole problem in two facts.
                redoseGuidance: String(localized: "There is no published safe interval for this one. What is published is that it drives redosing harder than any other common stimulant, and that the craving arrives almost as soon as you come down — while the last dose has barely finished. Decide the number of lines before you start, not during."),
                comedownNote: String(localized: "PsychonautWiki publishes no after-effects window for cocaine. What it names in that place instead is craving and compulsive redosing, arriving as the effects fade. So there is no hour to wait out here — the comedown is the part where the decision gets made again."),
                afterEffectsSource: nil
            )

        case .poppers:
            SubstanceReference(
                doses: [],
                timings: [.init(route: nil, onset: 0.1...0.5, peak: 0.5...2, total: 2...5,
                                afterEffects: nil)],
                source: .psychonautWiki,
                noDoseReason: String(localized: "Poppers are inhaled from the bottle, so there is no measured dose. Effects arrive within seconds and fade within minutes."),
                redoseGuidance: nil,
                comedownNote: nil,
                afterEffectsSource: nil
            )

        case .viagra, .kamagra:
            SubstanceReference(
                doses: [.init(route: .oral, unit: .milligrams,
                              light: 25...25, common: 50...50, strong: 100...100, heavyFrom: 100)],
                timings: [.init(route: nil, onset: 30...60, peak: 60...120, total: 240...360,
                                afterEffects: nil)],
                source: .nhs,
                noDoseReason: nil,
                // NHS medicines guidance on sildenafil, fetched 11 September 2026:
                // "Do not take more than 1 tablet a day as the effects can last up
                // to 36 hours." This is the hardest redose rule in the whole file
                // and the one most often broken — a second pill gets taken when the
                // first seems not to have worked, while the first is still active.
                redoseGuidance: String(localized: "One tablet in twenty-four hours, and no more. The effects can last up to thirty-six hours, so a second one taken because the first seemed not to work stacks on a dose that is still going."),
                comedownNote: nil,
                afterEffectsSource: nil
            )

        case .psychedelics:
            SubstanceReference(
                doses: [],
                timings: [],
                source: .psychonautWiki,
                noDoseReason: String(localized: "Psychedelics covers substances with completely different scales, from micrograms to grams. Look up the specific one rather than trusting a shared figure."),
                redoseGuidance: nil,
                comedownNote: nil,
                afterEffectsSource: nil
            )

        // PsychonautWiki, fetched 11 September 2026. Both routes are listed
        // because they behave differently enough to matter: snorted comes up in
        // minutes and is done in four to seven hours, swallowed takes up to
        // three-quarters of an hour to arrive and runs eight to twelve. The timing
        // below spans both, and the total takes the oral figure, because the
        // failure mode is believing it has finished when it has not.
        case .methamphetamine:
            SubstanceReference(
                doses: [
                    .init(route: .insufflated, unit: .milligrams,
                          light: 5...10, common: 10...30, strong: 30...60, heavyFrom: 60),
                    .init(route: .oral, unit: .milligrams,
                          light: 5...10, common: 10...25, strong: 25...50, heavyFrom: 50)
                ],
                timings: [
                    .init(route: .insufflated, onset: 3...5, peak: 90...180, total: 240...420,
                          afterEffects: 360...1440),
                    .init(route: .oral, onset: 15...45, peak: 180...300, total: 480...720,
                          afterEffects: 720...1440)
                ],
                source: .psychonautWiki,
                noDoseReason: nil,
                redoseGuidance: String(localized: "It keeps working long after it stops feeling like it is. The published total runs to twelve hours, so a redose late in a session lands on top of a dose that has not finished."),
                comedownNote: nil,
                afterEffectsSource: nil
            )

        // No dose ladder, for the same reason as psychedelics and more sharply:
        // a common dose of alprazolam is 0.25 mg and a common dose of diazepam is
        // 5 to 10 mg, so any single figure across the class would be wrong by a
        // factor of twenty for somebody. The timing is left out too — half-lives
        // here run from a couple of hours to more than a day.
        case .benzodiazepines:
            SubstanceReference(
                doses: [],
                timings: [],
                source: .nhs,
                noDoseReason: String(localized: "Benzodiazepines covers drugs whose doses differ by a factor of twenty or more, and whose effects last anywhere from a few hours to well into the next day. Look up the specific one you have, and treat any pill of unknown origin as unknown strength."),
                redoseGuidance: nil,
                comedownNote: nil,
                afterEffectsSource: nil
            )

        case .unknown, .other:
            nil
        }
    }
}

// MARK: - Formatting

extension SubstanceReference.Unit {
    /// A `Measurement` for `value` in this unit, so the reader's locale decides
    /// how it is written.
    func measurement(_ value: Double) -> String {
        switch self {
        case .milligrams:
            Measurement(value: value, unit: UnitMass.milligrams)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided))
        case .grams:
            Measurement(value: value, unit: UnitMass.grams)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided))
        case .millilitres:
            Measurement(value: value, unit: UnitVolume.milliliters)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided))
        }
    }

    /// "80–120 mg": the unit is written once, on the upper bound.
    func range(_ bounds: ClosedRange<Double>) -> String {
        guard bounds.lowerBound != bounds.upperBound else {
            return measurement(bounds.upperBound)
        }
        let lower = bounds.lowerBound.formatted(.number.precision(.fractionLength(0...2)))
        return "\(lower)–\(measurement(bounds.upperBound))"
    }

    func from(_ value: Double) -> String {
        measurement(value)
    }
}

extension SubstanceReference.Timing {
    /// "30–45 min", or "1.5–2.5 h" once a bound passes an hour.
    static func describe(_ bounds: ClosedRange<Double>) -> String {
        if bounds.upperBound >= 60 {
            let lower = (bounds.lowerBound / 60).formatted(.number.precision(.fractionLength(0...1)))
            let upper = Measurement(value: bounds.upperBound / 60, unit: UnitDuration.hours)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided))
            return bounds.lowerBound == bounds.upperBound ? upper : "\(lower)–\(upper)"
        }
        let lower = bounds.lowerBound.formatted(.number.precision(.fractionLength(0...1)))
        let upper = Measurement(value: bounds.upperBound, unit: UnitDuration.minutes)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided))
        return bounds.lowerBound == bounds.upperBound ? upper : "\(lower)–\(upper)"
    }

    var onsetText: String { Self.describe(onset) }
    var peakText: String { Self.describe(peak) }
    var totalText: String { Self.describe(total) }

    /// The after-effects window, or nil where the source publishes none.
    var afterEffectsText: String? { afterEffects.map(Self.describe) }

    /// How long after the dose the after-effects window can still be running, in
    /// minutes: the end of the longest total plus the end of the longest
    /// after-effects window. Nil where nothing is published.
    var afterEffectsEndFromDose: Double? {
        afterEffects.map { total.upperBound + $0.upperBound }
    }

    /// When the after-effects window can first begin, in minutes from the dose:
    /// the earliest the effects themselves can be over.
    var afterEffectsStartFromDose: Double? {
        afterEffects.map { _ in total.lowerBound }
    }
}
