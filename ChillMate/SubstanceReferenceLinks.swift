import Foundation
import ChillMateCore

/// Where to go and read more, which depends on where the reader is.
///
/// Split out of `Substance` when the domain moved into `ChillMateCore`. The
/// substance itself is the same everywhere; which national service to send
/// somebody to is app configuration, read from a `UserDefaults` key the domain
/// has no business being able to see.
extension Substance {

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
