import Foundation

// Sendable has to be declared here rather than alongside the AppEnum
// conformance in AppIntents.swift: Swift requires it in the defining file.
public enum Substance: String, CaseIterable, Identifiable, Sendable {
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

    public var id: String { rawValue }

    /// What people actually call this, so it can be found by the name they use.
    ///
    /// Nobody types "Methamphetamine" into a search box at two in the morning, and
    /// nobody calls GHB anything but G. These are matched alongside the display
    /// name, lower-cased and accent-insensitively, so the picker finds a substance
    /// from a street name, an abbreviation, or a brand.
    ///
    /// Deliberately not localized. Street names do not translate — a Dutch user
    /// says "ket" and "G" too — and a translated alias list would be a list of
    /// guesses rather than a list of names anyone uses. The display name is
    /// translated and is matched as well, so searching in your own language works
    /// through that.
    public var aliases: [String] {
        switch self {
        case .cannabis: ["weed", "wiet", "hash", "hasj", "blow", "joint", "thc", "marijuana", "green"]
        case .alcohol: ["booze", "drink", "drinks", "beer", "bier", "wine", "wijn", "spirits"]
        case .mdma: ["xtc", "ecstasy", "e", "md", "mandy", "molly", "pills", "pillen"]
        case .threeMMC: ["3-mmc", "3 mmc", "3mmc", "poes", "mmc", "cathinone"]
        case .ketamine: ["k", "ket", "keta", "special k"]
        case .ghb: ["g", "gee", "liquid ecstasy", "ghb"]
        case .gbl: ["gbl", "g", "wheel cleaner"]
        case .cocaine: ["coke", "coca", "charlie", "snow", "sneeuw", "blow", "c"]
        case .poppers: ["rush", "amyl", "nitrite", "nitrites", "alkyl nitrite"]
        case .kamagra: ["kamagra", "generic viagra", "blue", "jelly"]
        case .viagra: ["sildenafil", "blue pill", "blauwe pil", "erection pill"]
        case .psychedelics: ["lsd", "acid", "trip", "shrooms", "mushrooms", "paddo", "paddos",
                             "psilocybin", "dmt", "2c-b", "mescaline"]
        case .benzodiazepines: ["benzo", "benzos", "xanax", "alprazolam", "valium", "diazepam",
                                "oxazepam", "temazepam", "lorazepam", "clonazepam", "bars"]
        case .methamphetamine: ["meth", "tina", "t", "crystal", "crystal meth", "ice",
                                "methamphetamine", "chrystal"]
        case .unknown: ["unknown", "unsure", "something else"]
        case .other: ["other", "misc"]
        }
    }

    /// Whether this substance answers to `query`.
    ///
    /// Matches the localized display name and every alias, case- and
    /// accent-insensitively, on a prefix or a contained run — so "ket" finds
    /// ketamine and "mmc" finds 3-MMC.
    public func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }

        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        if localizedDisplayName.range(of: needle, options: options) != nil { return true }
        if rawValue.range(of: needle, options: options) != nil { return true }
        return aliases.contains { $0.range(of: needle, options: options) != nil }
    }

    /// The key this substance is filed under in `InteractionChart`.
    ///
    /// Deliberately not `rawValue`: the raw values are display names that have
    /// changed before ("3MMC" was once "3-MMC"), and a rename there must not
    /// silently detach a row from the source that corroborates it.
    public var chartKey: String {
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

    public var symbolName: String {
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


    public var effectWindow: ClosedRange<Double> {
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

    public var defaultTimerHours: Double {
        (effectWindow.lowerBound + effectWindow.upperBound) / 2
    }

    public func adjustedTimerHours(weightKg: Double, heightCm: Double) -> Double {
        let defaultWeight = 75.0
        let defaultHeight = 175.0
        let safeWeight = min(max(weightKg, 35), 180)
        let safeHeight = min(max(heightCm, 130), 220)
        let bodyFactor = ((safeWeight / defaultWeight) * 0.75) + ((safeHeight / defaultHeight) * 0.25)
        let adjusted = defaultTimerHours * min(max(bodyFactor, 0.72), 1.28)
        return min(max(adjusted, effectWindow.lowerBound), effectWindow.upperBound)
    }

    public var durationLabel: String {
        let lower = effectWindow.lowerBound.formatted(.number.precision(.fractionLength(0...1)))
        let upper = effectWindow.upperBound.formatted(.number.precision(.fractionLength(0...1)))
        return "\(lower)-\(upper) h"
    }

    public var informationSummary: String {
        switch self {
        case .cannabis:
            String(localized: "Can affect memory, coordination, anxiety, and sleep. Effects vary strongly by route and strength.", bundle: .main)
        case .alcohol:
            String(localized: "Can lower boundaries and coordination. Mixing with sedatives, GHB/GBL, or other depressants can be dangerous.", bundle: .main)
        case .mdma:
            String(localized: "Stimulant/empathogen effects can include warmth, jaw tension, overheating, and a next-day dip.", bundle: .main)
        case .threeMMC:
            String(localized: "A stimulant cathinone. Can raise heart rate, reduce sleep, and make it harder to pause.", bundle: .main)
        case .ketamine:
            String(localized: "Dissociative effects can affect balance, memory, and consent clarity.", bundle: .main)
        case .ghb:
            String(localized: "Effects can become unpredictable quickly. Mixing with alcohol or sedatives can cause unconsciousness or breathing problems.", bundle: .main)
        case .gbl:
            String(localized: "Converts to GHB in the body and carries similar risks, especially with alcohol or sedatives.", bundle: .main)
        case .cocaine:
            String(localized: "Stimulant effects can strain the heart, reduce sleep, and increase impulsive decisions.", bundle: .main)
        case .poppers:
            String(localized: "Short-acting vasodilator. Avoid with erectile dysfunction medication because blood pressure can drop sharply.", bundle: .main)
        case .kamagra:
            String(localized: "Often contains sildenafil. Avoid with poppers or nitrates because blood pressure can drop dangerously.", bundle: .main)
        case .viagra:
            String(localized: "Sildenafil for erections. Avoid with poppers or nitrates because blood pressure can drop dangerously.", bundle: .main)
        case .psychedelics:
            String(localized: "Can strongly change perception and emotions. Setting, support, and mental state matter.", bundle: .main)
        case .methamphetamine:
            String(localized: "A long, strong stimulant. Sessions stretch for many hours, sleep and eating stop, and the comedown is heavy. Injecting and sharing equipment carry their own risks, and judgement about sex and consent shifts a long way before you notice it has.", bundle: .main)
        case .benzodiazepines:
            String(localized: "Sedatives that differ enormously between compounds: some are gone in a few hours, others are still working the next day. The danger is rarely the benzo on its own — it is stacking it with alcohol, GHB/GBL or another depressant.", bundle: .main)
        case .unknown:
            String(localized: "Unknown substances are harder to predict. Avoid mixing and seek help if something feels wrong.", bundle: .main)
        case .other:
            String(localized: "Use this only for private reflection when something is not listed.", bundle: .main)
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
    public var mainRisks: [String] {
        switch self {
        case .cannabis:
            [String(localized: "Anxiety or paranoia", bundle: .main), String(localized: "Memory and coordination changes", bundle: .main), String(localized: "Stronger effects with edibles or high-potency products", bundle: .main)]
        case .alcohol:
            [String(localized: "Lowered inhibition", bundle: .main), String(localized: "Vomiting or injury risk", bundle: .main), String(localized: "Breathing risk when mixed with depressants", bundle: .main)]
        case .mdma:
            [String(localized: "Overheating and dehydration", bundle: .main), String(localized: "Jaw tension and high heart rate", bundle: .main), String(localized: "Next-day low mood or sleep disruption", bundle: .main)]
        case .threeMMC:
            [String(localized: "Strong urge to continue", bundle: .main), String(localized: "High heart rate and anxiety", bundle: .main), String(localized: "Sleep loss and low mood afterwards", bundle: .main)]
        case .ketamine:
            [String(localized: "Dissociation and falls", bundle: .main), String(localized: "Memory gaps", bundle: .main), String(localized: "Consent clarity can be affected", bundle: .main)]
        case .ghb, .gbl:
            [String(localized: "Unconsciousness can happen quickly", bundle: .main), String(localized: "Breathing problems when mixed", bundle: .main), String(localized: "Harder to judge safety and consent", bundle: .main)]
        case .cocaine:
            [String(localized: "Heart strain", bundle: .main), String(localized: "Anxiety or agitation", bundle: .main), String(localized: "Sleep loss and impulsive decisions", bundle: .main)]
        case .poppers:
            [String(localized: "Blood pressure drop", bundle: .main), String(localized: "Dizziness or fainting", bundle: .main), String(localized: "Higher risk with erectile medication", bundle: .main)]
        case .kamagra, .viagra:
            [String(localized: "Blood pressure effects", bundle: .main), String(localized: "Headache or dizziness", bundle: .main), String(localized: "Dangerous with poppers or nitrates", bundle: .main)]
        case .psychedelics:
            [String(localized: "Strong emotional shifts", bundle: .main), String(localized: "Panic or confusion", bundle: .main), String(localized: "Long duration and setting sensitivity", bundle: .main)]
        case .benzodiazepines:
            [String(localized: "Breathing risk when stacked with other depressants", bundle: .main), String(localized: "Memory gaps and blackouts", bundle: .main), String(localized: "Dependence builds fast with regular use", bundle: .main)]
        case .methamphetamine:
            [String(localized: "Heart strain and dangerously high temperature", bundle: .main), String(localized: "Days without sleep, then a heavy crash", bundle: .main), String(localized: "Consent and limits get much harder to hold", bundle: .main)]
        case .unknown:
            [String(localized: "Unknown strength", bundle: .main), String(localized: "Unknown contents", bundle: .main), String(localized: "Higher risk when mixed", bundle: .main)]
        case .other:
            [String(localized: "Unknown risk profile", bundle: .main), String(localized: "Timing and amount may be uncertain", bundle: .main), String(localized: "Avoid mixing unknown substances", bundle: .main)]
        }
    }

    public var mixingRisks: [String] {
        switch self {
        case .ghb, .gbl:
            [String(localized: "Avoid alcohol, benzodiazepines, opioids, ketamine, and other sedatives.", bundle: .main)]
        case .poppers:
            [String(localized: "Avoid Viagra, Kamagra, sildenafil, nitrates, nicorandil, or riociguat.", bundle: .main)]
        case .kamagra, .viagra:
            [String(localized: "Avoid poppers and nitrate-like medication because blood pressure can drop sharply.", bundle: .main)]
        case .mdma, .threeMMC, .cocaine:
            [String(localized: "Avoid stacking stimulants and be careful with serotonergic medication or MAOIs.", bundle: .main)]
        case .alcohol:
            [String(localized: "Avoid GHB/GBL, benzodiazepines, opioids, ketamine, and heavy stimulant use.", bundle: .main)]
        case .ketamine:
            [String(localized: "Avoid depressant stacks and settings where falls, water, stairs, or consent confusion are likely.", bundle: .main)]
        default:
            [String(localized: "Avoid unknown mixes, pressure to continue, and combining with medication without professional advice.", bundle: .main)]
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
    public var seekHelpSigns: [String] {
        switch self {
        case .alcohol:
            [
                String(localized: "Cannot be woken, or is snoring or gurgling", bundle: .main),
                String(localized: "Breathing is slow, shallow, or has stopped", bundle: .main),
                String(localized: "Has been sick while unable to sit up", bundle: .main),
                String(localized: "Skin is cold, clammy, or looks grey", bundle: .main)
            ]

        case .ghb, .gbl:
            [
                String(localized: "Went under suddenly, within minutes of a dose", bundle: .main),
                String(localized: "Cannot be woken, or is snoring or gurgling", bundle: .main),
                String(localized: "Breathing is slow, shallow, or has stopped", bundle: .main),
                String(localized: "Woke briefly, was confused or combative, then went under again", bundle: .main)
            ]

        case .ketamine:
            [
                String(localized: "Cannot move and is being sick", bundle: .main),
                String(localized: "Breathing is slow, shallow, or has stopped", bundle: .main),
                String(localized: "Cannot be woken, or is snoring or gurgling", bundle: .main)
            ]

        case .mdma, .threeMMC:
            [
                String(localized: "Very high temperature, or has stopped sweating", bundle: .main),
                String(localized: "Confusion with shivering, stiff muscles, or fever", bundle: .main),
                String(localized: "Seizure, or severe agitation that will not settle", bundle: .main),
                String(localized: "Drank a lot of water and became confused or had a seizure", bundle: .main)
            ]

        case .cocaine:
            [
                String(localized: "Chest pain, or a heartbeat that is racing or irregular", bundle: .main),
                String(localized: "Very high temperature, or has stopped sweating", bundle: .main),
                String(localized: "Seizure, or severe agitation that will not settle", bundle: .main),
                String(localized: "Sudden severe headache, or weakness on one side", bundle: .main)
            ]

        case .poppers:
            [
                String(localized: "Lips or fingertips are blue or grey and fresh air does not help", bundle: .main),
                String(localized: "Fainting, or a sudden severe headache", bundle: .main),
                String(localized: "Swallowed rather than inhaled, which can be life-threatening", bundle: .main)
            ]

        case .viagra, .kamagra:
            [
                String(localized: "An erection lasting longer than four hours", bundle: .main),
                String(localized: "Chest pain, fainting, or an irregular heartbeat", bundle: .main),
                String(localized: "Sudden loss of vision or hearing", bundle: .main)
            ]

        case .cannabis:
            [
                String(localized: "Repeated cycles of severe vomiting", bundle: .main),
                String(localized: "Panic with a racing heart that will not settle", bundle: .main),
                String(localized: "Chest pain, or fainting", bundle: .main)
            ]

        case .psychedelics:
            [
                String(localized: "Severe panic that will not settle, or does not know where they are", bundle: .main),
                String(localized: "Seizure, or a dangerously high temperature", bundle: .main),
                String(localized: "At risk of harming themselves or cannot be kept safe", bundle: .main)
            ]

        case .methamphetamine:
            [
                String(localized: "Chest pain, a racing heart that will not settle, or collapse", bundle: .main),
                String(localized: "Very hot to the touch, or has stopped sweating", bundle: .main),
                String(localized: "Seizure, or twitching they cannot control", bundle: .main),
                String(localized: "Severe agitation, paranoia, or does not know where they are", bundle: .main)
            ]

        // NHS medicines guidance on diazepam names slower, shallower breathing as
        // the serious sign and says to treat an extra dose as an emergency. The
        // rest is the same depressant picture as alcohol and GHB, which is the
        // situation a benzo is almost always in when this app is open.
        case .benzodiazepines:
            [
                String(localized: "Breathing is slow or shallow, or has stopped", bundle: .main),
                String(localized: "Cannot be woken, or only briefly and not properly", bundle: .main),
                String(localized: "Was taken with alcohol, GHB/GBL or another sedative", bundle: .main),
                String(localized: "Lips or fingertips look blue or grey", bundle: .main)
            ]

        case .unknown, .other:
            [
                String(localized: "Chest pain, seizure, fainting, or cannot be woken", bundle: .main),
                String(localized: "Blue lips, slow breathing, overheating, or severe confusion", bundle: .main),
                String(localized: "Severe panic, hallucinations, or feeling unsafe with people nearby", bundle: .main)
            ]
        }
    }

}

public enum LogMode: String, CaseIterable, Identifiable {
    case tracked = "I used"
    case skipped = "I didn't use"

    public var id: String { rawValue }
}
