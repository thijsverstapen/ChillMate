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
    // Leaf tools that used to live in their own tab, now reachable through a group.
    case safeRoute
    case weeklyReflection
    // Moment-based groups shown on Home. Each pushes a landing page listing its members.
    case groupBefore
    case groupDuring
    case groupAfter
    case groupPatterns

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

/// A Home "moment" that bundles several care tools under one intent, so the
/// dashboard shows four grouped cards instead of a dozen competing ones.
struct CareToolGroup: Identifiable {
    let page: CareToolPage
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let members: [CareToolPage]

    var id: String { page.id }

    /// The four groups shown on Home, in session order: prepare, be out, recover, reflect.
    static var homeGroups: [CareToolGroup] {
        [
            CareToolGroup(
                page: .groupBefore,
                title: String(localized: "Before you go"),
                subtitle: String(localized: "Plan · combos · substances · boundaries"),
                symbol: "checkmark.shield.fill",
                tint: Color.chillSecondaryBlue,
                members: [.saferPlanning, .combinationRisk, .drugInfo, .consentBoundaries, .drugChecking]
            ),
            CareToolGroup(
                page: .groupDuring,
                title: String(localized: "While you’re out"),
                subtitle: String(localized: "Check-in timers · safe route home"),
                symbol: "timer",
                tint: Color.chillIconAmber,
                members: [.drugTimers, .safeRoute, .emergency]
            ),
            CareToolGroup(
                page: .groupAfter,
                title: String(localized: "Aftercare & health"),
                subtitle: String(localized: "Morning check-in · STI tests"),
                symbol: "heart.text.square.fill",
                tint: Color.chillIconGreen,
                members: [.aftercare, .stdTests]
            ),
            CareToolGroup(
                page: .groupPatterns,
                title: String(localized: "Your patterns"),
                subtitle: String(localized: "Insights · recovery · weekly reflection"),
                symbol: "chart.xyaxis.line",
                tint: Color.chillIconPurple,
                members: [.privateInsights, .recoveryMode, .weeklyReflection, .helperBridge]
            )
        ]
    }

    /// A `CareToolDefinition` describing the group card itself (for the Home grid).
    var cardDefinition: CareToolDefinition {
        CareToolDefinition(page: page, title: title, subtitle: subtitle, symbol: symbol, tint: tint)
    }
}

/// Single source of truth for how each leaf tool presents (title, blurb, icon,
/// tint). Used by the grouped Home cards and every group landing page so the two
/// never drift apart.
enum CareToolCatalog {
    static func definition(for page: CareToolPage) -> CareToolDefinition {
        switch page {
        case .saferPlanning:
            return CareToolDefinition(page: page, title: String(localized: "Plan"), subtitle: String(localized: "Before-Chill checklist"), symbol: "checkmark.shield.fill", tint: Color.chillMint)
        case .combinationRisk:
            return CareToolDefinition(page: page, title: String(localized: "Risk checker"), subtitle: String(localized: "Safety signals"), symbol: "exclamationmark.shield.fill", tint: Color.chillIconOrange)
        case .drugInfo:
            return CareToolDefinition(page: page, title: String(localized: "Substance info"), subtitle: String(localized: "Safety reference"), symbol: "pills.fill", tint: Color.chillIconPurple)
        case .consentBoundaries:
            return CareToolDefinition(page: page, title: String(localized: "Boundaries"), subtitle: String(localized: "Consent and exit plan"), symbol: "hand.raised.fill", tint: Color.chillIconTeal)
        case .drugChecking:
            return CareToolDefinition(page: page, title: String(localized: "Checking info"), subtitle: String(localized: "Where to test your drugs"), symbol: "testtube.2", tint: Color.chillMint)
        case .drugTimers:
            return CareToolDefinition(page: page, title: String(localized: "Check-ins"), subtitle: String(localized: "Recovery reminders"), symbol: "timer", tint: Color.chillIconAmber)
        case .safeRoute:
            return CareToolDefinition(page: page, title: String(localized: "Safe route home"), subtitle: String(localized: "Plan transport and share location"), symbol: "location.fill", tint: Color.chillMint)
        case .emergency:
            return CareToolDefinition(page: page, title: String(localized: "Emergency Information"), subtitle: String(localized: "Numbers, contact, and location message"), symbol: "sos.circle.fill", tint: Color.chillIconRed)
        case .aftercare:
            return CareToolDefinition(page: page, title: String(localized: "Aftercare"), subtitle: String(localized: "Check in tomorrow"), symbol: "heart.text.square.fill", tint: Color.chillIconPink)
        case .stdTests:
            return CareToolDefinition(page: page, title: String(localized: "STI tests"), subtitle: String(localized: "Dates and results"), symbol: "cross.case.fill", tint: Color.chillIconTeal)
        case .privateInsights:
            return CareToolDefinition(page: page, title: String(localized: "Insights"), subtitle: String(localized: "Private patterns"), symbol: "chart.xyaxis.line", tint: Color.chillSecondaryBlue)
        case .recoveryMode:
            return CareToolDefinition(page: page, title: String(localized: "Recovery mode"), subtitle: String(localized: "Goals and cravings"), symbol: "figure.mind.and.body", tint: Color.chillIconGreen)
        case .weeklyReflection:
            return CareToolDefinition(page: page, title: String(localized: "Weekly reflection"), subtitle: String(localized: "A private, on-device summary"), symbol: "text.book.closed.fill", tint: Color.chillIconPurple)
        case .helperBridge:
            return CareToolDefinition(page: page, title: String(localized: "Helper summary"), subtitle: String(localized: "Share with a professional"), symbol: "person.2.wave.2.fill", tint: Color.chillSecondaryBlue)
        case .panicSupport:
            return CareToolDefinition(page: page, title: String(localized: "Panic support"), subtitle: String(localized: "Breathing, contact, and grounding"), symbol: "lungs.fill", tint: Color.chillIconPurple)
        case .safetyAutopilot:
            return CareToolDefinition(page: page, title: String(localized: "Safety autopilot"), subtitle: String(localized: "Helper summary and checking info"), symbol: "sparkles.rectangle.stack.fill", tint: Color.chillSecondaryBlue)
        case .groupBefore, .groupDuring, .groupAfter, .groupPatterns:
            // Groups describe themselves via CareToolGroup; fall back gracefully.
            return CareToolGroup.homeGroups.first { $0.page == page }?.cardDefinition
                ?? CareToolDefinition(page: page, title: page.rawValue, subtitle: "", symbol: "square.grid.2x2.fill", tint: Color.chillPrimary)
        }
    }
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
