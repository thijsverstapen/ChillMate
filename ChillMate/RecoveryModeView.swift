import Foundation
import SwiftData
import SwiftUI

struct RecoveryModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(ChillMateQueries.recentEntries) private var entries: [NightEntry]
    @AppStorage(DefaultsKey.recoveryGoal) private var recoveryGoal = ""
    @AppStorage(DefaultsKey.recoverySupportPerson) private var supportPerson = ""
    @AppStorage(DefaultsKey.recoveryCommitment) private var recoveryCommitment = ""
    @State private var isShowingCravingDelay = false

    private var streakDays: Int {
        ChillInsightCalculator.recoveryStreakDays(entries: entries)
    }

    private var topTriggers: [TrendCount] {
        ChillInsightCalculator.triggerCounts(entries: entries).prefix(4).map { $0 }
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Recovery mode"),
                            subtitle: String(localized: "A no-shame place for reducing, stopping, or simply taking a quieter stretch. A reset is information, not failure."),
                            symbol: "figure.mind.and.body",
                            tint: Color.chillPrimary
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(streakDays)")
                                .chillScaledFont(size: 54, weight: .black, relativeTo: .largeTitle, design: .rounded)
                                .foregroundStyle(Color.chillText)
                            Text("days since logged substance use")
                                .font(.headline)
                                .foregroundStyle(Color.chillSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .glassSurface(radius: 32, tint: Color.chillPrimary.opacity(0.10))

                        BoundaryPromptField(title: String(localized: "My goal"), placeholder: String(localized: "Example: no stimulant-related Chills for two weeks"), text: $recoveryGoal)
                        BoundaryPromptField(title: String(localized: "Who can I contact?"), placeholder: String(localized: "Name or plan for someone safe"), text: $supportPerson)
                        BoundaryPromptField(title: String(localized: "What helped last time?"), placeholder: String(localized: "Example: leave earlier, eat first, avoid app dates after midnight"), text: $recoveryCommitment)

                        Button {
                            isShowingCravingDelay = true
                        } label: {
                            Label("Start 10-minute craving delay", systemImage: "pause.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ChillPillButtonStyle(prominent: true))

                        TrendListCard(title: String(localized: "Common triggers"), emptyText: String(localized: "Trigger tags from logs will appear here."), counts: Array(topTriggers), tint: Color.chillPrimary)
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(Text(verbatim: ""))
            .fullScreenCover(isPresented: $isShowingCravingDelay) {
                CareCoverHost { CravingDelayView() }
            }
            .endEditingOnTap()
        }
    }
}
