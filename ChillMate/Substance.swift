import SwiftUI

// Sendable has to be declared here rather than alongside the AppEnum
// conformance in AppIntents.swift: Swift requires it in the defining file.
enum Substance: String, CaseIterable, Identifiable, Sendable {
    case cannabis = "Cannabis"
    case alcohol = "Alcohol"
    case mdma = "MDMA"
    case threeMMC = "3MMC"
    case ketamine = "Ketamine"
    case ghb = "GHB"
    case gbl = "GBL"
    case cocaine = "Cocaine"
    case poppers = "Poppers"
    case kamagra = "Kamagra"
    case viagra = "Viagra"
    case psychedelics = "Psychedelics"
    // Added in 5.0.0. Until then the app could not represent a benzodiazepine at
    // all, so someone logging GHB and a benzo together — which TripSit's chart
    // rates as dangerous, and which is a common way to come down — got no warning
    // of any kind. A new case is additive for SwiftData, which stores these as
    // raw strings.
    case benzodiazepines = "Benzodiazepines"
    // Also added in 5.0.0. Methamphetamine is central to the settings this app
    // is used in and could not be logged or checked at all — someone had to pick
    // "Other", which produces no interaction row and no timing.
    case methamphetamine = "Meth"
    case unknown = "Unknown"
    case other = "Other"

    var id: String { rawValue }

    /// The key this substance is filed under in `InteractionChart`.
    ///
    /// Deliberately not `rawValue`: the raw values are display names that have
    /// changed before ("3MMC" was once "3-MMC"), and a rename there must not
    /// silently detach a row from the source that corroborates it.
    var chartKey: String {
        switch self {
        case .cannabis: "cannabis"
        case .alcohol: "alcohol"
        case .mdma: "mdma"
        case .threeMMC: "threeMMC"
        case .ketamine: "ketamine"
        case .ghb: "ghb"
        case .gbl: "gbl"
        case .cocaine: "cocaine"
        case .poppers: "poppers"
        case .kamagra: "kamagra"
        case .viagra: "viagra"
        case .psychedelics: "psychedelics"
        case .benzodiazepines: "benzodiazepines"
        case .methamphetamine: "methamphetamine"
        case .unknown: "unknown"
        case .other: "other"
        }
    }

    var symbolName: String {
        switch self {
        case .cannabis:
            "leaf.fill"
        case .alcohol:
            "wineglass.fill"
        case .mdma:
            "sparkles"
        case .threeMMC:
            "bolt.heart.fill"
        case .ketamine:
            "moon.fill"
        case .ghb:
            "drop.triangle.fill"
        case .gbl:
            "testtube.2"
        case .cocaine:
            "bolt.fill"
        case .poppers:
            "drop.fill"
        case .kamagra, .viagra:
            "cross.vial.fill"
        case .psychedelics:
            "circle.hexagongrid.fill"
        case .benzodiazepines:
            "pills.fill"
        case .methamphetamine:
            "flame.fill"
        case .unknown:
            "questionmark.circle.fill"
        case .other:
            "plus.circle.fill"
        }
    }

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

    var effectWindow: ClosedRange<Double> {
        switch self {
        case .cannabis:
            2...6
        case .alcohol:
            1...6
        case .mdma:
            3...6
        case .threeMMC:
            2...4
        case .ketamine:
            1...2
        case .ghb, .gbl:
            1.5...3
        case .cocaine:
            0.5...1.5
        case .poppers:
            0.05...0.2
        case .kamagra, .viagra:
            4...6
        case .psychedelics:
            6...12
        // Wider than most entries here on purpose. "Benzodiazepines" is a class,
        // not a substance: midazolam is done in a couple of hours and diazepam is
        // still working the next day. A window that covered only the short-acting
        // ones would tell someone they were clear when they were not.
        case .benzodiazepines:
            4...12
        // PsychonautWiki gives 4 to 7 hours snorted and 8 to 12 swallowed, both
        // running far longer for irregular users. The upper bound follows the oral
        // figure because underestimating how long this is still working is what
        // drives the redosing.
        case .methamphetamine:
            4...12
        case .unknown, .other:
            1...4
        }
    }

    var defaultTimerHours: Double {
        (effectWindow.lowerBound + effectWindow.upperBound) / 2
    }

    func adjustedTimerHours(weightKg: Double, heightCm: Double) -> Double {
        let defaultWeight = 75.0
        let defaultHeight = 175.0
        let safeWeight = min(max(weightKg, 35), 180)
        let safeHeight = min(max(heightCm, 130), 220)
        let bodyFactor = ((safeWeight / defaultWeight) * 0.75) + ((safeHeight / defaultHeight) * 0.25)
        let adjusted = defaultTimerHours * min(max(bodyFactor, 0.72), 1.28)
        return min(max(adjusted, effectWindow.lowerBound), effectWindow.upperBound)
    }

    var durationLabel: String {
        let lower = effectWindow.lowerBound.formatted(.number.precision(.fractionLength(0...1)))
        let upper = effectWindow.upperBound.formatted(.number.precision(.fractionLength(0...1)))
        return "\(lower)-\(upper) h"
    }

    var informationSummary: String {
        switch self {
        case .cannabis:
            String(localized: "Can affect memory, coordination, anxiety, and sleep. Effects vary strongly by route and strength.")
        case .alcohol:
            String(localized: "Can lower boundaries and coordination. Mixing with sedatives, GHB/GBL, or other depressants can be dangerous.")
        case .mdma:
            String(localized: "Stimulant/empathogen effects can include warmth, jaw tension, overheating, and a next-day dip.")
        case .threeMMC:
            String(localized: "A stimulant cathinone. Can raise heart rate, reduce sleep, and make it harder to pause.")
        case .ketamine:
            String(localized: "Dissociative effects can affect balance, memory, and consent clarity.")
        case .ghb:
            String(localized: "Effects can become unpredictable quickly. Mixing with alcohol or sedatives can cause unconsciousness or breathing problems.")
        case .gbl:
            String(localized: "Converts to GHB in the body and carries similar risks, especially with alcohol or sedatives.")
        case .cocaine:
            String(localized: "Stimulant effects can strain the heart, reduce sleep, and increase impulsive decisions.")
        case .poppers:
            String(localized: "Short-acting vasodilator. Avoid with erectile dysfunction medication because blood pressure can drop sharply.")
        case .kamagra:
            String(localized: "Often contains sildenafil. Avoid with poppers or nitrates because blood pressure can drop dangerously.")
        case .viagra:
            String(localized: "Sildenafil for erections. Avoid with poppers or nitrates because blood pressure can drop dangerously.")
        case .psychedelics:
            String(localized: "Can strongly change perception and emotions. Setting, support, and mental state matter.")
        case .methamphetamine:
            String(localized: "A long, strong stimulant. Sessions stretch for many hours, sleep and eating stop, and the comedown is heavy. Injecting and sharing equipment carry their own risks, and judgement about sex and consent shifts a long way before you notice it has.")
        case .benzodiazepines:
            String(localized: "Sedatives that differ enormously between compounds: some are gone in a few hours, others are still working the next day. The danger is rarely the benzo on its own — it is stacking it with alcohol, GHB/GBL or another depressant.")
        case .unknown:
            String(localized: "Unknown substances are harder to predict. Avoid mixing and seek help if something feels wrong.")
        case .other:
            String(localized: "Use this only for private reflection when something is not listed.")
        }
    }

    /// The three things most likely to go wrong with this substance.
    ///
    /// Every line was a bare Swift string until 5.0.0, which meant it reached
    /// `Label(_:systemImage:)` as a `String` rather than a `LocalizedStringKey`.
    /// That overload does not localize, so all of this shipped in English to every
    /// Dutch, German, French and Spanish user — on the drug information screen,
    /// where the whole point is knowing what you are dealing with. Nothing caught
    /// it because the CI gate reads `String(localized:)` calls, and there were
    /// none here to read.
    var mainRisks: [String] {
        switch self {
        case .cannabis:
            [String(localized: "Anxiety or paranoia"), String(localized: "Memory and coordination changes"), String(localized: "Stronger effects with edibles or high-potency products")]
        case .alcohol:
            [String(localized: "Lowered inhibition"), String(localized: "Vomiting or injury risk"), String(localized: "Breathing risk when mixed with depressants")]
        case .mdma:
            [String(localized: "Overheating and dehydration"), String(localized: "Jaw tension and high heart rate"), String(localized: "Next-day low mood or sleep disruption")]
        case .threeMMC:
            [String(localized: "Strong urge to continue"), String(localized: "High heart rate and anxiety"), String(localized: "Sleep loss and low mood afterwards")]
        case .ketamine:
            [String(localized: "Dissociation and falls"), String(localized: "Memory gaps"), String(localized: "Consent clarity can be affected")]
        case .ghb, .gbl:
            [String(localized: "Unconsciousness can happen quickly"), String(localized: "Breathing problems when mixed"), String(localized: "Harder to judge safety and consent")]
        case .cocaine:
            [String(localized: "Heart strain"), String(localized: "Anxiety or agitation"), String(localized: "Sleep loss and impulsive decisions")]
        case .poppers:
            [String(localized: "Blood pressure drop"), String(localized: "Dizziness or fainting"), String(localized: "Higher risk with erectile medication")]
        case .kamagra, .viagra:
            [String(localized: "Blood pressure effects"), String(localized: "Headache or dizziness"), String(localized: "Dangerous with poppers or nitrates")]
        case .psychedelics:
            [String(localized: "Strong emotional shifts"), String(localized: "Panic or confusion"), String(localized: "Long duration and setting sensitivity")]
        case .benzodiazepines:
            [String(localized: "Breathing risk when stacked with other depressants"), String(localized: "Memory gaps and blackouts"), String(localized: "Dependence builds fast with regular use")]
        case .methamphetamine:
            [String(localized: "Heart strain and dangerously high temperature"), String(localized: "Days without sleep, then a heavy crash"), String(localized: "Consent and limits get much harder to hold")]
        case .unknown:
            [String(localized: "Unknown strength"), String(localized: "Unknown contents"), String(localized: "Higher risk when mixed")]
        case .other:
            [String(localized: "Unknown risk profile"), String(localized: "Timing and amount may be uncertain"), String(localized: "Avoid mixing unknown substances")]
        }
    }

    var mixingRisks: [String] {
        switch self {
        case .ghb, .gbl:
            [String(localized: "Avoid alcohol, benzodiazepines, opioids, ketamine, and other sedatives.")]
        case .poppers:
            [String(localized: "Avoid Viagra, Kamagra, sildenafil, nitrates, nicorandil, or riociguat.")]
        case .kamagra, .viagra:
            [String(localized: "Avoid poppers and nitrate-like medication because blood pressure can drop sharply.")]
        case .mdma, .threeMMC, .cocaine:
            [String(localized: "Avoid stacking stimulants and be careful with serotonergic medication or MAOIs.")]
        case .alcohol:
            [String(localized: "Avoid GHB/GBL, benzodiazepines, opioids, ketamine, and heavy stimulant use.")]
        case .ketamine:
            [String(localized: "Avoid depressant stacks and settings where falls, water, stairs, or consent confusion are likely.")]
        default:
            [String(localized: "Avoid unknown mixes, pressure to continue, and combining with medication without professional advice.")]
        }
    }

    /// What an emergency looks like for *this* substance.
    ///
    /// This used to ignore `self` entirely and return the same three sentences for
    /// all fourteen, which is the least useful moment to be generic: someone
    /// checking this is looking at a specific person in front of them. The signs
    /// below are the ones that distinguish an emergency from a heavy night, and
    /// they differ enormously — GHB drops someone abruptly minutes after a dose,
    /// poppers turn lips grey through methaemoglobinaemia that fresh air will not
    /// fix, sildenafil's is a four-hour erection.
    ///
    /// Sources: NHS medicines guidance (sildenafil), WHO opioid overdose fact
    /// sheet, and the published case literature on alkyl nitrite
    /// methaemoglobinaemia. Fetched 8 September 2026.
    var seekHelpSigns: [String] {
        switch self {
        case .alcohol:
            [
                String(localized: "Cannot be woken, or is snoring or gurgling"),
                String(localized: "Breathing is slow, shallow, or has stopped"),
                String(localized: "Has been sick while unable to sit up"),
                String(localized: "Skin is cold, clammy, or looks grey")
            ]

        case .ghb, .gbl:
            [
                String(localized: "Went under suddenly, within minutes of a dose"),
                String(localized: "Cannot be woken, or is snoring or gurgling"),
                String(localized: "Breathing is slow, shallow, or has stopped"),
                String(localized: "Woke briefly, was confused or combative, then went under again")
            ]

        case .ketamine:
            [
                String(localized: "Cannot move and is being sick"),
                String(localized: "Breathing is slow, shallow, or has stopped"),
                String(localized: "Cannot be woken, or is snoring or gurgling")
            ]

        case .mdma, .threeMMC:
            [
                String(localized: "Very high temperature, or has stopped sweating"),
                String(localized: "Confusion with shivering, stiff muscles, or fever"),
                String(localized: "Seizure, or severe agitation that will not settle"),
                String(localized: "Drank a lot of water and became confused or had a seizure")
            ]

        case .cocaine:
            [
                String(localized: "Chest pain, or a heartbeat that is racing or irregular"),
                String(localized: "Very high temperature, or has stopped sweating"),
                String(localized: "Seizure, or severe agitation that will not settle"),
                String(localized: "Sudden severe headache, or weakness on one side")
            ]

        case .poppers:
            [
                String(localized: "Lips or fingertips are blue or grey and fresh air does not help"),
                String(localized: "Fainting, or a sudden severe headache"),
                String(localized: "Swallowed rather than inhaled, which can be life-threatening")
            ]

        case .viagra, .kamagra:
            [
                String(localized: "An erection lasting longer than four hours"),
                String(localized: "Chest pain, fainting, or an irregular heartbeat"),
                String(localized: "Sudden loss of vision or hearing")
            ]

        case .cannabis:
            [
                String(localized: "Repeated cycles of severe vomiting"),
                String(localized: "Panic with a racing heart that will not settle"),
                String(localized: "Chest pain, or fainting")
            ]

        case .psychedelics:
            [
                String(localized: "Severe panic that will not settle, or does not know where they are"),
                String(localized: "Seizure, or a dangerously high temperature"),
                String(localized: "At risk of harming themselves or cannot be kept safe")
            ]

        case .methamphetamine:
            [
                String(localized: "Chest pain, a racing heart that will not settle, or collapse"),
                String(localized: "Very hot to the touch, or has stopped sweating"),
                String(localized: "Seizure, or twitching they cannot control"),
                String(localized: "Severe agitation, paranoia, or does not know where they are")
            ]

        // NHS medicines guidance on diazepam names slower, shallower breathing as
        // the serious sign and says to treat an extra dose as an emergency. The
        // rest is the same depressant picture as alcohol and GHB, which is the
        // situation a benzo is almost always in when this app is open.
        case .benzodiazepines:
            [
                String(localized: "Breathing is slow or shallow, or has stopped"),
                String(localized: "Cannot be woken, or only briefly and not properly"),
                String(localized: "Was taken with alcohol, GHB/GBL or another sedative"),
                String(localized: "Lips or fingertips look blue or grey")
            ]

        case .unknown, .other:
            [
                String(localized: "Chest pain, seizure, fainting, or cannot be woken"),
                String(localized: "Blue lips, slow breathing, overheating, or severe confusion"),
                String(localized: "Severe panic, hallucinations, or feeling unsafe with people nearby")
            ]
        }
    }

    var referenceLabel: String {
        switch self {
        case .unknown, .other:
            return String(localized: "No source")
        case .kamagra, .viagra:
            // ED medication: always a sildenafil reference, never a recreational-drug service.
            return String(localized: "Apotheek.nl sildenafil")
        default:
            break
        }
        // Route to the user's national drug-info service outside the Netherlands.
        switch Self.referenceCountry {
        case "United Kingdom":
            return String(localized: "Talk to FRANK")
        case "Germany":
            return String(localized: "drugcom.de")
        case "France":
            return String(localized: "Drogues Info Service")
        case "Spain":
            return String(localized: "Energy Control")
        case "United States":
            return String(localized: "DanceSafe")
        case "Ireland":
            return String(localized: "Drugs.ie")
        case "Australia":
            return String(localized: "Alcohol and Drug Foundation")
        default:
            switch self {
            case .kamagra, .viagra:
                return String(localized: "Apotheek.nl sildenafil")
            default:
                return String(localized: "Drugsinfo.nl")
            }
        }
    }

    private static var referenceCountry: String {
        UserDefaults.standard.string(forKey: DefaultsKey.country) ?? "Netherlands"
    }

    var referenceURL: URL? {
        switch self {
        case .unknown, .other:
            return nil
        case .kamagra, .viagra:
            // ED medication: always a sildenafil reference, never a recreational-drug service.
            return URL(string: "https://www.apotheek.nl/medicijnen/sildenafil")
        default:
            break
        }
        // Non-Dutch regions get their national service's stable landing page (verified
        // live) rather than a Dutch page or a fragile per-drug deep link.
        switch Self.referenceCountry {
        case "United Kingdom":
            return URL(string: "https://www.talktofrank.com/drugs-a-z")
        case "Germany":
            return URL(string: "https://www.drugcom.de/drogenlexikon/")
        case "France":
            return URL(string: "https://www.drogues-info-service.fr/")
        case "Spain":
            return URL(string: "https://energycontrol.org/")
        case "United States":
            return URL(string: "https://dancesafe.org/drug-information/")
        case "Ireland":
            return URL(string: "https://www.drugs.ie/drugtypes/")
        case "Australia":
            return URL(string: "https://adf.org.au/drug-facts/")
        default:
            // Netherlands / Belgium / Other: per-substance Dutch reference.
            switch self {
            case .cannabis:
                return URL(string: "https://www.drugsinfo.nl/cannabis")
            case .alcohol:
                return URL(string: "https://www.drugsinfo.nl/alcohol")
            case .mdma:
                return URL(string: "https://www.drugsinfo.nl/xtc")
            case .threeMMC:
                return URL(string: "https://www.drugsinfo.nl/3-mmc")
            case .ketamine:
                return URL(string: "https://www.drugsinfo.nl/ketamine")
            case .ghb:
                return URL(string: "https://www.drugsinfo.nl/ghb")
            case .gbl:
                return URL(string: "https://www.drugsinfo.nl/gbl")
            case .cocaine:
                return URL(string: "https://www.drugsinfo.nl/cocaine")
            case .poppers:
                return URL(string: "https://www.drugsinfo.nl/poppers")
            case .kamagra, .viagra:
                return URL(string: "https://www.apotheek.nl/medicijnen/sildenafil")
            case .psychedelics:
                return URL(string: "https://www.drugsinfo.nl/lsd")
            case .benzodiazepines:
                return URL(string: "https://www.drugsinfo.nl/benzodiazepines")
            case .methamphetamine:
                return URL(string: "https://www.drugsinfo.nl/crystal-meth")
            case .unknown, .other:
                return nil
            }
        }
    }
}

enum LogMode: String, CaseIterable, Identifiable {
    case tracked = "I used"
    case skipped = "I didn't use"

    var id: String { rawValue }
}
