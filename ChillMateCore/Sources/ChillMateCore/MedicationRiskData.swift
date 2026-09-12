import Foundation

/// The one thing the medication matcher needs from a saved medication.
///
/// It took `[ProfileMedication]`, which is a SwiftData model, so a name matcher
/// could not be compiled without a persistence framework. `UserProfile` supplies
/// the conformance in the app.
public protocol SavedMedication {
    var id: UUID { get }
    var name: String { get }
    var dosage: String { get }
    var effectiveHours: Double { get }
    /// When it was taken and how long it is expected to work, already written out.
    var timingSummary: String { get }
}

// Medication interaction-matching data and logic extracted from CareToolsView.swift.
// These are pure (non-View) types with no dependency on CareToolsView's private members,
// which also makes the matching logic unit-testable in isolation.

public struct MedicationRiskMatch: Hashable {
    public let category: MedicationRiskCategory
    public let matchedTerm: String
}

public enum MedicationRiskCategory: String, CaseIterable, Sendable {
    case serotonergic
    case maoi
    case sedative
    case opioid
    case nitrateLike
    case alphaBlocker
    case stimulantMedication
    case ritonavirBooster

    public var label: String {
        switch self {
        case .serotonergic:
            String(localized: "Affects serotonin", bundle: .main)
        case .maoi:
            String(localized: "MAOI", bundle: .main)
        case .sedative:
            String(localized: "Sedative", bundle: .main)
        case .opioid:
            String(localized: "Opioid", bundle: .main)
        case .nitrateLike:
            String(localized: "Nitrate-like", bundle: .main)
        case .alphaBlocker:
            String(localized: "Alpha blocker", bundle: .main)
        case .stimulantMedication:
            String(localized: "Stimulant medication", bundle: .main)
        case .ritonavirBooster:
            String(localized: "Ritonavir/cobicistat", bundle: .main)
        }
    }

    public var aliases: [String] {
        switch self {
        case .serotonergic:
            [
                "ssri", "snri", "tramadol", "lithium", "linezolid", "mirtazapine", "venlafaxine",
                "fluoxetine", "sertraline", "citalopram", "escitalopram", "paroxetine", "duloxetine",
                "vortioxetine", "dextromethorphan", "sumatriptan", "triptan", "st johns wort"
            ]
        case .maoi:
            ["maoi", "phenelzine", "tranylcypromine", "moclobemide", "selegiline"]
        case .sedative:
            [
                "benzodiazepine", "benzo", "diazepam", "alprazolam", "lorazepam", "oxazepam",
                "temazepam", "zolpidem", "zopiclone", "pregabalin", "gabapentin", "baclofen", "quetiapine"
            ]
        case .opioid:
            ["opioid", "opiate", "oxycodone", "morphine", "fentanyl", "codeine", "methadone", "buprenorphine", "tramadol"]
        case .nitrateLike:
            ["nitrate", "nitroglycerin", "glyceryl trinitrate", "isosorbide", "mononitrate", "dinitrate", "nicorandil", "riociguat"]
        case .alphaBlocker:
            ["alpha blocker", "tamsulosin", "doxazosin", "alfuzosin", "prazosin", "terazosin"]
        case .stimulantMedication:
            [
                "methylphenidate", "ritalin", "concerta", "dexamfetamine", "dexamphetamine",
                "lisdexamfetamine", "vyvanse", "elvanse", "adderall", "modafinil", "bupropion"
            ]
        case .ritonavirBooster:
            ["ritonavir", "cobicistat"]
        }
    }
}

public enum MedicationRiskDatabase {
    public static func matches(in text: String) -> [MedicationRiskMatch] {
        let normalizedText = normalized(text)
        guard !normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var matches: [MedicationRiskMatch] = []

        for category in MedicationRiskCategory.allCases {
            for alias in category.aliases {
                let normalizedAlias = normalized(alias)
                if contains(normalizedAlias, in: normalizedText) {
                    matches.append(MedicationRiskMatch(category: category, matchedTerm: alias))
                    break
                }
            }
        }

        return matches
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
    }

    private static func contains(_ alias: String, in text: String) -> Bool {
        let paddedText = " \(text) "
        let paddedAlias = " \(alias) "
        return paddedText.contains(paddedAlias)
    }
}

public struct MedicationSuggestion: Identifiable {
    public let id: String
    public let name: String
    public let detail: String
    public let dosage: String?
    public let effectiveHours: Double?
}

public enum MedicationSuggestionDatabase {
    public static func suggestions<Medication: SavedMedication>(for query: String, savedMedications: [Medication]) -> [MedicationSuggestion] {
        let normalizedQuery = normalized(query)
        guard normalizedQuery.count >= 2 else {
            return []
        }

        var suggestions: [MedicationSuggestion] = []

        for medication in savedMedications where matches(medication.name, query: normalizedQuery) {
            suggestions.append(
                MedicationSuggestion(
                    id: "saved-\(medication.id.uuidString)",
                    name: medication.name,
                    detail: medication.timingSummary,
                    dosage: medication.dosage,
                    effectiveHours: medication.effectiveHours
                )
            )
        }

        let knownNames = MedicationRiskCategory.allCases
            .flatMap(\.aliases)
            .map { $0.capitalized }
            .sorted()

        for name in knownNames where matches(name, query: normalizedQuery) {
            let id = "known-\(normalized(name))"
            guard !suggestions.contains(where: { $0.id == id || normalized($0.name) == normalized(name) }) else {
                continue
            }
            suggestions.append(
                MedicationSuggestion(
                    id: id,
                    name: name,
                    detail: String(localized: "Common interaction category", bundle: .main),
                    dosage: nil,
                    effectiveHours: nil
                )
            )
        }

        return Array(suggestions.prefix(6))
    }

    private static func matches(_ value: String, query: String) -> Bool {
        normalized(value).contains(query)
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
