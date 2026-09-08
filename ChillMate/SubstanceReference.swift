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
/// Sources, all fetched 8 September 2026:
/// - PsychonautWiki substance summaries (dose and duration for the eight
///   substances that have them)
/// - NHS medicines guidance (sildenafil)
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

    /// Phase timings in minutes.
    struct Timing: Sendable {
        let onset: ClosedRange<Double>
        let peak: ClosedRange<Double>
        let total: ClosedRange<Double>
    }

    let doses: [Doses]
    let timing: Timing?
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
                timing: .init(onset: 2...5, peak: 30...90, total: 90...300),
                source: .psychonautWiki,
                noDoseReason: nil,
                redoseGuidance: nil
            )

        case .cannabis:
            SubstanceReference(
                doses: [
                    .init(route: .smoked, unit: .milligrams,
                          light: 0.4...2, common: 2...4, strong: 4...10, heavyFrom: 10),
                    .init(route: .oral, unit: .milligrams,
                          light: 2.5...5, common: 5...10, strong: 10...25, heavyFrom: 25)
                ],
                timing: .init(onset: 0.1...10, peak: 15...45, total: 150...300),
                source: .psychonautWiki,
                noDoseReason: nil,
                redoseGuidance: nil
            )

        case .mdma:
            SubstanceReference(
                doses: [.init(route: .oral, unit: .milligrams,
                              light: 20...80, common: 80...120, strong: 120...150, heavyFrom: 150)],
                timing: .init(onset: 30...45, peak: 90...150, total: 180...360),
                source: .psychonautWiki,
                noDoseReason: nil,
                redoseGuidance: String(localized: "Give it 60 to 90 minutes before deciding anything. Eating beforehand delays the onset, which is what makes people take more too early.")
            )

        case .threeMMC:
            SubstanceReference(
                doses: [
                    .init(route: .insufflated, unit: .milligrams,
                          light: 10...20, common: 20...40, strong: 40...60, heavyFrom: 120),
                    .init(route: .oral, unit: .milligrams,
                          light: 25...50, common: 50...150, strong: 150...250, heavyFrom: 350)
                ],
                timing: .init(onset: 5...10, peak: 60...90, total: 150...270),
                source: .psychonautWiki,
                noDoseReason: nil,
                redoseGuidance: nil
            )

        case .ketamine:
            SubstanceReference(
                doses: [
                    .init(route: .insufflated, unit: .milligrams,
                          light: 5...10, common: 10...30, strong: 30...75, heavyFrom: 150),
                    .init(route: .oral, unit: .milligrams,
                          light: 50...100, common: 100...300, strong: 300...450, heavyFrom: 450)
                ],
                timing: .init(onset: 1...3, peak: 15...45, total: 60...120),
                source: .psychonautWiki,
                noDoseReason: nil,
                redoseGuidance: nil
            )

        case .ghb:
            SubstanceReference(
                doses: [.init(route: .oral, unit: .grams,
                              light: 0.5...1, common: 1...2.5, strong: 2.5...4, heavyFrom: 4)],
                timing: .init(onset: 5...30, peak: 45...90, total: 90...150),
                source: .drugsAndMe,
                noDoseReason: nil,
                redoseGuidance: String(localized: "Wait at least 90 minutes before a second dose, and longer if you rarely use it. Redosing before the first dose has fully arrived is the most common way people go under.")
            )

        case .gbl:
            SubstanceReference(
                doses: [.init(route: .oral, unit: .millilitres,
                              light: 0.3...0.9, common: 0.9...1.5, strong: 1.5...3, heavyFrom: 3)],
                timing: .init(onset: 3...10, peak: 30...45, total: 60...120),
                source: .drugsAndMe,
                noDoseReason: nil,
                redoseGuidance: String(localized: "Wait at least 90 minutes before a second dose, and longer if you rarely use it. Redosing before the first dose has fully arrived is the most common way people go under.")
            )

        case .cocaine:
            SubstanceReference(
                doses: [.init(route: .insufflated, unit: .milligrams,
                              light: 10...30, common: 30...60, strong: 60...90, heavyFrom: 90)],
                timing: .init(onset: 3...10, peak: 7.5...16, total: 10...90),
                source: .psychonautWiki,
                noDoseReason: nil,
                redoseGuidance: nil
            )

        case .poppers:
            SubstanceReference(
                doses: [],
                timing: .init(onset: 0.1...0.5, peak: 0.5...2, total: 2...5),
                source: .psychonautWiki,
                noDoseReason: String(localized: "Poppers are inhaled from the bottle, so there is no measured dose. Effects arrive within seconds and fade within minutes."),
                redoseGuidance: nil
            )

        case .viagra, .kamagra:
            SubstanceReference(
                doses: [.init(route: .oral, unit: .milligrams,
                              light: 25...25, common: 50...50, strong: 100...100, heavyFrom: 100)],
                timing: .init(onset: 30...60, peak: 60...120, total: 240...360),
                source: .nhs,
                noDoseReason: nil,
                redoseGuidance: nil
            )

        case .psychedelics:
            SubstanceReference(
                doses: [],
                timing: nil,
                source: .psychonautWiki,
                noDoseReason: String(localized: "Psychedelics covers substances with completely different scales, from micrograms to grams. Look up the specific one rather than trusting a shared figure."),
                redoseGuidance: nil
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
}
