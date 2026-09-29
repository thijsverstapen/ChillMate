import SwiftUI
import ChillMateCore

// The cards Home shows under its header, each one situational.

struct HeaderSummaryView: View {
    let width: CGFloat
    let dailyScore: DailyRecoveryScore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Brand wordmark
            HStack(spacing: 9) {
                ChillMateBrandMark(size: 20)

                Text("ChillMate")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(LinearGradient.chillBrandDiagonal)
            }
            .padding(.bottom, 4)

            Text("Summary")
                .chillScaledFont(size: 38, weight: .bold, relativeTo: .largeTitle, design: .rounded)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.80)

            Text("Your private overview · last 3 months")
                .font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: max(320, width - 40), alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 4)
    }
}

struct ReductionGoalProgressCard: View {
    let goal: Int
    let substanceOnly: Bool
    let entries: [NightEntry]

    private var currentMonthCount: Int {
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
        return entries.filter { entry in
            entry.date >= start && !entry.skippedNight && (substanceOnly ? entry.hasSubstances : entry.hadSex || entry.hasSubstances)
        }.count
    }

    private var progress: Double { min(1, Double(currentMonthCount) / Double(goal)) }

    private var progressColor: Color {
        switch progress {
        case 0..<0.6: Color.chillMint
        case 0.6..<0.85: .yellow
        default: .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Monthly goal", systemImage: "chart.line.downtrend.xyaxis")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(currentMonthCount)")
                    .chillScaledFont(size: 28, weight: .black, relativeTo: .title, design: .rounded)
                    .foregroundStyle(progressColor)
                Text("/ \(goal)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                Text(substanceOnly ? String(localized: "substance sessions this month") : String(localized: "sessions this month"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.10))
                    Capsule()
                        .fill(progressColor)
                        .frame(width: max(12, proxy.size.width * progress))
                }
            }
            .frame(height: 8)

            if currentMonthCount >= goal {
                Text("You've reached your limit for this month. Consider pausing.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            } else {
                Text("\(goal - currentMonthCount) \(goal - currentMonthCount == 1 ? String(localized: "session") : String(localized: "sessions")) remaining this month.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
            }
        }
        .padding(18)
        .glassSurface(radius: 30, tint: progressColor.opacity(0.08), interactive: true)
    }
}

struct HealthWarningCard: View {
    let count: Int
    @State private var isShowingHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Health check-in", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("You have logged \(count) Chills involving sex and substances in the last 3 weeks. That pattern can carry physical and mental health risks.")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Would you like to start talking to a professional helper?")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            HStack {
                GlassActionButton(prominent: true) {
                    isShowingHelp = true
                } label: {
                    Label("Yes", systemImage: "person.2.wave.2.fill")
                        .font(.subheadline.weight(.bold))
                }

                Text("A GP, sexual health clinic, or trusted counselor can help without judgment.")
                    .font(.caption)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .glassSurface(radius: 30, tint: .orange.opacity(0.16), interactive: true)
        .fullScreenCover(isPresented: $isShowingHelp) {
            ProfessionalHelpView()
        }
    }
}

struct PEPCountdownCard: View {
    let entry: NightEntry

    /// Only the remaining-time line is inside the TimelineView. The card body and
    /// its glass surface used to be rebuilt every minute along with it.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("PEP time window", systemImage: "clock.badge.exclamationmark.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("Based on what you logged, this may be worth a quick HIV PEP check. PEP works best if started within 72 hours.")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TimelineView(.periodic(from: .now, by: 60)) { context in
                let remaining = max(0, entry.pepDeadline.timeIntervalSince(context.date))
                HStack(alignment: .firstTextBaseline) {
                    Text(remainingText(for: remaining))
                        .font(.title2.bold())
                        .monospacedDigit()
                        .foregroundStyle(remaining <= 12 * 60 * 60 ? Color.chillIconRed : Color.chillSecondaryBlue)
                    Text("left in the 72 hour window")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.chillSecondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityRemainingLabel(for: remaining))
            }

            Text("Contact a sexual-health service, GP, or hospital as soon as possible. PEP works best when started quickly and is generally time limited to 72 hours.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .glassSurface(radius: 30, tint: Color.chillSecondaryBlue.opacity(0.12), interactive: true)
    }

    private func remainingText(for interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }

    private func accessibilityRemainingLabel(for interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        return String(localized: "\(hours) hours \(minutes) minutes left in the 72 hour PEP window")
    }
}

struct WhatChangedPatternCard: View {
    let recentCount: Int
    let previousCount: Int
    let reasonCounts: [(reason: ChangeReason, count: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What changed?", systemImage: "waveform.path.ecg")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("Risky Chills increased from \(previousCount) to \(recentCount) compared with the previous 3 weeks. If something changed, tagging it in logs can make patterns easier to see.")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if reasonCounts.isEmpty {
                Text("No change reasons tagged yet. New logs now include stress, breakup, work pressure, loneliness, money, housing, conflict, and boredom.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(reasonCounts.prefix(5), id: \.reason) { item in
                        HStack {
                            Text(item.reason.localizedDisplayName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.chillText)
                            Spacer()
                            Text("\(item.count)")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(Color.chillSecondaryBlue)
                        }
                    }
                }
            }
        }
        .padding(18)
        .glassSurface(radius: 30, tint: Color.chillSecondaryBlue.opacity(0.10), interactive: true)
    }
}

struct RealityCheckCard: View {
    let openPanicSupport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                BreathingOrb()
                    .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Reality check mode")
                        .font(.title3.bold())
                        .foregroundStyle(Color.chillText)
                    Text("A calmer layout is available because recent inputs suggest extra load.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                }
            }

            Text("No judgment. Bigger actions, fewer colors, and a slower pace can help when decisions feel noisy.")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: openPanicSupport) {
                Label("Open calming mode", systemImage: "lungs.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
            }
            .buttonStyle(ChillPillButtonStyle(prominent: true))
        }
        .padding(18)
        .glassSurface(radius: 30, tint: Color.chillDarkBackground.opacity(0.10), interactive: true)
    }
}

private struct BreathingOrb: View {
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.chillPrimary.opacity(0.72), Color.chillMint.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

private struct ProfessionalHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DefaultsKey.lastDailyRecoveryScore) private var lastDailyRecoveryScore = 42

    private var palette: DailyScorePalette {
        DailyScorePalette(score: lastDailyRecoveryScore)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(String(localized: "Talk to someone"))
                            .font(.largeTitle.bold())
                            .foregroundStyle(palette.heroText)
                            .disablesRootSwipeBack()

                        Text(String(localized: "A professional helper can talk through sex, substances, sleep, PrEP, consent, and safety without judgment."))
                            .font(.callout)
                            .foregroundStyle(palette.heroSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HelpResourceCard(
                            title: String(localized: "Sexual health clinic"),
                            detail: String(localized: "Good for STI testing, PrEP, condoms, chemsex support, and safer-sex planning."),
                            symbol: "cross.case.fill"
                        )

                        HelpResourceCard(
                            title: String(localized: "GP or family doctor"),
                            detail: String(localized: "Good for sleep, mood, substance concerns, medication interactions, and referrals."),
                            symbol: "stethoscope"
                        )

                        HelpResourceCard(
                            title: String(localized: "Counselor or addiction support"),
                            detail: String(localized: "Good when patterns feel hard to change, risky, or emotionally heavy."),
                            symbol: "person.2.fill"
                        )
                    }
                    .padding(20)
                }
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BackChevronButton {
                        dismiss()
                    }
                }
            }
            .edgeSwipeToDismiss()
        }
    }
}

private struct HelpResourceCard: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.chillPrimary)
                .frame(width: 42, height: 42)
                .glassSurface(radius: 21, tint: Color.chillPrimary.opacity(0.10))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.chillText)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .black.opacity(0.04))
    }
}

struct TodayFocusCard: View {
    let entries: [NightEntry]
    let plans: [SaferSessionPlan]
    let timers: [DrugDoseTimerRecord]
    let tests: [STDTestRecord]
    let journalEntries: [JournalEntry]
    let metrics: DashboardMetrics
    let log: () -> Void
    let openCare: (CareToolPage) -> Void
    let openCalendar: () -> Void

    private var action: SmartNextAction {
        SmartNextAction(
            entries: entries,
            plans: plans,
            timers: timers,
            tests: tests,
            journalEntries: journalEntries,
            metrics: metrics
        )
    }

    var body: some View {
        Button(action: performAction) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(action.tint.opacity(0.22))
                        .frame(width: 48, height: 48)
                    Image(systemName: action.symbol)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(action.tint)
                        .symbolRenderingMode(.hierarchical)
                }
                .shadow(color: action.tint.opacity(0.36), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    // The next-action headline. Its length swings from "Log a Chill"
                    // to "Ready when you are" to the German for either, and one
                    // headline-sized line at 75% does not hold the longer ones once
                    // the text size grows — it truncates the sentence that tells
                    // someone what the card is for.
                    Text(action.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.chillText)
                        .chillLineLimit(2, scale: 0.7)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(action.detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.chillTertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ChillPlainButtonStyle())
        .glassSurface(radius: 28, tint: .clear, interactive: true)
        .accessibilityLabel(action.accessibilityLabel)
    }

    private func performAction() {
        switch action.destination {
        case .log:
            log()
        case .calendar:
            openCalendar()
        case .care(let page):
            openCare(page)
        }
    }
}

/// Always-visible crisis affordance pinned near the top of Home: a solid red bar,
/// so the one path that must never be hunted for is the loudest thing on screen.
/// `escalated` adds a pulsing ring when signals suggest the user may be in distress.
struct GetHelpNowBar: View {
    var escalated: Bool = false
    let open: () -> Void

    @Environment(\.chillReduceMotion) private var reduceMotion

    /// A deep, saturated red (matching the emergency-call button) that keeps white
    /// text readable. The icon-tint `chillIconRed` is too light for a solid fill.
    private let barRed = Color(red: 216 / 255, green: 52 / 255, blue: 52 / 255)

    /// 0 → 1 continuous driver for the pulsing ring (a Bool doesn't oscillate
    /// reliably under `repeatForever`).
    @State private var pulse: CGFloat = 0

    var body: some View {
        Button(action: open) {
            HStack(spacing: 9) {
                Image(systemName: "cross.case.fill")
                Text("Get help now")
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(barRed)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(escalated ? (0.25 + 0.6 * pulse) : 0), lineWidth: 2)
            )
            .shadow(color: barRed.opacity(escalated ? 0.55 : 0.28), radius: escalated ? 18 : 9, y: 4)
        }
        .buttonStyle(ChillPlainButtonStyle())
        .accessibilityLabel(Text("Get help now. Breathing, grounding, or call emergency services."))
        .onAppear { syncPulse() }
        .onChange(of: escalated) { _, _ in syncPulse() }
    }

    private func syncPulse() {
        // Reduce Motion holds the ring steady instead of breathing. The escalated
        // state still has to READ as escalated, so the ring stays at its bright
        // value rather than being dropped: the people most likely to have Reduce
        // Motion on are the last people who should lose a crisis affordance.
        //
        // A `repeatForever` animation also never settles, so leaving it running
        // ignores the preference for as long as the bar is on screen.
        guard !reduceMotion else {
            pulse = escalated ? 1 : 0
            return
        }

        if escalated {
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) { pulse = 1 }
        } else {
            withAnimation(.easeOut(duration: 0.3)) { pulse = 0 }
        }
    }
}

struct FloatingLogBar: View {
    let add: () -> Void
    let skip: () -> Void
    var isTonightLogged: Bool = false
    @State private var isPressed = false
    @State private var confirmSkip = false
    @State private var hasQuickSkippedLocally = false
    @State private var pressTask: Task<Void, Never>?
    @Environment(\.chillReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Primary action: matches original clean design
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Private log"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                    Text(String(localized: "Add sleep, reflection, or a skip"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                }

                Spacer(minLength: 12)

                Button {
                    // Cancellable and reduce-motion aware. The previous
                    // DispatchQueue.main.asyncAfter could not be cancelled and fired
                    // its animation even after the view had gone away.
                    if !reduceMotion {
                        pressTask?.cancel()
                        withAnimation(.spring(response: 0.20, dampingFraction: 0.70)) { isPressed = true }
                        pressTask = Task {
                            try? await Task.sleep(for: .milliseconds(140))
                            guard !Task.isCancelled else { return }
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) { isPressed = false }
                        }
                    }
                    add()
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(LinearGradient.chillBrand, in: Capsule())
                        .shadow(color: Color.chillPrimary.opacity(0.44), radius: 12, y: 6)
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                }
                .buttonStyle(ChillPlainButtonStyle())
                .accessibilityLabel("Add Chill")
                .accessibilityIdentifier(AccessibilityID.logChillButton)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            // Secondary action: clear-night quick log.
            // Hidden once tonight is already logged, or immediately hidden when tapped locally
            if !isTonightLogged && !hasQuickSkippedLocally {
                Rectangle()
                    .fill(.white.opacity(0.07))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)

                Button {
                    confirmSkip = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.chillSecondary)
                        Text(String(localized: "Nothing happened tonight"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.chillTertiary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(ChillPlainButtonStyle())
                .accessibilityLabel("Log nothing happened tonight")
                .accessibilityIdentifier(AccessibilityID.skipNightButton)
            }
        }
        .glassSurface(radius: 30, tint: .black.opacity(0.04))
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isTonightLogged)
        .onDisappear { pressTask?.cancel() }
        .alert(String(localized: "Log a clear night?"), isPresented: $confirmSkip) {
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Confirm")) {
                withAnimation { hasQuickSkippedLocally = true }
                skip()
            }
        } message: {
            Text("This marks tonight as a clear night with nothing to track. You can still add a log later if something comes up.")
        }
    }
}
