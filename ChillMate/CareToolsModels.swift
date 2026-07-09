import Foundation
import SwiftUI

// Plain (non-View) model, enum, and store types extracted from CareToolsView.swift
// as the first increment of splitting that file into per-concern units. These types
// are `internal` and have no dependency on CareToolsView's private members, so moving
// them here is behavior-preserving.

/// Country-aware emergency-services number, honoring the user's manual override.
/// Every supported country uses 112 except the United Kingdom (999); 112 also
/// works EU-wide as a fallback. Readable from any view or service.
enum EmergencyContactInfo {
    static var number: String {
        let defaults = UserDefaults.standard
        let override = (defaults.string(forKey: "localEmergencyNumber") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !override.isEmpty { return override }
        switch defaults.string(forKey: "country") ?? "Netherlands" {
        case "United Kingdom": return "999"
        case "United States": return "911"
        case "Australia": return "000"
        default: return "112"
        }
    }

    /// A `tel://` URL for the resolved emergency number, or nil if malformed.
    static var dialURL: URL? {
        URL(string: "tel://\(number.filter { $0.isNumber || $0 == "+" })")
    }
}

enum CareToolPage: String, Identifiable {
    case safetyAutopilot
    case saferPlanning
    case stdTests
    case drugTimers
    case emergency
    case panicSupport
    case drugInfo
    case aftercare
    case combinationRisk
    case consentBoundaries
    case recoveryMode
    case privateInsights
    case helperBridge
    case drugChecking

    var id: String { rawValue }
}

struct CareToolDefinition: Identifiable {
    let page: CareToolPage
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var id: String { page.id }
}

enum CombinationTiming: String, CaseIterable, Identifiable {
    case sameSession = "Same session"
    case withinSixHours = "6 h"
    case withinDay = "24 h"

    var id: String { rawValue }
}

enum RiskLevel {
    case lower
    case caution
    case high

    var label: String {
        switch self {
        case .lower:
            String(localized: "No known")
        case .caution:
            String(localized: "Caution")
        case .high:
            String(localized: "High")
        }
    }

    var tint: Color {
        switch self {
        case .lower:
            Color.chillMint
        case .caution:
            .orange
        case .high:
            .red
        }
    }
}

struct RecentlyDeletedItem: Codable, Identifiable {
    var id = UUID()
    var kind: String
    var title: String
    var detail: String
    var deletedAt: Date
}

enum RecentlyDeletedStore {
    private static let key = "recentlyDeletedItems"

    static func items() -> [RecentlyDeletedItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([RecentlyDeletedItem].self, from: data) else {
            return []
        }
        return items.sorted { $0.deletedAt > $1.deletedAt }
    }

    static func record(kind: String, title: String, detail: String, deletedAt: Date = .now) {
        var current = items()
        current.insert(RecentlyDeletedItem(kind: kind, title: title, detail: detail, deletedAt: deletedAt), at: 0)
        current = Array(current.prefix(40))
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
