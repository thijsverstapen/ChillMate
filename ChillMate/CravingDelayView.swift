import Foundation
import SwiftData
import SwiftUI

struct CravingDelayView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(ChillMateQueries.recentTimers) private var timers: [DrugDoseTimerRecord]
    @State private var startedAt: Date?
    @State private var isShowingTimer = false

    private var latestTimer: DrugDoseTimerRecord? {
        timers.first
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(
                            title: String(localized: "Craving delay"),
                            subtitle: String(localized: "A 10 minute pause before deciding. If something already happened, use a check-in to record context without judging yourself."),
                            symbol: "pause.circle.fill",
                            tint: Color.chillPrimary
                        )

                        if let latestTimer {
                            LatestDoseReminder(timer: latestTimer)
                        }

                        DelayOrb(startedAt: startedAt)

                        HStack(spacing: 10) {
                            GlassActionButton(prominent: true) {
                                startedAt = .now
                            } label: {
                                Label(startedAt == nil ? "Start 10 min pause" : "Restart pause", systemImage: "timer")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }

                            Button {
                                isShowingTimer = true
                            } label: {
                                Label("Open check-in", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .chillSecondaryBlue))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("During the pause")
                                .font(.headline)
                                .foregroundStyle(Color.chillText)
                            Text("Breathe slowly, drink water if safe, check your body, remember what was already logged, and ask whether waiting would protect tomorrow-you.")
                                .font(.callout)
                                .foregroundStyle(Color.chillSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .glassSurface(radius: 24, tint: Color.chillPrimary.opacity(0.08))
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(Text(verbatim: ""))
            .fullScreenCover(isPresented: $isShowingTimer) {
                DrugTimerView()
            }
        }
    }
}

private struct LatestDoseReminder: View {
    let timer: DrugDoseTimerRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Earlier log reminder", systemImage: "clock.arrow.circlepath")
                .font(.headline)
                .foregroundStyle(Color.chillText)
            Text("\(timer.substanceName) was logged at \(timer.startedAt.formatted(date: .abbreviated, time: .shortened)). Check-in progress: \(timer.effectProgress(at: .now).formatted(.percent.precision(.fractionLength(0)))).")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassSurface(radius: 24, tint: Color.chillSecondaryBlue.opacity(0.08), interactive: true)
    }
}

private struct DelayOrb: View {
    let startedAt: Date?

    /// The gradient circle and the glass surface are built once and stay put; only
    /// the digits and the caption sit inside the TimelineView.
    ///
    /// Previously the whole orb (including `glassSurface`, which is a blurred
    /// material) was rebuilt once a second for the full ten minutes of the delay
    /// tool, when the only thing changing was the number.
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.chillPrimary.opacity(0.55), Color.chillMint.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 156, height: 156)
                    .scaleEffect(startedAt == nil ? 0.92 : 1.0)

                countdown { remaining in
                    Text(timeText(remaining))
                        .chillScaledFont(size: 34, weight: .bold, relativeTo: .largeTitle, design: .rounded)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        // The countdown is information, not decoration, so it keeps
                        // updating under Reduce Motion. Only VoiceOver pacing changes.
                        .accessibilityLabel(accessibilityTimeLabel(remaining))
                }
            }

            countdown { remaining in
                Text(remaining == 0 && startedAt != nil
                     ? String(localized: "Pause complete. Decide slowly.")
                     : String(localized: "Let the first urge pass before choosing."))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassSurface(radius: 32, tint: Color.chillPrimary.opacity(0.08))
    }

    /// Drives `content` from a one-second timeline once the delay is running, and
    /// renders it statically before that.
    @ViewBuilder
    private func countdown<Content: View>(@ViewBuilder content: @escaping (Int) -> Content) -> some View {
        if startedAt == nil {
            content(10 * 60)
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                content(remainingSeconds(now: context.date))
            }
        }
    }

    private func remainingSeconds(now: Date) -> Int {
        guard let startedAt else { return 10 * 60 }
        return max(0, Int(startedAt.addingTimeInterval(10 * 60).timeIntervalSince(now)))
    }

    private func accessibilityTimeLabel(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(localized: "\(minutes) minutes \(remainder) seconds remaining")
    }

    private func timeText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return "\(minutes.twoDigitPadded):\(remainder.twoDigitPadded)"
    }
}

private extension Int {
    var twoDigitPadded: String {
        self < 10 ? "0\(self)" : "\(self)"
    }
}
