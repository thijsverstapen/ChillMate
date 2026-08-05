import Foundation
import SwiftData
import SwiftUI

struct SafetyAutopilotView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(ChillMateQueries.recentEntries) private var entries: [NightEntry]
    @Query(ChillMateQueries.recentTimers) private var timers: [DrugDoseTimerRecord]
    @Query(ChillMateQueries.recentPlansByDate) private var plans: [SaferSessionPlan]
    @Query(ChillMateQueries.recentTests) private var stiTests: [STDTestRecord]
    @Query(ChillMateQueries.profile) private var profiles: [UserProfile]

    @State private var showHelperSummary = false
    @State private var showCheckingInfo = false

    private var context: SafetyAutopilotContext {
        SafetyAutopilotContext(
            entries: entries,
            timers: timers,
            plans: plans,
            stiTests: stiTests,
            profile: profiles.first
        )
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Safety autopilot"),
                            subtitle: String(localized: "A calm place to see what might help next. It looks at your saved logs, timers, plans, sleep, symptoms, STI/PEP timing, and trusted contact."),
                            symbol: "sparkles.rectangle.stack.fill",
                            tint: Color.chillSecondaryBlue
                        )

                        SafetyAutopilotStatusCard(context: context)

                        VStack(alignment: .leading, spacing: 12) {
                            CareSectionTitle(title: String(localized: "Do next"), symbol: "arrow.right.circle.fill")

                            ForEach(context.actions) { action in
                                SafetyAutopilotActionCard(action: action)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            CareSectionTitle(title: String(localized: "More support"), symbol: "ellipsis.circle.fill")

                            SafetyAutopilotLinkRow(
                                title: String(localized: "Helper summary"),
                                detail: String(localized: "A simple summary to share with a GP or helper"),
                                symbol: "doc.text.magnifyingglass",
                                tint: Color.chillMint
                            ) { showHelperSummary = true }

                            SafetyAutopilotLinkRow(
                                title: String(localized: "Checking info"),
                                detail: String(localized: "Drug-checking and where to find support"),
                                symbol: "checkmark.seal.text.page.fill",
                                tint: Color.chillIconAmber
                            ) { showCheckingInfo = true }
                        }

                        ConsentMiniCard()
                        EvidenceSourcesSection(title: String(localized: "Why these suggestions?"), sources: EvidenceLibrary.coreSafety)
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(Text(verbatim: ""))
            .fullScreenCover(isPresented: $showHelperSummary) {
                CareCoverHost { ProfessionalHelperBridgeView() }
            }
            .fullScreenCover(isPresented: $showCheckingInfo) {
                CareCoverHost { DrugCheckingEducationView() }
            }
        }
    }
}

private struct SafetyAutopilotLinkRow: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.chillText)
                    Text(detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .glassSurface(radius: 20, tint: tint.opacity(0.07), interactive: true)
        }
        .buttonStyle(ChillPlainButtonStyle())
    }
}

private struct SafetyAutopilotContext {
    let entries: [NightEntry]
    let timers: [DrugDoseTimerRecord]
    let plans: [SaferSessionPlan]
    let stiTests: [STDTestRecord]
    let profile: UserProfile?

    private var now: Date { .now }

    var latestEntry: NightEntry? {
        entries.first
    }

    var activeTimer: DrugDoseTimerRecord? {
        timers.first { $0.endsAt > now }
    }

    var latestPEPEntry: NightEntry? {
        entries.first { $0.suggestsPEPConcern && $0.pepDeadline > now }
    }

    var recoveryStreakDays: Int {
        ChillInsightCalculator.recoveryStreakDays(entries: entries)
    }

    var riskTrend: (recent: Int, previous: Int) {
        ChillInsightCalculator.riskyLogTrend(entries: entries)
    }

    var actions: [SafetyAutopilotAction] {
        var result: [SafetyAutopilotAction] = []

        if let pep = latestPEPEntry {
            let hours = max(0, Int(pep.pepDeadline.timeIntervalSince(now) / 3600))
            result.append(SafetyAutopilotAction(
                priority: .urgent,
                title: String(localized: "PEP window is active"),
                detail: "It has been less than 72 hours since a log that may include HIV exposure. Contact a sexual-health service, your doctor, an out-of-hours clinic, or a hospital now. About \(hours) hours remain.",
                symbol: "cross.case.circle.fill"
            ))
        }

        if let timer = activeTimer {
            let progress = Int((timer.effectProgress(at: now) * 100).rounded())
            result.append(SafetyAutopilotAction(
                priority: timer.redoseNudgeIsActive(at: now) ? .caution : .support,
                title: timer.redoseNudgeIsActive(at: now) ? "Pause before continuing" : "Check-in is active",
                detail: "\(timer.substanceName) check-in is \(progress)% through. Check water, food, body temperature, support, and whether you still feel safe.",
                symbol: "timer.circle.fill"
            ))
        }

        if let entry = latestEntry, entry.reportedMemoryGap {
            result.append(SafetyAutopilotAction(
                priority: entry.memoryNeedsHelp || entry.memoryConsentConcern || entry.memoryInjuries ? .urgent : .caution,
                title: String(localized: "Memory gap protocol"),
                detail: String(localized: "Keep it simple: are you safe now, hurt, missing anything, worried about consent, or needing help? If yes, contact someone you trust or professional support."),
                symbol: "brain.head.profile"
            ))
        }

        if let entry = latestEntry, !entry.skippedNight {
            if entry.sleptYet && entry.sleepHours < 3 {
                result.append(SafetyAutopilotAction(
                    priority: .caution,
                    title: String(localized: "Low sleep recovery"),
                    detail: String(localized: "Less than 3 hours of sleep was logged. Keep today simple: water, food, rest, and avoid stacking stimulants."),
                    symbol: "bed.double.fill"
                ))
            }

            if !entry.aftercareDrankWater || !entry.aftercareAteFood {
                result.append(SafetyAutopilotAction(
                    priority: .support,
                    title: String(localized: "Body basics"),
                    detail: String(localized: "Aftercare is incomplete. Drink water slowly and eat something gentle if you can."),
                    symbol: "drop.fill"
                ))
            }
        }

        if plans.first(where: { $0.plannedDate > now && $0.plannedDate < now.addingTimeInterval(36 * 60 * 60) }) == nil {
            result.append(SafetyAutopilotAction(
                priority: .support,
                title: String(localized: "Plan before the next Chill"),
                detail: String(localized: "A short plan helps: ending time, transport, medication check, substance limits, condoms/lube, emergency contact, and boundaries."),
                symbol: "checkmark.shield.fill"
            ))
        }

        if riskTrend.recent >= 3 && riskTrend.recent > riskTrend.previous {
            result.append(SafetyAutopilotAction(
                priority: .caution,
                title: String(localized: "Something may have changed"),
                detail: "Risky logs increased from \(riskTrend.previous) to \(riskTrend.recent). Look at stress, loneliness, money, housing, conflict, boredom, or breakup patterns.",
                symbol: "waveform.path.ecg"
            ))
        }

        if result.isEmpty {
            result.append(SafetyAutopilotAction(
                priority: .good,
                title: String(localized: "No urgent action right now"),
                detail: String(localized: "Your recent logs do not show an urgent window right now. Keep your lock on, plan ahead, and use the pause tool if cravings show up."),
                symbol: "checkmark.seal.fill"
            ))
        }

        return Array(result.prefix(5))
    }
}

private struct SafetyAutopilotAction: Identifiable {
    let id = UUID()
    let priority: SafetyAutopilotPriority
    let title: String
    let detail: String
    let symbol: String
}

private enum SafetyAutopilotPriority {
    case urgent
    case caution
    case support
    case good

    var label: String {
        switch self {
        case .urgent: "Urgent"
        case .caution: String(localized: "Caution")
        case .support: "Support"
        case .good: "Steady"
        }
    }

    var tint: Color {
        switch self {
        case .urgent: .red
        case .caution: .orange
        case .support: Color.chillSecondaryBlue
        case .good: Color.chillMint
        }
    }
}

private struct SafetyAutopilotStatusCard: View {
    let context: SafetyAutopilotContext

    var body: some View {
        HStack(spacing: 12) {
            SafetyStatusMetric(title: String(localized: "Streak"), value: "\(context.recoveryStreakDays)d", symbol: "leaf.circle.fill", tint: Color.chillMint)
            SafetyStatusMetric(title: String(localized: "Risk trend"), value: "\(context.riskTrend.recent)/3w", symbol: "chart.line.uptrend.xyaxis", tint: context.riskTrend.recent > context.riskTrend.previous ? .orange : Color.chillSecondaryBlue)
            SafetyStatusMetric(title: String(localized: "Timer"), value: context.activeTimer == nil ? "None" : "Active", symbol: "timer", tint: context.activeTimer == nil ? Color.chillSecondary : Color.chillSecondaryBlue)
        }
        .padding(14)
        .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08))
    }
}

private struct SafetyStatusMetric: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.headline)
                .foregroundStyle(Color.chillText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.chillSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 74)
    }
}

private struct SafetyAutopilotActionCard: View {
    let action: SafetyAutopilotAction

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: action.symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(action.priority.tint)
                .frame(width: 42, height: 42)
                .glassSurface(radius: 21, tint: action.priority.tint.opacity(0.12))

            VStack(alignment: .leading, spacing: 6) {
                Text(action.priority.label.uppercased())
                    .font(.caption2.weight(.black))
                    .foregroundStyle(action.priority.tint)
                Text(action.title)
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
                Text(action.detail)
                    .font(.callout)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
        .padding(16)
        .glassSurface(radius: 26, tint: action.priority.tint.opacity(0.08), interactive: true)
    }
}
