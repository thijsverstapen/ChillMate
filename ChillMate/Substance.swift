import SwiftUI

enum Substance: String, CaseIterable, Identifiable {
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
    case unknown = "Unknown"
    case other = "Other"

    var id: String { rawValue }

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
        case .unknown:
            "questionmark.circle.fill"
        case .other:
            "plus.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .cannabis:
            Color.chillVisibleMint
        case .alcohol:
            .orange
        case .mdma:
            Color.chillVisibleMint
        case .threeMMC:
            .red
        case .ketamine:
            Color.chillPrimary
        case .ghb:
            Color.chillVisibleBlue
        case .gbl:
            Color.chillVisibleMint
        case .cocaine:
            Color.chillVisibleBlue
        case .poppers:
            Color.chillVisibleMint
        case .kamagra:
            Color.chillVisibleBlue
        case .viagra:
            .indigo
        case .psychedelics:
            .indigo
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
            "Can affect memory, coordination, anxiety, and sleep. Effects vary strongly by route and strength."
        case .alcohol:
            "Can lower boundaries and coordination. Mixing with sedatives, GHB/GBL, or other depressants can be dangerous."
        case .mdma:
            "Stimulant/empathogen effects can include warmth, jaw tension, overheating, and a next-day dip."
        case .threeMMC:
            "A stimulant cathinone. Can raise heart rate, reduce sleep, and increase redosing urges."
        case .ketamine:
            "Dissociative effects can affect balance, memory, and consent clarity."
        case .ghb:
            "Small amount changes can matter. Mixing with alcohol or sedatives can cause unconsciousness or breathing problems."
        case .gbl:
            "Converts to GHB in the body and carries similar risks, especially with alcohol or sedatives."
        case .cocaine:
            "Stimulant effects can strain the heart, reduce sleep, and increase impulsive decisions."
        case .poppers:
            "Short-acting vasodilator. Avoid with erectile dysfunction medication because blood pressure can drop sharply."
        case .kamagra:
            "Often contains sildenafil. Avoid with poppers or nitrates because blood pressure can drop dangerously."
        case .viagra:
            "Sildenafil for erections. Avoid with poppers or nitrates because blood pressure can drop dangerously."
        case .psychedelics:
            "Can strongly change perception and emotions. Setting, support, and mental state matter."
        case .unknown:
            "Unknown substances are harder to predict. Avoid mixing and seek help if something feels wrong."
        case .other:
            "Use this for personal notes when the substance is not listed."
        }
    }

    var mainRisks: [String] {
        switch self {
        case .cannabis:
            ["Anxiety or paranoia", "Memory and coordination changes", "Stronger effects with edibles or high-potency products"]
        case .alcohol:
            ["Lowered inhibition", "Vomiting or injury risk", "Breathing risk when mixed with depressants"]
        case .mdma:
            ["Overheating and dehydration", "Jaw tension and high heart rate", "Next-day low mood or sleep disruption"]
        case .threeMMC:
            ["Strong redosing urges", "High heart rate and anxiety", "Sleep loss and comedown"]
        case .ketamine:
            ["Dissociation and falls", "Memory gaps", "Consent clarity can be affected"]
        case .ghb, .gbl:
            ["Narrow dose margin", "Unconsciousness risk", "Breathing problems when mixed"]
        case .cocaine:
            ["Heart strain", "Anxiety or agitation", "Sleep loss and impulsive decisions"]
        case .poppers:
            ["Blood pressure drop", "Dizziness or fainting", "Higher risk with erectile medication"]
        case .kamagra, .viagra:
            ["Blood pressure effects", "Headache or dizziness", "Dangerous with poppers or nitrates"]
        case .psychedelics:
            ["Strong emotional shifts", "Panic or confusion", "Long duration and setting sensitivity"]
        case .unknown:
            ["Unknown strength", "Unknown contents", "Higher risk when mixed"]
        case .other:
            ["Unknown risk profile", "Timing and amount may be uncertain", "Avoid mixing unknown substances"]
        }
    }

    var mixingRisks: [String] {
        switch self {
        case .ghb, .gbl:
            ["Avoid alcohol, benzodiazepines, opioids, ketamine, and other sedatives."]
        case .poppers:
            ["Avoid Viagra, Kamagra, sildenafil, nitrates, nicorandil, or riociguat."]
        case .kamagra, .viagra:
            ["Avoid poppers and nitrate-like medication because blood pressure can drop sharply."]
        case .mdma, .threeMMC, .cocaine:
            ["Avoid stacking stimulants and be careful with serotonergic medication or MAOIs."]
        case .alcohol:
            ["Avoid GHB/GBL, benzodiazepines, opioids, ketamine, and heavy stimulant use."]
        case .ketamine:
            ["Avoid depressant stacks and settings where falls, water, stairs, or consent confusion are likely."]
        default:
            ["Avoid unknown mixes, redosing pressure, and combining with medication without professional advice."]
        }
    }

    var seekHelpSigns: [String] {
        [
            "Chest pain, seizure, fainting, or cannot be woken",
            "Blue lips, slow breathing, overheating, or severe confusion",
            "Severe panic, hallucinations, or feeling unsafe with people nearby"
        ]
    }

    var referenceLabel: String {
        switch self {
        case .kamagra, .viagra:
            "Apotheek.nl sildenafil"
        case .unknown, .other:
            "No source"
        default:
            "Drugsinfo.nl"
        }
    }

    var referenceURL: URL? {
        switch self {
        case .cannabis:
            URL(string: "https://www.drugsinfo.nl/cannabis")
        case .alcohol:
            URL(string: "https://www.drugsinfo.nl/alcohol")
        case .mdma:
            URL(string: "https://www.drugsinfo.nl/xtc")
        case .threeMMC:
            URL(string: "https://www.drugsinfo.nl/3-mmc")
        case .ketamine:
            URL(string: "https://www.drugsinfo.nl/ketamine")
        case .ghb:
            URL(string: "https://www.drugsinfo.nl/ghb")
        case .gbl:
            URL(string: "https://www.drugsinfo.nl/gbl")
        case .cocaine:
            URL(string: "https://www.drugsinfo.nl/cocaine")
        case .poppers:
            URL(string: "https://www.drugsinfo.nl/poppers")
        case .kamagra, .viagra:
            URL(string: "https://www.apotheek.nl/medicijnen/sildenafil")
        case .psychedelics:
            URL(string: "https://www.drugsinfo.nl/lsd")
        case .unknown, .other:
            nil
        }
    }
}

enum LogMode: String, CaseIterable, Identifiable {
    case tracked = "I used"
    case skipped = "I didn't use"

    var id: String { rawValue }
}
