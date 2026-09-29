import SwiftUI
import ChillMateCore

// The grid of numbers on Home, and the sheet that explains the daily score.

struct MetricsGrid: View {
    @State private var delays = DelayedActionRunner()
    @Environment(\.chillReduceMotion) private var reduceMotion

    let trackedCount: Int
    let skippedCount: Int
    let substanceCount: Int
    let averageSleepHours: Double?
    let dailyScore: DailyRecoveryScore
    let recoveryStreakDays: Int
    let openRecoveryStreak: () -> Void

    @State private var showDetails = false
    @State private var isShowingFactors = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: openRecoveryStreak) {
                    StatTile(
                        value: "\(recoveryStreakDays)",
                        // A `== 1` ternary, deliberately. Xcode rejects a plural
                        // variation whose value does not print the number
                        // ("Plural variation requires referencing the number in the
                        // string ... use separate top-level strings"), and this unit
                        // sits beside a number the tile already draws. Separate
                        // strings picked in code is the sanctioned form here.
                        unit: recoveryStreakDays == 1 ? String(localized: "day") : String(localized: "days"),
                        label: String(localized: "Recovery streak"),
                        showsChevron: false
                    )
                }
                .buttonStyle(ChillPlainButtonStyle())
                .accessibilityLabel(Text("Recovery streak of \(recoveryStreakDays) days. Tap to open your calendar."))

                Button { isShowingFactors = true } label: {
                    StatTile(
                        value: dailyScore.isActive ? "\(dailyScore.value)" : dailyScore.emoji,
                        unit: nil,
                        label: dailyScore.isActive ? String(localized: "Today’s score") : String(localized: "Log to activate"),
                        showsChevron: true
                    )
                }
                .buttonStyle(ChillPlainButtonStyle())
                .accessibilityLabel(dailyScore.isActive ? Text("Today’s score \(dailyScore.value). Tap to see the breakdown.") : Text("Daily score not active yet. Log a night to activate."))
                // The identifier used to sit on a pill no screen showed, so the UI
                // test that checks this is announced could never find it.
                .accessibilityIdentifier(AccessibilityID.dailyScorePill)
            }

            if showDetails {
                LazyVGrid(columns: columns, spacing: 8) {
                    MetricCard(title: String(localized: "Logged"), value: "\(trackedCount)", caption: String(localized: "with sex or substances"), symbol: "heart.text.square.fill", tint: Color.chillIconPink)
                    MetricCard(title: String(localized: "Skipped"), value: "\(skippedCount)", caption: String(localized: "all-clear check-ins"), symbol: "moon.zzz.fill", tint: Color.chillIconPurple)
                    MetricCard(title: String(localized: "Substances"), value: "\(substanceCount)", caption: String(localized: "tags across logs"), symbol: "pills.fill", tint: Color.chillSecondaryBlue)
                    MetricCard(title: String(localized: "Sleep"), value: sleepValue, caption: sleepCaption, symbol: "bed.double.fill", tint: Color.chillIconAmber)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                withAnimation(.snappy) { showDetails.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(showDetails ? String(localized: "Hide details") : String(localized: "Show details"))
                        .font(.caption.weight(.bold))
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(Color.chillPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(ChillPlainButtonStyle())
            .accessibilityLabel(showDetails ? Text("Hide monthly details") : Text("Show monthly details"))
        }
        .padding(12)
        .glassSurface(radius: 28, tint: .clear)
        .sheet(isPresented: $isShowingFactors) {
            ScoreFactorsSheet(score: dailyScore, openCalendar: {
                isShowingFactors = false
                // Cancellable, and skipped entirely under Reduce Motion, where the
                // delay exists only to let a flourish play.
                delays.run(after: .milliseconds(350), reduceMotion: reduceMotion) { openRecoveryStreak() }
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sensoryFeedback(trigger: isShowingFactors) { _, presented in presented ? .impact(weight: .light) : nil }
        .cancellingDelayedActions(delays)
    }

    private var sleepValue: String {
        guard let averageSleepHours else { return String(localized: "0 hours") }
        return SleepMood(hours: averageSleepHours).emoji
    }

    private var sleepCaption: String {
        guard let averageSleepHours else { return String(localized: "sleep not logged") }
        return String(localized: "avg \(averageSleepHours.formatted(.number.precision(.fractionLength(0...1)))) h")
    }
}

/// One flat metric tile in the two-up summary row (recovery streak / today's score),
/// matching the mockup's stat cards.
private struct StatTile: View {
    let value: String
    let unit: String?
    let label: String
    let showsChevron: Bool

    /// True when `value` is a score rather than the placeholder emoji.
    private var isNumeric: Bool { value.allSatisfy(\.isNumber) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                // `value` is a number when the score is active and an emoji when
                // it is not, and the two need different sizes.
                //
                // A digit at 26pt relative to .title is fine: it is narrow, and
                // minimumScaleFactor shrinks it if the row runs out of width. An
                // emoji is neither. It is roughly square, it does not respond to
                // minimumScaleFactor the way glyphs from a text font do, and at the
                // accessibility sizes a .title-relative emoji outgrows this tile and
                // is drawn clipped — which is what the audit reports.
                //
                // So the emoji gets its own smaller scale with headroom to grow
                // into. It is standing in for "no score yet" rather than carrying a
                // reading, so it can afford to be smaller; the label beside it is
                // what actually says so.
                Text(value)
                    .chillScaledFont(
                        size: isNumeric ? 26 : 20,
                        weight: .bold,
                        relativeTo: isNumeric ? .title : .body,
                        design: .rounded
                    )
                    .foregroundStyle(Color.chillText)
                    .monospacedDigit()
                    .contentTransition(isNumeric ? .numericText() : .identity)
                    .chillLineLimit(1, scale: 0.6)
                    .accessibilityHidden(!isNumeric)
                if let unit {
                    Text(unit)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.chillSecondary)
                }
                Spacer(minLength: 0)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.chillTertiary)
                }
            }
            // One line at 80% is not enough room for "Log to activate" once the
            // text size grows, so it truncated — which the accessibility audit
            // reports as clipped text, and which on this tile hides the only
            // instruction telling someone how to switch the score on.
            //
            // Two lines and a little more shrink. The tiles sit side by side, so
            // the taller one sets the row height and they stay aligned.
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .chillLineLimit(2, scale: 0.7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassSurface(radius: 20, tint: .clear, interactive: true)
    }
}

private struct ScoreFactorsSheet: View {
    let score: DailyRecoveryScore
    let openCalendar: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.84).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(Color.chillPrimary.opacity(0.14), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: score.isActive ? CGFloat(score.value) / 100 : 1)
                                .stroke(LinearGradient.chillBrand, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            // Scaling text inside a container that does not scale
                            // can only ever end in clipping, and this ring is a
                            // fixed 52pt. The glyph is allowed to shrink to fit it
                            // rather than grow out of it — which matters most for
                            // the emoji, since an emoji is roughly square and hits
                            // the edge long before a digit does.
                            Text(score.isActive ? "\(score.value)" : score.emoji)
                                .chillScaledFont(size: 18, weight: .black, relativeTo: .title3, design: .rounded)
                                .foregroundStyle(Color.chillText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .accessibilityHidden(!score.isActive)
                        }
                        .frame(width: 52, height: 52)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(localized: "Daily recovery score"))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.chillText)
                            Text(score.isActive ? score.label.capitalized : String(localized: "Log a Chill to activate"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.chillSecondary)
                        }
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(score.factors.enumerated()), id: \.offset) { _, factor in
                            HStack(spacing: 14) {
                                Text(factor.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.chillText)
                                    .frame(width: 90, alignment: .leading)
                                Text(factor.caption)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.chillSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(.white.opacity(0.06))
                                    .frame(height: 1)
                            }
                        }
                    }
                    .glassSurface(radius: 20, tint: .white.opacity(0.07))

                    Text(String(localized: "Score is based on your most recent log entry: sleep, aftercare, substances, recovery streak, and Apple Watch HRV if available."))
                        .font(.caption)
                        .foregroundStyle(Color.chillTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: openCalendar) {
                        Label(String(localized: "View calendar"), systemImage: "calendar")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChillPillButtonStyle(prominent: false))
                }
                .padding(20)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let caption: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 0) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                        .frame(width: 34, height: 34)
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(tint)
                        .symbolRenderingMode(.hierarchical)
                }
                .shadow(color: tint.opacity(0.36), radius: 6, y: 2)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .chillScaledFont(size: 22, weight: .black, relativeTo: .title2, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(Color.chillText)
                    .chillLineLimit(1, scale: 0.70)

                // Both of these carry sentences whose length varies with the
                // language and with what the card is reporting, and a hard
                // one-line limit truncates them rather than wrapping. The audit
                // reports that as clipped text; on this card it is the line that
                // says what the number means.
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillText.opacity(0.90))
                    .chillLineLimit(2, scale: 0.75)
                    .fixedSize(horizontal: false, vertical: true)

                Text(caption)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .chillLineLimit(2, scale: 0.75)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        .padding(12)
        .glassSurface(radius: 20, tint: .clear, interactive: true)
    }
}
