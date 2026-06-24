import Foundation

// Medication interaction-matching data and logic extracted from CareToolsView.swift.
// These are pure (non-View) types with no dependency on CareToolsView's private members,
// which also makes the matching logic unit-testable in isolation.

struct MedicationRiskMatch: Hashable {
    let category: MedicationRiskCategory
    let matchedTerm: String
}

enum MedicationRiskCategory: String, CaseIterable {
    case serotonergic
    case maoi
    case sedative
    case opioid
    case nitrateLike
    case alphaBlocker
    case stimulantMedication
    case ritonavirBooster

    var label: String {
        switch self {
        case .serotonergic:
            String(localized: "Affects serotonin")
        case .maoi:
            String(localized: "MAOI")
        case .sedative:
            String(localized: "Sedative")
        case .opioid:
            String(localized: "Opioid")
        case .nitrateLike:
            String(localized: "Nitrate-like")
        case .alphaBlocker:
            String(localized: "Alpha blocker")
        case .stimulantMedication:
            String(localized: "Stimulant medication")
        case .ritonavirBooster:
            String(localized: "Ritonavir/cobicistat")
        }
    }

    var aliases: [String] {
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

enum MedicationRiskDatabase {
    static func matches(in text: String) -> [MedicationRiskMatch] {
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

struct MedicationSuggestion: Identifiable {
    let id: String
    let name: String
    let detail: String
    let dosage: String?
    let effectiveHours: Double?
}

enum MedicationSuggestionDatabase {
    static func suggestions(for query: String, savedMedications: [ProfileMedication]) -> [MedicationSuggestion] {
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
                    detail: String(localized: "Common interaction category"),
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
