import Foundation

/// The two words the risk engine speaks in.
///
/// Both lived in `CareToolsModels.swift`, a file about care-tool pages, next to
/// a SwiftUI colour. `CombinationAssessment` is the only thing that produces a
/// `RiskLevel` and the only thing that reads a `CombinationTiming`, so they
/// belong beside it. The colour stayed behind: a severity is a severity whether
/// or not there is a screen.

public enum CombinationTiming: String, CaseIterable, Identifiable, Sendable {
    case sameSession = "Same session"
    case withinSixHours = "6 h"
    case withinDay = "24 h"

    public var id: String { rawValue }
}

public enum RiskLevel: Sendable {
    case lower
    case caution
    case high

    public var label: String {
        switch self {
        case .lower:
            String(localized: "No known", bundle: .main)
        case .caution:
            String(localized: "Caution", bundle: .main)
        case .high:
            String(localized: "High", bundle: .main)
        }
    }
}
